import 'dart:math';

import 'exchange.dart';
import 'sector.dart';

/// 하루치 봉 (시고저종). 캔들 차트용.
class Candle {
  const Candle({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final double open;
  final double high;
  final double low;
  final double close;

  Map<String, double> toJson() =>
      {'o': open, 'h': high, 'l': low, 'c': close};

  factory Candle.fromJson(Map<String, dynamic> m) => Candle(
        open: (m['o'] as num).toDouble(),
        high: (m['h'] as num).toDouble(),
        low: (m['l'] as num).toDouble(),
        close: (m['c'] as num).toDouble(),
      );
}

/// 상장 상태. 상장폐지 트리거는 Phase 3에서 구현하며 필드만 미리 둔다.
enum ListingStatus { listed, delisted }

class Stock {
  Stock({
    required this.code,
    required this.name,
    required this.sectorId,
    required this.baseMu,
    required this.baseSigma,
    required double initialPrice,
    this.exchangeId = ExchangeId.krx,
  })  : price = initialPrice,
        assert(initialPrice > 0),
        assert(baseSigma > 0);

  final String code;
  final String name;
  final SectorId sectorId;
  final ExchangeId exchangeId;

  /// 연환산 기본 드리프트 (예: 0.08 = 연 +8%).
  final double baseMu;

  /// 연환산 기본 변동성 (예: 0.35 = 연 35%). 우량주 낮고 테마주 높음.
  final double baseSigma;

  /// 거래소 통화 기준 가격 (국장: 원, 미장: 달러).
  double price;
  ListingStatus status = ListingStatus.listed;

  bool get isListed => status == ListingStatus.listed;

  Exchange get exchange => exchangeOf(exchangeId);

  /// 원화 환산 가격 (포트폴리오 평가·매매 통화 통일용).
  double get priceKrw =>
      exchangeId == ExchangeId.us ? price * kUsdKrw : price;

  /// 일봉 종가 히스토리 (통계용).
  final List<double> closeHistory = [];

  /// 일봉 캔들 히스토리 (차트용, 시고저종).
  final List<Candle> candleHistory = [];

  /// 오늘 장중 틱 가격 (매일 아침 리셋).
  final List<double> tickHistory = [];

  /// 새 게임 시작 시 초반에도 차트에 흐름이 보이도록 과거 일봉을 합성한다.
  /// 종목 고유 변동성으로 현재가에서 과거로 랜덤워크해 [days]개 일봉을 채운다.
  /// (게임 밸런스와 무관 — 순전히 표시용 더미 히스토리)
  void seedHistory(Random random, {int days = 30}) {
    final dailySigma = baseSigma / sqrt(252); // 연변동성 -> 일변동성
    var close = price;
    final candles = <Candle>[]; // 최근 -> 과거 순으로 쌓는다
    for (var d = 0; d < days; d++) {
      final open = close / (1 + _gauss(random) * dailySigma);
      final hi = max(open, close) * (1 + random.nextDouble() * dailySigma);
      final lo = min(open, close) * (1 - random.nextDouble() * dailySigma);
      candles.add(Candle(open: open, high: hi, low: lo, close: close));
      close = open; // 더 과거 날의 종가 = 오늘 시가에 이어붙임
    }
    for (final c in candles.reversed) {
      candleHistory.add(c);
      closeHistory.add(c.close);
    }
  }

  static double _gauss(Random r) {
    final u1 = 1 - r.nextDouble();
    final u2 = r.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  void openDay() {
    tickHistory
      ..clear()
      ..add(price);
  }

  void recordTick() => tickHistory.add(price);

  void closeDay() {
    closeHistory.add(price);
    if (tickHistory.isNotEmpty) {
      candleHistory.add(Candle(
        open: tickHistory.first,
        high: tickHistory.reduce(max),
        low: tickHistory.reduce(min),
        close: price,
      ));
    }
  }

  /// 오늘 장중 틱으로 형성 중인 봉 (아직 마감 안 됨). 틱이 없으면 null.
  Candle? get formingCandle {
    if (tickHistory.isEmpty) return null;
    return Candle(
      open: tickHistory.first,
      high: tickHistory.reduce(max),
      low: tickHistory.reduce(min),
      close: price,
    );
  }

  /// 오늘의 시가 대비 등락률. 장 시작 전이면 0.
  double get todayChangeRate {
    if (tickHistory.isEmpty) return 0;
    final open = tickHistory.first;
    return open == 0 ? 0 : (price - open) / open;
  }
}
