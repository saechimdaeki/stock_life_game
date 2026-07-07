import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/game_session.dart';
import 'package:stock_life_game/engine/engine.dart';

void main() {
  group('변동 환율', () {
    test('환율은 매일 움직이되 밴드(1250~1550)를 벗어나지 않는다', () {
      final session = GameSession.newGame(seed: 11);
      final seen = <double>{};
      for (var d = 0; d < 200; d++) {
        seen.add(session.market.usdKrw);
        expect(session.market.usdKrw, inInclusiveRange(1250, 1550));
        while (session.advanceTick()) {}
        session.endDay();
        session.startDay();
      }
      expect(seen.length, greaterThan(1)); // 실제로 움직인다
    });

    test('미장 원화 환산가는 현재 환율을 따른다', () {
      final session = GameSession.newGame(seed: 12);
      final us = session.market.stocks
          .firstWhere((s) => s.exchangeId == ExchangeId.us && s.isListed);
      session.market.usdKrw = 1500;
      expect(session.market.priceKrwOf(us), us.price * 1500);
      expect(session.market.prices[us.code], us.price * 1500);
    });

    test('환율은 저장/복원을 거쳐도 유지된다', () {
      final session = GameSession.newGame(seed: 13);
      session.market.usdKrw = 1490;
      final restored = GameSession.fromJson(session.toJson());
      // 복원 시 startDay의 하루 워크 1회만 적용된다 (±0.6% 수준).
      expect(restored.market.usdKrw, closeTo(1490, 1490 * 0.05));
    });
  });

  group('상장폐지 / IPO', () {
    test('종가가 바닥까지 붕괴하면 장마감에 상장폐지된다', () {
      final session = GameSession.newGame(seed: 21);
      final victim = session.market.listedStocks
          .firstWhere((s) => s.exchangeId == ExchangeId.krx);
      victim.price = Market.minPriceKrx; // 바닥
      while (session.advanceTick()) {}
      victim.price = Market.minPriceKrx;
      session.endDay();
      expect(victim.isListed, isFalse);
      expect(session.market.delistedYesterday, contains(victim.name));
      // 다음 날 아침 공지에 뜬다.
      session.startDay();
      expect(session.morningNotices.any((n) => n.contains('상장폐지')), isTrue);
    });

    test('IPO 풀에서 상장하면 목록에 나타나고 풀이 마르면 null', () {
      final session = GameSession.newGame(seed: 22);
      final market = session.market;
      final before = market.listedStocks.length;
      final pool = market.stocks
          .where((s) => s.status == ListingStatus.unlisted)
          .length;
      expect(pool, greaterThan(0));

      final rng = Random(0);
      for (var i = 0; i < pool; i++) {
        final ipo = market.debutIpo(rng);
        expect(ipo, isNotNull);
        expect(ipo!.isListed, isTrue);
        expect(ipo.candleHistory, isNotEmpty); // 짧은 더미 히스토리
      }
      expect(market.listedStocks.length, before + pool);
      expect(market.debutIpo(rng), isNull); // 풀 소진
    });

    test('비상장(IPO 대기) 종목은 시장 목록·가격 스냅샷에 없다', () {
      final session = GameSession.newGame(seed: 23);
      final unlisted = session.market.stocks
          .firstWhere((s) => s.status == ListingStatus.unlisted);
      expect(session.market.listedStocks.contains(unlisted), isFalse);
      expect(session.market.prices.containsKey(unlisted.code), isFalse);
    });

    test('상장 상태는 저장/복원을 거쳐도 유지된다', () {
      final session = GameSession.newGame(seed: 24);
      final market = session.market;
      final ipo = market.debutIpo(Random(0))!;
      final dead = market.listedStocks.firstWhere((s) => s.code != ipo.code);
      dead.status = ListingStatus.delisted;

      final restored = GameSession.fromJson(session.toJson());
      expect(restored.market.stockByCode(ipo.code)!.isListed, isTrue);
      expect(restored.market.stockByCode(dead.code)!.status,
          ListingStatus.delisted);
    });
  });

  group('업적 / 엔딩', () {
    test('첫 매매·자산 마일스톤 업적이 열리고 중복 달성되지 않는다', () {
      final session = GameSession.newGame(seed: 31);
      expect(session.checkAchievements(), isEmpty);

      final stock = session.market.listedStocks.firstWhere(
          (s) => session.market.isTradableAt(s, session.clock.minuteOfDay),
          orElse: () => session.market.listedStocks.first);
      // 아침엔 장이 닫혀 있을 수 있으니 개장까지 진행.
      while (!session.market.isTradableAt(stock, session.clock.minuteOfDay)) {
        session.advanceTick();
      }
      session.buy(stock, 1);
      var newly = session.checkAchievements();
      expect(newly.map((a) => a.id), contains('first_trade'));

      session.portfolio.cash += 1000000000;
      newly = session.checkAchievements();
      final ids = newly.map((a) => a.id).toList();
      expect(ids, containsAll(['assets_20m', 'assets_100m', 'assets_1b']));
      expect(session.checkAchievements(), isEmpty); // 재달성 없음
    });

    test('업적·엔딩 플래그는 저장/복원을 거쳐도 유지된다', () {
      final session = GameSession.newGame(seed: 32);
      session.achievements.addAll(['first_trade', 'assets_1b']);
      session.endingSeen = true;
      final restored = GameSession.fromJson(session.toJson());
      expect(restored.achievements, containsAll(['first_trade', 'assets_1b']));
      expect(restored.endingSeen, isTrue);
    });

    test('구버전 세이브(업적/환율 없음)도 로드된다', () {
      final session = GameSession.newGame(seed: 33);
      final json = session.toJson()
        ..remove('usdKrw')
        ..remove('achievements')
        ..remove('endingSeen');
      final restored = GameSession.fromJson(json);
      expect(restored.achievements, isEmpty);
      expect(restored.endingSeen, isFalse);
      expect(restored.market.usdKrw, inInclusiveRange(1250, 1550));
    });
  });
}
