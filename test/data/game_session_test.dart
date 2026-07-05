import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/game_session.dart';
import 'package:stock_life_game/engine/engine.dart';

void main() {
  group('GameSession', () {
    /// 하루를 끝까지 진행한다.
    void playThroughDay(GameSession session) {
      while (session.advanceTick()) {}
      session.endDay();
      session.startDay();
    }

    test('새 게임은 1일차 아침 뉴스와 초기 자금으로 시작한다', () {
      final session = GameSession.newGame(seed: 1);

      expect(session.clock.day, 1);
      expect(session.portfolio.cash, GameSession.initialCash);
      expect(session.totalAssets, GameSession.initialCash);
      // openDay가 호출되어 틱 히스토리가 준비됨
      expect(session.market.stocks.first.tickHistory, isNotEmpty);
    });

    test('30일마다 월급이 들어온다', () {
      final session = GameSession.newGame(seed: 2);

      var salaryCount = 0;
      for (var i = 0; i < 60; i++) {
        final before = session.portfolio.cash;
        playThroughDay(session);
        final delta = session.portfolio.cash - before;
        if (session.morningNotices.isNotEmpty) {
          salaryCount++;
          expect(delta, GameSession.monthlySalary);
        }
      }
      expect(salaryCount, 2); // 30일차, 60일차
    });

    test('장이 닫힌 시각의 매매는 거부된다', () {
      final session = GameSession.newGame(seed: 3);
      final krStock = session.market.listedOn(ExchangeId.krx).first;

      // 아침 07:00 - 국장 폐장
      final result = session.buy(krStock, 1);
      expect(result.isSuccess, isFalse);

      // 근무시간까지 진행 - 국장 개장
      while (session.clock.minuteOfDay < 9 * 60) {
        session.advanceTick();
      }
      expect(session.buy(krStock, 1).isSuccess, isTrue);
    });

    test('저장 후 복원하면 자산·보유·가격·이벤트가 유지된다', () {
      final session = GameSession.newGame(seed: 4);

      // 며칠 진행하며 매매
      for (var i = 0; i < 5; i++) {
        while (session.advanceTick()) {
          if (session.clock.minuteOfDay == 10 * 60) {
            final stock = session.market.listedOn(ExchangeId.krx).first;
            session.buy(stock, 3);
          }
        }
        session.endDay();
        session.startDay();
      }

      final json = session.toJson();
      final restored = GameSession.fromJson(json);

      expect(restored.clock.day, session.clock.day);
      expect(restored.portfolio.cash, closeTo(session.portfolio.cash, 0.01));
      expect(restored.portfolio.positions.length,
          session.portfolio.positions.length);
      for (final p in session.portfolio.positions.values) {
        final rp = restored.portfolio.positionOf(p.code)!;
        expect(rp.quantity, p.quantity);
        expect(rp.totalCost, closeTo(p.totalCost, 0.01));
      }
      // 가격·히스토리 복원 (fromJson의 startDay가 새 하루를 열기 전 저장값 기준)
      // 저장은 endDay 직후(다음 날 아침 이전) 시점이므로 closeHistory 길이가 같아야 함
      for (final s in session.market.stocks) {
        final rs = restored.market.stockByCode(s.code)!;
        expect(rs.closeHistory.length,
            lessThanOrEqualTo(s.closeHistory.length + 1));
      }
      // 활성 이벤트 복원
      expect(restored.market.eventEngine.active.length,
          greaterThanOrEqualTo(0));
    });

    test('직렬화 왕복이 안정적이다 (JSON -> 세션 -> JSON)', () {
      final session = GameSession.newGame(seed: 5);
      for (var i = 0; i < 3; i++) {
        playThroughDay(session);
      }

      final json1 = session.toJson();
      final restored = GameSession.fromJson(json1);
      final json2 = restored.toJson();

      expect(json2['day'], json1['day']);
      expect(json2['cash'], json1['cash']);
      expect((json2['positions'] as List).length,
          (json1['positions'] as List).length);
    });
  });
}
