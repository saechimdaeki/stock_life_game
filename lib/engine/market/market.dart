import 'dart:math';

import '../clock/game_clock.dart';
import '../events/event_engine.dart';
import '../events/game_event.dart';
import 'exchange.dart';
import 'price_engine.dart';
import 'sector.dart';
import 'stock.dart';

/// 오늘의 뉴스 항목 (헤드라인 + 원본 이벤트).
class NewsItem {
  const NewsItem({required this.headline, required this.event});

  final String headline;
  final ActiveEvent event;
}

/// 시장 전체 오케스트레이션. 국장/미장이 각자의 세션 시각에만 움직인다.
///
/// 하루 흐름:
///   [settleOvernight] (취침 중 미장 잔여 세션 정산, 2일차부터)
///   -> [openDay] (아침 뉴스 추첨·점프 적용·유효 파라미터 계산)
///   -> [advanceTick] 반복 (개장 중인 거래소만 가격 갱신)
///   -> [closeDay] (종가 기록·이벤트 만료)
class Market {
  Market({
    required this.stocks,
    required this.priceEngine,
    required this.eventEngine,
  });

  final List<Stock> stocks;
  final PriceEngine priceEngine;
  final EventEngine eventEngine;

  /// 원/달러 환율. 매일 아침 랜덤워크(일 변동성 ~0.6%, 1250~1550 밴드).
  double usdKrw = kUsdKrw;

  static const double _fxDailySigma = 0.006;
  static const double _fxMin = 1250;
  static const double _fxMax = 1550;

  /// 상장폐지 트리거: 종가가 사실상 바닥(하한×1.1)에 붙으면 폐지.
  /// 문턱을 높이면 회생 가능 종목까지 영구 동결돼 바이앤홀드가 과하게 깎인다.
  static const double delistMultiple = 1.1;

  /// 어제 장마감에 상장폐지된 종목 이름들 (아침 공지용, openDay에서 초기화).
  final List<String> delistedYesterday = [];

  /// 유효 드리프트 클램프 범위 (연환산). 이벤트가 여러 개 겹칠 수 있어
  /// 비대칭이면 한쪽으로 수익률이 폭주한다 — 반드시 대칭 유지.
  static const double minMu = -1.0;
  static const double maxMu = 1.0;

  /// 유효 변동성 클램프 범위 (연환산).
  static const double minSigma = 0.05;
  static const double maxSigma = 2.0;

  /// 주가 하한 (거래소 통화 기준). 0 붕괴 방지 - 상장폐지 트리거는 Phase 3.
  static const double minPriceKrx = 100; // 원
  static const double minPriceUs = 0.1; // 달러

  final List<NewsItem> todaysNews = [];

  /// 장중 돌발 이벤트 속보 대기열. 컨트롤러가 피드로 옮기며 비운다.
  final List<NewsItem> intradayNewsBuffer = [];

  final Map<String, double> _dayMu = {};
  final Map<String, double> _daySigma = {};
  int _currentDay = 1;

  List<Stock> get listedStocks => stocks.where((s) => s.isListed).toList();

  List<Stock> listedOn(ExchangeId exchangeId) =>
      stocks.where((s) => s.isListed && s.exchangeId == exchangeId).toList();

  /// 원화 환산 가격 (포트폴리오 평가·매매 통화 통일용).
  double priceKrwOf(Stock s) =>
      s.exchangeId == ExchangeId.us ? s.price * usdKrw : s.price;

  /// 원화 환산 현재가 스냅샷 (포트폴리오 평가용).
  Map<String, double> get prices => {
        for (final s in stocks)
          if (s.isListed) s.code: priceKrwOf(s),
      };

  /// IPO 대기 풀에서 하나를 상장시킨다. 풀이 비었으면 null.
  Stock? debutIpo(Random random) {
    final pool = stocks.where((s) => s.status == ListingStatus.unlisted).toList();
    if (pool.isEmpty) return null;
    final stock = pool[random.nextInt(pool.length)];
    stock.status = ListingStatus.listed;
    // 상장 직후 차트가 텅 비지 않게 짧은 더미 히스토리만 깐다.
    stock.seedHistory(random, days: 5);
    return stock;
  }

  Stock? stockByCode(String code) {
    for (final s in stocks) {
      if (s.code == code) return s;
    }
    return null;
  }

  /// 현재 시각에 해당 종목을 매매할 수 있는지 (거래소 개장 여부).
  bool isTradableAt(Stock stock, int minuteOfDay) =>
      stock.isListed && stock.exchange.isOpenAt(minuteOfDay);

  /// 취침(02:00~06:00) 동안 진행된 미장 잔여 세션을 한 번에 정산한다.
  /// 다음 날 [openDay] 직전에 호출 - "자고 일어나니 미장이 움직여 있다".
  void settleOvernight() {
    final remainingTicks = (kUsExchange.closeMinute - GameClock.dayEndMinute) ~/
        GameClock.minutesPerTick;
    for (var i = 0; i < remainingTicks; i++) {
      _moveStocks(listedOn(ExchangeId.us));
    }
  }

  /// 아침: 이벤트 추첨, 신규 이벤트 점프를 시가에 반영,
  /// 오늘 하루의 유효 mu/sigma를 계산한다.
  void openDay(int day) {
    _currentDay = day;
    delistedYesterday.clear();
    intradayNewsBuffer.clear();
    // 환율 랜덤워크 (하루 1회).
    usdKrw = (usdKrw * exp(_fxDailySigma * priceEngine.nextGaussian()))
        .clamp(_fxMin, _fxMax);
    final listed = listedStocks;
    final rolled = eventEngine.rollMorning(day: day, listedStocks: listed);

    todaysNews
      ..clear()
      ..addAll(rolled.map(_toNews));

    for (final event in rolled) {
      _applyJump(event);
    }

    _recomputeDayParams(listed);
    for (final stock in listed) {
      stock.openDay();
    }
  }

  /// 활성 이벤트를 반영해 오늘의 유효 mu/sigma를 다시 계산한다.
  void _recomputeDayParams(List<Stock> listed) {
    for (final stock in listed) {
      final mu = stock.baseMu + eventEngine.muBonusFor(stock);
      final sigma = stock.baseSigma * eventEngine.sigmaMultFor(stock);
      _dayMu[stock.code] = mu.clamp(minMu, maxMu);
      _daySigma[stock.code] = sigma.clamp(minSigma, maxSigma);
    }
  }

  /// 장중 1틱: 현재 시각에 개장 중인 거래소의 종목만 가격을 갱신한다.
  /// 낮은 확률로 돌발 이벤트가 터진다 (점프+드리프트 즉시 반영, 속보 대기열에 추가).
  void advanceTick(int minuteOfDay) {
    final open = stocks
        .where((s) => s.isListed && s.exchange.isOpenAt(minuteOfDay))
        .toList();
    if (open.isEmpty) return;
    final breaking =
        eventEngine.maybeIntraday(day: _currentDay, tradableStocks: open);
    if (breaking != null) {
      _applyJump(breaking);
      _recomputeDayParams(listedStocks);
      intradayNewsBuffer.add(_toNews(breaking));
    }
    _moveStocks(open, recordTicks: true);
  }

  /// 장마감: 종가 기록, 붕괴 종목 상장폐지, 이벤트 잔여 일수 차감·만료.
  void closeDay() {
    for (final stock in stocks) {
      if (!stock.isListed) continue;
      stock.closeDay();
      if (stock.price <= _minPriceOf(stock) * delistMultiple) {
        stock.status = ListingStatus.delisted;
        delistedYesterday.add(stock.name);
      }
    }
    eventEngine.endDay();
  }

  void _moveStocks(List<Stock> targets, {bool recordTicks = false}) {
    // 차트 표시용(recordTicks) 세션 틱은 마이크로 스텝으로 잘게 그려 부드럽게 잇는다.
    // 오버나이트 정산 등 비표시 이동은 1스텝(기존과 동일)으로 유지한다.
    final steps = recordTicks ? priceEngine.microSteps : 1;

    for (var st = 0; st < steps; st++) {
      final sectorZ = {
        for (final sector in kSectors) sector.id: priceEngine.nextGaussian(),
      };
      for (final stock in targets) {
        final factor = priceEngine.tickFactor(
          mu: _dayMu[stock.code] ?? stock.baseMu,
          sigma: _daySigma[stock.code] ?? stock.baseSigma,
          sectorZ: sectorZ[stock.sectorId]!,
          rho: sectorOf(stock.sectorId).correlation,
          steps: steps,
        );
        stock.price = max(stock.price * factor, _minPriceOf(stock));
      }
      if (recordTicks) {
        for (final stock in targets) {
          stock.recordTick();
        }
      }
    }
  }

  double _minPriceOf(Stock stock) =>
      stock.exchangeId == ExchangeId.us ? minPriceUs : minPriceKrx;

  /// 현재 진행 중인 가장 강한 이벤트의 속보(헤드라인+호악재). 없으면 null.
  /// 회의 중 "폭락 중입니다" 같은 실시간 속보용 (오늘 뉴스가 아닌 활성 이벤트 기준).
  ({String headline, bool good})? breakingEvent() {
    ActiveEvent? best;
    for (final e in eventEngine.active) {
      if (e.spec.effect.muBonus.abs() < 0.4) continue;
      if (best == null ||
          e.spec.effect.muBonus.abs() > best.spec.effect.muBonus.abs()) {
        best = e;
      }
    }
    if (best == null) return null;
    return (headline: _toNews(best).headline, good: best.spec.isGood);
  }

  NewsItem _toNews(ActiveEvent event) {
    final stock =
        event.stockCode == null ? null : stockByCode(event.stockCode!);
    final sectorName =
        event.sectorId == null ? null : sectorOf(event.sectorId!).nameKo;
    return NewsItem(
      headline: event.resolveHeadline(
        stockName: stock?.name,
        sectorName: sectorName,
      ),
      event: event,
    );
  }

  void _applyJump(ActiveEvent event) {
    final jump = event.spec.effect.jump;
    if (jump == 1.0) return;
    for (final stock in stocks) {
      if (!stock.isListed) continue;
      final applies = switch (event.spec.scope) {
        EventScope.stock => event.stockCode == stock.code,
        EventScope.sector => event.sectorId == stock.sectorId,
        EventScope.exchange => event.exchangeId == stock.exchangeId,
        EventScope.market => true,
      };
      if (applies) {
        stock.price = max(stock.price * jump, _minPriceOf(stock));
      }
    }
  }
}
