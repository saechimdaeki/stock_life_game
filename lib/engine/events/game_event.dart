import '../market/exchange.dart';
import '../market/sector.dart';

/// 이벤트가 영향을 주는 범위.
enum EventScope { stock, sector, exchange, market }

/// 이벤트의 가격 효과. 뉴스 텍스트와 분리해 정의한다
/// (광고 보상 "애널리스트 리포트" 힌트 시스템 확장 대비).
class EventEffect {
  const EventEffect({
    this.jump = 1.0,
    this.muBonus = 0.0,
    this.sigmaMult = 1.0,
    this.durationDays = 1,
  })  : assert(jump > 0),
        assert(sigmaMult > 0),
        assert(durationDays >= 1);

  /// 발생일 시가에 1회 적용되는 즉시 점프 배율 (1.0 = 없음).
  final double jump;

  /// 지속 기간 동안 연환산 드리프트에 가산되는 값.
  final double muBonus;

  /// 지속 기간 동안 연환산 변동성에 곱해지는 배율.
  final double sigmaMult;

  /// 효과 지속 일수 (발생일 포함).
  final int durationDays;
}

/// 이벤트 테이블에 정의되는 템플릿. 가중치 추첨의 단위.
class EventSpec {
  const EventSpec({
    required this.id,
    required this.scope,
    required this.weight,
    required this.headline,
    required this.effect,
    this.exchangeId,
  })  : assert(weight > 0),
        assert(scope != EventScope.exchange || exchangeId != null);

  final String id;
  final EventScope scope;

  /// scope == exchange일 때 대상 거래소 (테이블에서 고정 지정).
  final ExchangeId? exchangeId;

  /// 추첨 가중치 (상대값).
  final double weight;

  /// 아침 뉴스 헤드라인 템플릿. '{stock}', '{sector}' 플레이스홀더 지원.
  final String headline;

  final EventEffect effect;

  /// 호재 여부 (UI 색상·힌트용). jump 기준으로 판단.
  bool get isGood => effect.jump >= 1.0 && effect.muBonus >= 0;
}

/// 추첨되어 시장에 적용 중인 이벤트 인스턴스.
class ActiveEvent {
  ActiveEvent({
    required this.spec,
    required this.startDay,
    this.stockCode,
    this.sectorId,
  })  : remainingDays = spec.effect.durationDays,
        assert(spec.scope != EventScope.stock || stockCode != null),
        assert(spec.scope != EventScope.sector || sectorId != null);

  final EventSpec spec;
  final int startDay;

  /// scope == stock일 때 대상 종목 코드.
  final String? stockCode;

  /// scope == sector일 때 대상 섹터.
  final SectorId? sectorId;

  /// scope == exchange일 때 대상 거래소 (spec에서 복사).
  ExchangeId? get exchangeId => spec.exchangeId;

  int remainingDays;

  bool get isExpired => remainingDays <= 0;

  /// 플레이스홀더가 치환된 헤드라인.
  String resolveHeadline({String? stockName, String? sectorName}) {
    var text = spec.headline;
    if (stockName != null) text = text.replaceAll('{stock}', stockName);
    if (sectorName != null) text = text.replaceAll('{sector}', sectorName);
    return text;
  }
}
