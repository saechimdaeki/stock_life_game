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

  /// 유효 드리프트 클램프 범위 (연환산).
  static const double minMu = -1.0;
  static const double maxMu = 1.5;

  /// 유효 변동성 클램프 범위 (연환산).
  static const double minSigma = 0.05;
  static const double maxSigma = 2.0;

  /// 주가 하한 (거래소 통화 기준). 0 붕괴 방지 - 상장폐지 트리거는 Phase 3.
  static const double minPriceKrx = 100; // 원
  static const double minPriceUs = 0.1; // 달러

  final List<NewsItem> todaysNews = [];

  final Map<String, double> _dayMu = {};
  final Map<String, double> _daySigma = {};

  List<Stock> get listedStocks => stocks.where((s) => s.isListed).toList();

  List<Stock> listedOn(ExchangeId exchangeId) =>
      stocks.where((s) => s.isListed && s.exchangeId == exchangeId).toList();

  /// 원화 환산 현재가 스냅샷 (포트폴리오 평가용).
  Map<String, double> get prices => {
        for (final s in stocks)
          if (s.isListed) s.code: s.priceKrw,
      };

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
    final listed = listedStocks;
    final rolled = eventEngine.rollMorning(day: day, listedStocks: listed);

    todaysNews
      ..clear()
      ..addAll(rolled.map(_toNews));

    for (final event in rolled) {
      _applyJump(event);
    }

    for (final stock in listed) {
      final mu = stock.baseMu + eventEngine.muBonusFor(stock);
      final sigma = stock.baseSigma * eventEngine.sigmaMultFor(stock);
      _dayMu[stock.code] = mu.clamp(minMu, maxMu);
      _daySigma[stock.code] = sigma.clamp(minSigma, maxSigma);
      stock.openDay();
    }
  }

  /// 장중 1틱: 현재 시각에 개장 중인 거래소의 종목만 가격을 갱신한다.
  void advanceTick(int minuteOfDay) {
    final open = stocks
        .where((s) => s.isListed && s.exchange.isOpenAt(minuteOfDay))
        .toList();
    if (open.isEmpty) return;
    _moveStocks(open, recordTicks: true);
  }

  /// 장마감: 종가 기록, 이벤트 잔여 일수 차감·만료.
  void closeDay() {
    for (final stock in stocks) {
      if (stock.isListed) stock.closeDay();
    }
    eventEngine.endDay();
  }

  void _moveStocks(List<Stock> targets, {bool recordTicks = false}) {
    final sectorZ = {
      for (final sector in kSectors) sector.id: priceEngine.nextGaussian(),
    };

    for (final stock in targets) {
      final factor = priceEngine.tickFactor(
        mu: _dayMu[stock.code] ?? stock.baseMu,
        sigma: _daySigma[stock.code] ?? stock.baseSigma,
        sectorZ: sectorZ[stock.sectorId]!,
        rho: sectorOf(stock.sectorId).correlation,
      );
      stock.price = max(stock.price * factor, _minPriceOf(stock));
      if (recordTicks) stock.recordTick();
    }
  }

  double _minPriceOf(Stock stock) =>
      stock.exchangeId == ExchangeId.us ? minPriceUs : minPriceKrx;

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
