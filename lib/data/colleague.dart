/// 동료 성향. 근무 인터랙션 종류와 분위기를 가른다.
enum ColleagueTrait {
  smoker, // 담배타임 파트너
  foodie, // 회식러 — 저녁 회식으로 정보
  gossip, // 정보통 — 신뢰도 높음
  rookie, // 신입 — 신뢰도 낮지만 친해지기 쉬움
  workaholic, // 일벌레
}

extension ColleagueTraitX on ColleagueTrait {
  String get label => switch (this) {
        ColleagueTrait.smoker => '🚬 흡연',
        ColleagueTrait.foodie => '🍻 회식러',
        ColleagueTrait.gossip => '👂 정보통',
        ColleagueTrait.rookie => '🐣 신입',
        ColleagueTrait.workaholic => '💼 일벌레',
      };
}

/// 회사 동료. 담배타임·점심·회식·회의 등 근무 인터랙션의 상대이며,
/// 흘려주는 주식 정보의 신뢰도가 각자 다르다. 친밀도(rapport)는
/// [GameSession.rapport]에 별도 저장된다.
class Colleague {
  const Colleague({
    required this.id,
    required this.name,
    required this.avatarId,
    required this.trait,
    required this.reliability,
  });

  final String id;
  final String name;

  /// character_avatar.dart의 스타일 인덱스 재사용.
  final int avatarId;

  final ColleagueTrait trait;

  /// 정보 기본 적중률 0~1. 친밀도가 오르면 여기에 가산된다.
  final double reliability;

  bool get smokes => trait == ColleagueTrait.smoker;
}

/// 고정 동료 로스터. 흡연자·회식러 ≥1 보장.
const List<Colleague> kColleagues = [
  Colleague(
      id: 'kim',
      name: '김대리',
      avatarId: 0,
      trait: ColleagueTrait.smoker,
      reliability: 0.80),
  Colleague(
      id: 'lee',
      name: '이사원',
      avatarId: 2,
      trait: ColleagueTrait.rookie,
      reliability: 0.42),
  Colleague(
      id: 'park',
      name: '박과장',
      avatarId: 4,
      trait: ColleagueTrait.gossip,
      reliability: 0.90),
  Colleague(
      id: 'choi',
      name: '최부장',
      avatarId: 5,
      trait: ColleagueTrait.foodie,
      reliability: 0.62),
  Colleague(
      id: 'jung',
      name: '정선임',
      avatarId: 1,
      trait: ColleagueTrait.smoker,
      reliability: 0.70),
  Colleague(
      id: 'yoon',
      name: '윤차장',
      avatarId: 6,
      trait: ColleagueTrait.workaholic,
      reliability: 0.75),
];

List<Colleague> get kSmokers =>
    [for (final c in kColleagues) if (c.trait == ColleagueTrait.smoker) c];

List<Colleague> get kFoodies =>
    [for (final c in kColleagues) if (c.trait == ColleagueTrait.foodie) c];

/// 근무 중 얻은 종목 정보(팁). 오늘만 유효 — 직렬화하지 않는다.
class StockTip {
  StockTip({
    required this.stockCode,
    required this.bullish,
    required this.reliable,
    required this.fromName,
  });

  final String stockCode;

  /// true=상승 우세, false=하락 우세.
  final bool bullish;

  /// 고신뢰 동료면 '정보', 아니면 '소문'.
  final bool reliable;

  final String fromName;
}
