/// 업적 정의. 달성 조건 판정은 GameSession._achieved(id)에 있다.
class Achievement {
  const Achievement(this.id, this.emoji, this.title, this.desc);

  final String id;
  final String emoji;
  final String title;
  final String desc;
}

const List<Achievement> kAchievements = [
  Achievement('first_trade', '🐣', '주식 입문', '첫 매매를 체결한다'),
  Achievement('profit_10m', '💰', '수익 실현의 맛', '실현손익 누계 +1,000만원'),
  Achievement('assets_20m', '📈', '종잣돈 두 배', '총자산 2,000만원 달성'),
  Achievement('assets_50m', '🚀', '흙수저 탈출 중', '총자산 5,000만원 달성'),
  Achievement('assets_100m', '🏆', '1억의 사나이', '총자산 1억원 달성'),
  Achievement('assets_1b', '👑', '경제적 자유', '총자산 10억원 달성 — 엔딩'),
  Achievement('bestie', '🤝', '단짝', '동료 한 명과 친밀도 100'),
  Achievement('manager', '💼', '중간관리자', '과장으로 승진'),
  Achievement('executive', '🎩', '별을 달다', '임원으로 승진'),
  Achievement('day_30', '📅', '한 달 생존', 'Day 30 도달'),
  Achievement('day_100', '🗓', '백일잔치', 'Day 100 도달'),
];
