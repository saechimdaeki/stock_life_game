import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/engine/engine.dart';

Market _newMarket(int seed) {
  final random = Random(seed);
  return Market(
    stocks: createInitialStocks(),
    priceEngine: PriceEngine(random: random),
    eventEngine: EventEngine(random: random),
  );
}

void main() {
  group('2단계 루머 이벤트', () {
    test('루머가 만료되면 다음 날 아침 같은 종목에 확정/무산 후속이 뜬다', () {
      final market = _newMarket(1);
      final engine = market.eventEngine;
      final rumorSpec = kEventTable.firstWhere((s) => s.id == 'ma_rumor');
      final target = market.listedStocks.first;

      engine.active.add(
          ActiveEvent(spec: rumorSpec, startDay: 1, stockCode: target.code)
            ..remainingDays = 1);
      engine.endDay(); // 만료 → 후속 마킹
      expect(engine.pendingFollowUps, hasLength(1));

      final rolled =
          engine.rollMorning(day: 2, listedStocks: market.listedStocks);
      final followUp = rolled.firstWhere(
          (e) => e.spec.id == 'ma_confirmed' || e.spec.id == 'ma_collapse');
      expect(followUp.stockCode, target.code);
      expect(engine.pendingFollowUps, isEmpty);
    });

    test('후속 전용 스펙(weight 0)은 랜덤 추첨으로 나오지 않는다', () {
      final market = _newMarket(2);
      for (var day = 1; day <= 300; day++) {
        final rolled = market.eventEngine
            .rollMorning(day: day, listedStocks: market.listedStocks);
        for (final e in rolled) {
          // 후속·정기 전용은 조건 없이는 안 나온다.
          if (e.spec.id == 'ma_confirmed') {
            fail('ma_confirmed가 랜덤으로 나옴');
          }
        }
        market.eventEngine.endDay();
        // 루머가 만료 대기 중이면 비워서 후속 경로를 차단(랜덤만 검사).
        market.eventEngine.pendingFollowUps.clear();
      }
    });
  });

  group('정기 매크로 일정', () {
    test('주기 offset이 되는 날 CPI/FOMC 이벤트가 확정 발생한다', () {
      for (final entry in kMacroSchedule) {
        final market = _newMarket(3);
        final rolled = market.eventEngine.rollMorning(
            day: entry.offset, listedStocks: market.listedStocks);
        expect(
          rolled.any(
              (e) => e.spec.id == entry.goodId || e.spec.id == entry.badId),
          isTrue,
          reason: '${entry.label}이 day ${entry.offset}에 발생해야 함',
        );
      }
    });

    test('일정이 아닌 날엔 정기 매크로가 나오지 않는다', () {
      final market = _newMarket(4);
      final scheduledIds = {
        for (final e in kMacroSchedule) ...[e.goodId, e.badId]
      };
      final offsets = {for (final e in kMacroSchedule) e.offset};
      for (var day = 1; day <= 200; day++) {
        final rolled = market.eventEngine
            .rollMorning(day: day, listedStocks: market.listedStocks);
        if (!offsets.contains(day % kMacroCycleDays)) {
          expect(rolled.any((e) => scheduledIds.contains(e.spec.id)), isFalse,
              reason: 'day $day에 정기 매크로가 나옴');
        }
        market.eventEngine.endDay();
      }
    });
  });

  group('장중 돌발 이벤트', () {
    test('돌발 이벤트는 개장 종목을 대상으로 즉시 활성화된다', () {
      final market = _newMarket(5);
      final open = market.listedOn(ExchangeId.krx);
      // chance=1로 강제 발생.
      final event = market.eventEngine
          .maybeIntraday(day: 1, tradableStocks: open, chance: 1.0);
      expect(event, isNotNull);
      expect(event!.spec.scope, EventScope.stock);
      expect(open.any((s) => s.code == event.stockCode), isTrue);
      expect(market.eventEngine.active, contains(event));
    });

    test('장중 진행 중 돌발 속보가 대기열에 쌓인다 (확률적)', () {
      final market = _newMarket(6);
      market.openDay(1);
      var total = 0;
      // 200일치 국장 세션을 돌리면 돌발이 최소 몇 건은 터진다.
      for (var day = 1; day <= 200; day++) {
        for (var m = 9 * 60; m < 15 * 60 + 30; m += 15) {
          market.advanceTick(m);
        }
        total += market.intradayNewsBuffer.length;
        market.closeDay();
        market.openDay(day + 1);
      }
      expect(total, greaterThan(0));
    });
  });
}
