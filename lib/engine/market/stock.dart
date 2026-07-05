import 'exchange.dart';
import 'sector.dart';

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

  /// 일봉 종가 히스토리 (차트·통계용).
  final List<double> closeHistory = [];

  /// 오늘 장중 틱 가격 (매일 아침 리셋).
  final List<double> tickHistory = [];

  void openDay() {
    tickHistory
      ..clear()
      ..add(price);
  }

  void recordTick() => tickHistory.add(price);

  void closeDay() => closeHistory.add(price);

  /// 오늘의 시가 대비 등락률. 장 시작 전이면 0.
  double get todayChangeRate {
    if (tickHistory.isEmpty) return 0;
    final open = tickHistory.first;
    return open == 0 ? 0 : (price - open) / open;
  }
}
