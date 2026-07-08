import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/game_session.dart';

/// 하루를 끝까지 돌리고 다음 날 아침으로 넘긴다.
void nextMorning(GameSession s) {
  while (s.advanceTick()) {}
  s.endDay();
  s.startDay();
}

/// [day]일 아침까지 진행.
void advanceToDay(GameSession s, int day) {
  while (s.clock.day < day) {
    nextMorning(s);
  }
}

void main() {
  group('인사평가', () {
    test('고과가 promoteScore 이상이면 평가일에 승진한다', () {
      final s = GameSession.newGame(seed: 7);
      s.addPerformance(GameSession.promoteScore);
      advanceToDay(s, GameSession.promotionIntervalDays);
      expect(s.rank, 1);
      expect(s.lastReview, ReviewOutcome.promoted);
      expect(s.performanceScore, 0, reason: '평가 후 고과 리셋');
    });

    test('고과가 warnScore 이하면 경고, 경고 2회면 해고된다', () {
      final s = GameSession.newGame(seed: 7);
      s.addPerformance(GameSession.warnScore);
      advanceToDay(s, GameSession.promotionIntervalDays);
      expect(s.warnings, 1);
      expect(s.lastReview, ReviewOutcome.warned);
      expect(s.fired, isFalse);

      s.addPerformance(GameSession.warnScore);
      advanceToDay(s, GameSession.promotionIntervalDays * 2);
      expect(s.warnings, 2);
      expect(s.fired, isTrue);
      expect(s.lastReview, ReviewOutcome.fired);
    });

    test('중간 고과는 유지 — 자동 승진은 더 이상 없다', () {
      final s = GameSession.newGame(seed: 7);
      advanceToDay(s, GameSession.promotionIntervalDays);
      expect(s.rank, 0);
      expect(s.lastReview, ReviewOutcome.stay);
    });

    test('해고되면 월급이 안 나온다', () {
      final s = GameSession.newGame(seed: 7);
      s.fired = true;
      advanceToDay(s, GameSession.salaryIntervalDays - 1);
      final cashBefore = s.portfolio.cash;
      nextMorning(s); // 월급날 아침
      expect(s.portfolio.cash, cashBefore, reason: '백수는 월급 없음');
    });
  });

  group('내부자 정보', () {
    test('딜 상태가 저장/복원을 넘어 유지된다', () {
      final s = GameSession.newGame(seed: 7);
      final code = s.market.listedStocks.first.code;
      s.insiderStockCode = code;
      s.insiderResolveDay = s.clock.day + 3;
      s.insiderFromId = 'oh';
      s.performanceScore = 3;
      s.warnings = 1;

      final restored = GameSession.fromJson(s.toJson());
      expect(restored.insiderStockCode, code);
      expect(restored.insiderResolveDay, s.clock.day + 3);
      expect(restored.insiderFromId, 'oh');
      expect(restored.performanceScore, 3);
      expect(restored.warnings, 1);
    });

    test('판정일 아침에 딜이 해소되고 결과가 남는다', () {
      final s = GameSession.newGame(seed: 7);
      final code = s.market.listedStocks.first.code;
      s.insiderStockCode = code;
      s.insiderResolveDay = s.clock.day + 3;
      advanceToDay(s, s.clock.day + 3);
      expect(s.insiderStockCode, isNull);
      expect(s.insiderResolveDay, isNull);
      expect(s.lastInsiderOutcome, isNotNull);
      if (s.lastInsiderOutcome == InsiderOutcome.caught) {
        expect(s.lastInsiderFine, greaterThan(0));
      }
    });

    test('적발되면 벌금이 현금에서 빠지고 고과 -5', () {
      // 적발(30%)이 나오는 시드를 찾아 결정적으로 검증.
      for (var seed = 0; seed < 60; seed++) {
        final s = GameSession.newGame(seed: seed);
        final code = s.market.listedStocks.first.code;
        s.insiderStockCode = code;
        s.insiderResolveDay = s.clock.day + 3;
        advanceToDay(s, s.clock.day + 3);
        if (s.lastInsiderOutcome != InsiderOutcome.caught) continue;
        expect(s.lastInsiderFine, greaterThan(0));
        expect(s.performanceScore, -5);
        return; // 적발 케이스 1회 검증 완료
      }
      fail('시드 0~59 중 적발 케이스가 없음 — 확률 로직 확인 필요');
    });
  });
}
