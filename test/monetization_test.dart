import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/game_session.dart';

void main() {
  group('구제금융', () {
    test('자산이 임계 미만일 때만, 최대 횟수까지만 지급된다', () {
      final s = GameSession.newGame(seed: 42);
      // 초기 자산 1,000만원 — 임계(300만) 이상이라 신청 불가.
      expect(s.bailoutAvailable, isFalse);
      expect(s.applyBailout(), isNull);
      for (var i = 0; i < GameSession.maxBailouts; i++) {
        s.portfolio.cash = 1000000; // 파산 위기 상태로 강제
        expect(s.bailoutAvailable, isTrue);
        expect(s.applyBailout(), GameSession.bailoutAmount);
        expect(s.portfolio.cash, 1000000 + GameSession.bailoutAmount);
      }
      s.portfolio.cash = 1000000;
      expect(s.bailoutAvailable, isFalse); // 횟수 소진
      expect(s.applyBailout(), isNull);
    });
  });

  group('애널리스트 리포트', () {
    test('진짜 이벤트 방향을 알려주고 하루 1회로 제한된다', () {
      // 아침 이벤트 추첨이 시드마다 다르므로 재료가 있는 시드를 찾는다.
      GameSession? s;
      for (var seed = 0; seed < 50; seed++) {
        final candidate = GameSession.newGame(seed: seed);
        if (candidate.analystReportAvailable) {
          s = candidate;
          break;
        }
      }
      expect(s, isNotNull, reason: '재료가 있는 시드를 찾지 못함');
      final r = s!.runAnalystReport();
      expect(r, isNotNull);
      final stock = s.market.stockByCode(r!.tip.stockCode)!;
      // 리포트 방향은 항상 진짜(활성 이벤트의 드리프트 부호)와 일치.
      expect(r.tip.bullish, s.market.eventEngine.muBonusFor(stock) > 0);
      expect(r.tip.reliable, isTrue);
      // 시장 화면 💡 배지와 연동되는 todayTips에도 들어간다.
      expect(s.todayTips.any((t) => t.stockCode == stock.code), isTrue);
      // 같은 날 두 번은 불가.
      expect(s.analystReportAvailable, isFalse);
      expect(s.runAnalystReport(), isNull);
    });
  });

  test('광고 보상 상태 직렬화 왕복', () {
    final s = GameSession.newGame(seed: 1);
    s.bailoutsUsed = 2;
    s.analystReportDay = 3;
    final restored = GameSession.fromJson(s.toJson());
    expect(restored.bailoutsUsed, 2);
    expect(restored.analystReportDay, 3);
  });
}
