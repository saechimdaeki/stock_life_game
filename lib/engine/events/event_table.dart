import '../market/exchange.dart';
import 'game_event.dart';

/// MVP 이벤트 테이블. 밸런스 튜닝은 simulation_test의 몬테카를로 리포트로 검증한다.
///
/// IPO·상장폐지 이벤트는 Phase 3에서 추가 예정.
const List<EventSpec> kEventTable = [
  // ---- 종목 이벤트 ----
  EventSpec(
    id: 'earnings_surprise',
    scope: EventScope.stock,
    weight: 10,
    headline: '{stock}, 분기 실적 어닝 서프라이즈',
    effect: EventEffect(jump: 1.12, muBonus: 0.40, durationDays: 3),
  ),
  EventSpec(
    id: 'earnings_shock',
    scope: EventScope.stock,
    weight: 10,
    headline: '{stock}, 실적 쇼크에 투자자 실망',
    effect: EventEffect(jump: 0.89, muBonus: -0.40, durationDays: 3),
  ),
  EventSpec(
    id: 'new_product',
    scope: EventScope.stock,
    weight: 8,
    headline: '{stock}, 혁신 신제품 공개에 시장 주목',
    effect: EventEffect(jump: 1.08, muBonus: 0.60, durationDays: 5),
  ),
  EventSpec(
    id: 'big_contract',
    scope: EventScope.stock,
    weight: 6,
    headline: '{stock}, 대형 수주 계약 체결',
    effect: EventEffect(jump: 1.10, muBonus: 0.50, durationDays: 4),
  ),
  EventSpec(
    id: 'embezzlement',
    scope: EventScope.stock,
    weight: 3,
    headline: '{stock} 경영진 횡령 혐의 적발... 검찰 수사 착수',
    effect:
        EventEffect(jump: 0.75, muBonus: -0.80, sigmaMult: 1.8, durationDays: 7),
  ),
  EventSpec(
    id: 'recall',
    scope: EventScope.stock,
    weight: 5,
    headline: '{stock}, 주력 제품 대규모 리콜 결정',
    effect: EventEffect(jump: 0.90, muBonus: -0.50, durationDays: 4),
  ),
  EventSpec(
    id: 'rights_issue',
    scope: EventScope.stock,
    weight: 5,
    headline: '{stock}, 대규모 유상증자 발표',
    effect: EventEffect(jump: 0.93, muBonus: -0.20, durationDays: 3),
  ),
  EventSpec(
    id: 'rumor_pump',
    scope: EventScope.stock,
    weight: 4,
    headline: '{stock}에 정체불명 매수세... 작전 루머 확산',
    effect:
        EventEffect(jump: 1.05, muBonus: 0.10, sigmaMult: 2.0, durationDays: 3),
  ),
  EventSpec(
    id: 'analyst_upgrade',
    scope: EventScope.stock,
    weight: 8,
    headline: '증권가, {stock} 목표가 상향... "지금이 매수 기회"',
    effect: EventEffect(jump: 1.04, muBonus: 0.30, durationDays: 2),
  ),
  EventSpec(
    id: 'analyst_downgrade',
    scope: EventScope.stock,
    weight: 8,
    headline: '증권가, {stock} 투자의견 하향 조정',
    effect: EventEffect(jump: 0.96, muBonus: -0.30, durationDays: 2),
  ),

  // ---- 섹터 이벤트 ----
  EventSpec(
    id: 'theme_boom',
    scope: EventScope.sector,
    weight: 4,
    headline: '{sector} 테마 열풍! 관련주 일제히 강세',
    effect:
        EventEffect(jump: 1.08, muBonus: 0.80, sigmaMult: 1.4, durationDays: 5),
  ),
  // 주의: 호재/악재 쌍은 가중치·점프·드리프트를 대칭으로 유지할 것.
  // 비대칭이면 전 종목에 공짜 드리프트가 생겨 바이앤홀드 밸런스가 무너진다
  // (simulation_test의 몬테카를로 리포트로 검증).
  EventSpec(
    id: 'theme_bust',
    scope: EventScope.sector,
    weight: 4,
    headline: '{sector} 업황 부진 우려 확산... 관련주 급락',
    effect: EventEffect(jump: 0.93, muBonus: -0.80, durationDays: 5),
  ),

  // ---- 거래소 매크로 이벤트 ----
  EventSpec(
    id: 'fomc_hawkish',
    scope: EventScope.exchange,
    exchangeId: ExchangeId.us,
    weight: 4,
    headline: '파월 의장 "굿 애프터눈"... 매파 발언에 미장 긴장',
    effect: EventEffect(jump: 0.96, muBonus: -0.30, sigmaMult: 1.3, durationDays: 5),
  ),
  EventSpec(
    id: 'fomc_dovish',
    scope: EventScope.exchange,
    exchangeId: ExchangeId.us,
    weight: 4,
    headline: '파월 의장 "굿 애프터눈"... 금리 인하 시사에 미장 환호',
    effect: EventEffect(jump: 1.04, muBonus: 0.30, durationDays: 5),
  ),
  EventSpec(
    id: 'us_cpi_hot',
    scope: EventScope.exchange,
    exchangeId: ExchangeId.us,
    weight: 4,
    headline: '미국 CPI 예상치 상회... 인플레 공포 재점화',
    effect: EventEffect(jump: 0.95, muBonus: -0.25, durationDays: 3),
  ),
  EventSpec(
    id: 'us_jobs_strong',
    scope: EventScope.exchange,
    exchangeId: ExchangeId.us,
    weight: 4,
    headline: '미국 고용지표 서프라이즈... 경기 연착륙 기대',
    effect: EventEffect(jump: 1.05, muBonus: 0.25, durationDays: 3),
  ),
  EventSpec(
    id: 'kr_export_boom',
    scope: EventScope.exchange,
    exchangeId: ExchangeId.krx,
    weight: 4,
    headline: '반도체 수출 호조... 국장에 훈풍',
    effect: EventEffect(jump: 1.03, muBonus: 0.20, durationDays: 4),
  ),
  EventSpec(
    id: 'kr_regulation',
    scope: EventScope.exchange,
    exchangeId: ExchangeId.krx,
    weight: 4,
    headline: '금융당국 규제 리스크 부각... 국장 투자심리 위축',
    effect: EventEffect(jump: 0.97, muBonus: -0.20, sigmaMult: 1.4, durationDays: 4),
  ),

  // ---- 시장 전체 이벤트 ----
  EventSpec(
    id: 'rate_hike',
    scope: EventScope.market,
    weight: 5,
    headline: '중앙은행 기준금리 인상... 증시 부담',
    effect: EventEffect(jump: 0.97, muBonus: -0.15, durationDays: 10),
  ),
  EventSpec(
    id: 'rate_cut',
    scope: EventScope.market,
    weight: 5,
    headline: '중앙은행 기준금리 인하... 유동성 기대감',
    effect: EventEffect(jump: 1.03, muBonus: 0.15, durationDays: 10),
  ),
  EventSpec(
    id: 'market_crash',
    scope: EventScope.market,
    weight: 2,
    headline: '글로벌 증시 폭락! 공포지수 급등',
    effect:
        EventEffect(jump: 0.90, muBonus: -0.50, sigmaMult: 1.8, durationDays: 5),
  ),
  EventSpec(
    id: 'market_rally',
    scope: EventScope.market,
    weight: 2,
    headline: '글로벌 유동성 랠리! 위험자산 일제히 급등',
    effect: EventEffect(jump: 1.11, muBonus: 0.50, durationDays: 5),
  ),
];

/// 하루에 발생하는 이벤트 개수 분포 (인덱스 = 개수, 값 = 확률).
/// 기대값 약 0.9건/일 - 목표 밴드 0.5~1.5건.
const List<double> kDailyEventCountDist = [0.35, 0.45, 0.15, 0.05];
