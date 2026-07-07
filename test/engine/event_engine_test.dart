import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/engine/engine.dart';

void main() {
  group('EventEngine', () {
    test('하루 이벤트 발생 빈도가 목표 밴드(0.9~1.8건)에 들어온다', () {
      final engine = EventEngine(random: Random(1));
      final stocks = createInitialStocks();
      const nDays = 20000;

      var total = 0;
      for (var day = 1; day <= nDays; day++) {
        total += engine.rollMorning(day: day, listedStocks: stocks).length;
        engine.endDay();
      }

      // 랜덤 기대 ~1.2 + 정기 매크로 2/30 + 루머 후속.
      final perDay = total / nDays;
      expect(perDay, greaterThan(0.9));
      expect(perDay, lessThan(1.8));
    });

    test('가중치가 높은 이벤트가 더 자주 추첨된다', () {
      final engine = EventEngine(random: Random(2));
      final stocks = createInitialStocks();
      final counts = <String, int>{};
      for (var day = 1; day <= 30000; day++) {
        for (final e in engine.rollMorning(day: day, listedStocks: stocks)) {
          counts[e.spec.id] = (counts[e.spec.id] ?? 0) + 1;
        }
        engine.endDay();
      }

      // weight 10 (earnings_surprise) vs weight 2 (market_crash): 약 5배 차이
      final surprise = counts['earnings_surprise'] ?? 0;
      final crash = counts['market_crash'] ?? 0;
      expect(surprise, greaterThan(crash * 3));
      expect(crash, greaterThan(0));
    });

    test('종목 이벤트 효과는 대상 종목에만 적용된다', () {
      final engine = EventEngine(random: Random(3));
      final stocks = createInitialStocks();
      final target = stocks[0];
      final other = stocks[1];

      const spec = EventSpec(
        id: 'test_boost',
        scope: EventScope.stock,
        weight: 1,
        headline: '{stock} 테스트 호재',
        effect: EventEffect(muBonus: 0.5, sigmaMult: 1.5, durationDays: 2),
      );
      engine.active.add(
        ActiveEvent(spec: spec, startDay: 1, stockCode: target.code),
      );

      expect(engine.muBonusFor(target), closeTo(0.5, 1e-9));
      expect(engine.sigmaMultFor(target), closeTo(1.5, 1e-9));
      expect(engine.muBonusFor(other), 0.0);
      expect(engine.sigmaMultFor(other), 1.0);
    });

    test('시장 이벤트는 전 종목에, 섹터 이벤트는 해당 섹터에만 적용된다', () {
      final engine = EventEngine(random: Random(4));
      final stocks = createInitialStocks();
      final techStock = stocks.firstWhere((s) => s.sectorId == SectorId.tech);
      final bioStock = stocks.firstWhere((s) => s.sectorId == SectorId.bio);

      const marketSpec = EventSpec(
        id: 'test_market',
        scope: EventScope.market,
        weight: 1,
        headline: '시장 이벤트',
        effect: EventEffect(muBonus: -0.2, durationDays: 3),
      );
      const sectorSpec = EventSpec(
        id: 'test_sector',
        scope: EventScope.sector,
        weight: 1,
        headline: '{sector} 이벤트',
        effect: EventEffect(muBonus: 0.3, durationDays: 3),
      );
      engine.active
        ..add(ActiveEvent(spec: marketSpec, startDay: 1))
        ..add(ActiveEvent(
            spec: sectorSpec, startDay: 1, sectorId: SectorId.tech));

      expect(engine.muBonusFor(techStock), closeTo(-0.2 + 0.3, 1e-9));
      expect(engine.muBonusFor(bioStock), closeTo(-0.2, 1e-9));
    });

    test('거래소 이벤트(FOMC 등)는 해당 거래소 종목에만 적용된다', () {
      final engine = EventEngine(random: Random(6));
      final stocks = createInitialStocks();
      final krStock = stocks.firstWhere((s) => s.exchangeId == ExchangeId.krx);
      final usStock = stocks.firstWhere((s) => s.exchangeId == ExchangeId.us);

      const fomcSpec = EventSpec(
        id: 'test_fomc',
        scope: EventScope.exchange,
        exchangeId: ExchangeId.us,
        weight: 1,
        headline: '파월 의장 매파 발언',
        effect: EventEffect(muBonus: -0.3, durationDays: 5),
      );
      engine.active.add(ActiveEvent(spec: fomcSpec, startDay: 1));

      expect(engine.muBonusFor(usStock), closeTo(-0.3, 1e-9));
      expect(engine.muBonusFor(krStock), 0.0);
    });

    test('이벤트는 지속 일수가 지나면 만료된다', () {
      final engine = EventEngine(random: Random(5));
      final stocks = createInitialStocks();
      final target = stocks[0];

      const spec = EventSpec(
        id: 'test_expire',
        scope: EventScope.stock,
        weight: 1,
        headline: '만료 테스트',
        effect: EventEffect(muBonus: 1.0, durationDays: 2),
      );
      engine.active.add(
        ActiveEvent(spec: spec, startDay: 1, stockCode: target.code),
      );

      expect(engine.muBonusFor(target), closeTo(1.0, 1e-9)); // 1일차
      engine.endDay();
      expect(engine.muBonusFor(target), closeTo(1.0, 1e-9)); // 2일차
      engine.endDay();
      expect(engine.muBonusFor(target), 0.0); // 만료
      expect(engine.active, isEmpty);
    });

    test('헤드라인 플레이스홀더가 종목명·섹터명으로 치환된다', () {
      const spec = EventSpec(
        id: 'test_headline',
        scope: EventScope.stock,
        weight: 1,
        headline: '{stock}, 대형 호재 발표',
        effect: EventEffect(),
      );
      final event = ActiveEvent(spec: spec, startDay: 1, stockCode: '110001');

      expect(
        event.resolveHeadline(stockName: '한빛전자'),
        '한빛전자, 대형 호재 발표',
      );
    });
  });
}
