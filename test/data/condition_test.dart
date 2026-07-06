import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/colleague.dart';
import 'package:stock_life_game/data/game_session.dart';
import 'package:stock_life_game/data/news_feed.dart';
import 'package:stock_life_game/engine/engine.dart';

void main() {
  group('컨디션 시스템', () {
    test('회식하면 컨디션이 깎이고, 자면 회복된다 (취하면 덜 회복)', () {
      final session = GameSession.newGame(seed: 1);
      expect(session.condition, 100);

      session.applyDinnerFatigue();
      expect(session.condition, 75);

      // 취한 채 취침 → +20만 회복.
      session.drunk = true;
      while (session.advanceTick()) {}
      session.endDay();
      session.startDay();
      expect(session.condition, 95);

      // 맨정신 취침 → +30 (상한 100).
      while (session.advanceTick()) {}
      session.endDay();
      session.startDay();
      expect(session.condition, 100);
    });

    test('심야(미장) 매매는 하루 1회만 컨디션을 깎는다', () {
      final session = GameSession.newGame(seed: 2);
      // 심야로 진행.
      while (session.clock.phase != DayPhase.night) {
        session.advanceTick();
      }
      final stock = session.market.listedStocks
          .firstWhere((s) => session.market.isTradableAt(s, session.clock.minuteOfDay));

      expect(session.buy(stock, 1).isSuccess, isTrue);
      expect(session.condition, 90);
      expect(session.sell(stock, 1).isSuccess, isTrue);
      expect(session.condition, 90); // 두 번째 매매는 안 깎임
    });

    test('컨디션이 낮으면 미니게임 핸디캡과 피로 상태가 걸린다', () {
      final session = GameSession.newGame(seed: 3);
      expect(session.minigameHandicap, 0);
      expect(session.tooTired, isFalse);

      session.condition = 20;
      expect(session.minigameHandicap, 0.5);
      expect(session.tooTired, isTrue);

      session.condition = 0;
      expect(session.minigameHandicap, 1.0);
    });

    test('컨디션은 저장/복원을 거쳐도 유지되고, 구세이브는 100으로 시작한다', () {
      final session = GameSession.newGame(seed: 4);
      session.condition = 40;
      final json = session.toJson();

      // 복원 시 startDay가 수면 회복(+30)을 적용한다 — 라이브 흐름과 동일.
      final restored = GameSession.fromJson(json);
      expect(restored.condition, 70);

      final legacy = Map<String, dynamic>.from(json)..remove('condition');
      expect(GameSession.fromJson(legacy).condition, 100);
    });
  });

  group('힌트 속보', () {
    test('힌트 속보는 실제 활성 이벤트 방향과 일치한다', () {
      final session = GameSession.newGame(seed: 5);
      final engine = session.market.eventEngine;
      engine.active.clear();

      final goodSpec = kEventTable.firstWhere(
          (s) => s.scope == EventScope.stock && s.effect.muBonus > 0);
      final target = session.market.listedStocks.first;
      engine.active.add(
          ActiveEvent(spec: goodSpec, startDay: 1, stockCode: target.code));

      final rng = Random(0);
      for (var i = 0; i < 20; i++) {
        final item = rollHintNews(rng, session.market, 600);
        expect(item, isNotNull);
        expect(item!.channel, '단독');
        expect(item.tone, 1); // 호재 이벤트 → 호재 톤
        expect(item.text, contains(target.name));
      }
    });

    test('활성 이벤트가 없으면 힌트 속보는 null', () {
      final session = GameSession.newGame(seed: 6);
      session.market.eventEngine.active.clear();
      expect(rollHintNews(Random(0), session.market, 600), isNull);
    });
  });

  group('동료 심화', () {
    test('인싸·투자고수 동료가 로스터에 있고 아바타 3·7을 쓴다', () {
      expect(kInsiders, isNotEmpty);
      final investor = kColleagues
          .firstWhere((c) => c.trait == ColleagueTrait.investor);
      final insider = kInsiders.first;
      expect(insider.avatarId, 3);
      expect(investor.avatarId, 7);
      expect(investor.reliability, greaterThanOrEqualTo(0.9));
    });

    test('친밀도 100 일벌레는 아침 컨디션 보너스를 준다', () {
      final session = GameSession.newGame(seed: 7);
      final workaholic = kColleagues
          .firstWhere((c) => c.trait == ColleagueTrait.workaholic);
      session.addRapport(workaholic.id, 100);
      session.condition = 50;

      while (session.advanceTick()) {}
      session.endDay();
      session.startDay();
      // 수면 +30, 일벌레 +5.
      expect(session.condition, 85);
    });
  });
}
