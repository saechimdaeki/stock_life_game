import 'dart:math';

import '../engine/engine.dart';

/// 텔레그램형 속보 피드 항목.
class FeedItem {
  const FeedItem({
    required this.minute,
    required this.text,
    required this.tone, // 1 호재 / -1 악재 / 0 중립
    required this.channel,
  });

  final int minute;
  final String text;
  final int tone;
  final String channel;
}

/// 장중 간간히 올라오는 분위기용 속보 템플릿(가격엔 영향 없음 — 노이즈).
/// {stock}/{sector}는 실제 종목·섹터명으로 치환된다.
const List<({String text, int tone, String channel})> _flavor = [
  (text: '{stock} 관련 지라시 도는 중... "뭔가 있다더라"', tone: 1, channel: '지라시'),
  (text: '{stock}에 정체불명 대량 매수... 세력설 솔솔', tone: 1, channel: '속보'),
  (text: '외국인, {sector} 순매수 확대', tone: 1, channel: '수급'),
  (text: '{sector} 업황 둔화 우려 스멀스멀', tone: -1, channel: '코멘트'),
  (text: '{stock} 임원 지분 매도 공시', tone: -1, channel: '공시'),
  (text: '미국 선물 하락 출발... 관망세', tone: -1, channel: '해외'),
  (text: '환율 급등, 수입 비중 큰 종목 부담', tone: -1, channel: '매크로'),
  (text: '{stock} 신고가 경신 임박?', tone: 1, channel: '속보'),
  (text: '"{sector}가 다음 주도주" 증권가 리포트', tone: 1, channel: '증권가'),
  (text: '개미들 {stock} 커뮤니티 불타는 중 🔥', tone: 1, channel: '커뮤'),
  (text: '{stock} 공매도 잔고 증가', tone: -1, channel: '수급'),
  (text: '유가 반등에 에너지 관련주 들썩', tone: 1, channel: '매크로'),
  (text: '{stock} 사장 "주주가치 제고" 발언', tone: 1, channel: 'IR'),
  (text: '{sector} 규제 소식에 투심 위축', tone: -1, channel: '속보'),
  (text: '큰손 "{stock} 지금 담는다" 소문', tone: 1, channel: '지라시'),
  (text: '{stock} 목표가 상향 리포트 등장', tone: 1, channel: '증권가'),
  (text: '{stock} 목표가 하향... "실적 우려"', tone: -1, channel: '증권가'),
  (text: '기관 {sector} 차익실현 물량 출회', tone: -1, channel: '수급'),
  (text: '{stock} 신제품 반응 "생각보다 별로"', tone: -1, channel: '커뮤'),
  (text: '증시 대기 매수세 유입 기대', tone: 1, channel: '코멘트'),
  (text: '{stock} 대주주 블록딜 루머', tone: -1, channel: '지라시'),
  (text: '{sector} 테마 다시 꿈틀?', tone: 1, channel: '테마'),
  (text: '"오늘 장 어렵다" 트레이더들 한숨', tone: -1, channel: '코멘트'),
  (text: '{stock} 실적 발표 D-1, 눈치보기', tone: 0, channel: '일정'),
  (text: '외국인·기관 동반 매도... 지수 흔들', tone: -1, channel: '수급'),
];

/// 실제 이벤트 방향과 일치하는 힌트 속보 문구(채널 '단독'). {stock} 치환.
const List<String> _hintGood = [
  '단독: {stock} 내부 분위기 심상찮다... "위로 본다"',
  '단독: {stock}에 큰손 자금 유입 정황 포착',
  '단독: {stock} 호재성 재료 임박설, 관계자 "곧 알게 될 것"',
  '단독: 기관, {stock} 조용히 모으는 중',
];

const List<String> _hintBad = [
  '단독: {stock} 내부서 흉흉한 소문... "미리 피하라"',
  '단독: {stock} 악재 터지기 직전이라는 제보',
  '단독: 큰손들 {stock} 물량 정리 중이라는 정황',
  '단독: {stock} 관계자 "당분간 쳐다보지 마라"',
];

/// 진행 중인 진짜 이벤트가 걸린 종목의 방향을 흘리는 힌트 속보.
/// 가격에 추가 영향은 없지만 방향은 진짜 — 피드를 읽을 이유가 생긴다.
/// 재료(활성 이벤트 종목)가 없으면 null.
FeedItem? rollHintNews(Random r, Market market, int minute) {
  final candidates = [
    for (final s in market.listedStocks)
      if (market.eventEngine.muBonusFor(s) != 0) s,
  ];
  if (candidates.isEmpty) return null;
  final stock = candidates[r.nextInt(candidates.length)];
  final bullish = market.eventEngine.muBonusFor(stock) > 0;
  final pool = bullish ? _hintGood : _hintBad;
  return FeedItem(
    minute: minute,
    text: pool[r.nextInt(pool.length)].replaceAll('{stock}', stock.name),
    tone: bullish ? 1 : -1,
    channel: '단독',
  );
}

/// 장중 속보 하나를 뽑아 종목/섹터명을 채워 만든다.
FeedItem rollFlavorNews(Random r, Market market, int minute) {
  final t = _flavor[r.nextInt(_flavor.length)];
  var text = t.text;
  if (text.contains('{stock}')) {
    final listed = market.listedStocks;
    if (listed.isNotEmpty) {
      text = text.replaceAll('{stock}', listed[r.nextInt(listed.length)].name);
    }
  }
  if (text.contains('{sector}')) {
    text = text.replaceAll('{sector}', kSectors[r.nextInt(kSectors.length)].nameKo);
  }
  return FeedItem(minute: minute, text: text, tone: t.tone, channel: t.channel);
}
