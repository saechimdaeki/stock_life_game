import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/engine/engine.dart';

/// 1,000일 몬테카를로 시뮬레이션으로 게임 밸런스를 검증한다.
///
/// 검증 지표:
/// - 가격이 NaN/무한대로 발산하거나 0으로 붕괴하지 않는지
/// - 이벤트 발생 빈도가 0.5~1.5건/일인지
/// - 균등 분산 바이앤홀드 수익률이 게임 난이도로서 적정 범위인지
void main() {
  /// 하루를 시계·시장 규칙대로 진행한다.
  void playDay(GameClock clock, Market market) {
    if (clock.day > 1) market.settleOvernight();
    market.openDay(clock.day);
    while (clock.advanceTick()) {
      market.advanceTick(clock.minuteOfDay);
    }
    market.closeDay();
    clock.nextDay();
  }

  group('1,000일 몬테카를로 시뮬레이션', () {
    test('밸런스 지표가 목표 범위에 들어온다', () {
      const nDays = 1000;
      final seeds = List.generate(20, (i) => i + 1);

      final buyHoldReturns = <double>[];
      final collapseRates = <double>[];
      final eventRates = <double>[];

      for (final seed in seeds) {
        final random = Random(seed);
        final clock = GameClock();
        final stocks = createInitialStocks();
        final market = Market(
          stocks: stocks,
          priceEngine: PriceEngine(random: random),
          eventEngine: EventEngine(random: random),
        );

        // IPO 대기 풀은 시뮬 내내 비상장(가격 불변)이므로 지표에서 제외.
        final universe =
            stocks.where((s) => s.status != ListingStatus.unlisted).toList();
        final initialKrw = {
          for (final s in universe) s.code: market.priceKrwOf(s)
        };
        var eventCount = 0;

        for (var day = 1; day <= nDays; day++) {
          expect(clock.day, day);
          playDay(clock, market);
          eventCount += market.todaysNews.length;
        }

        // --- 무결성 검증 (상장폐지된 종목은 히스토리가 짧을 수 있다) ---
        for (final stock in universe) {
          expect(stock.price.isFinite, isTrue,
              reason: '${stock.name} 가격 발산');
          expect(stock.price, greaterThan(0));
          expect(stock.closeHistory.length,
              stock.isListed ? nDays : lessThanOrEqualTo(nDays));
        }

        // --- 밸런스 지표 수집 (원화 환산 균등 바이앤홀드) ---
        var ratioSum = 0.0;
        var collapsed = 0;
        for (final stock in universe) {
          final ratio = market.priceKrwOf(stock) / initialKrw[stock.code]!;
          ratioSum += ratio;
          if (ratio < 0.1) collapsed++;
        }
        buyHoldReturns.add(ratioSum / universe.length - 1.0);
        collapseRates.add(collapsed / universe.length);
        eventRates.add(eventCount / nDays);
      }

      final sorted = [...buyHoldReturns]..sort();
      final medianReturn = sorted[sorted.length ~/ 2];
      final avgReturn =
          buyHoldReturns.reduce((a, b) => a + b) / buyHoldReturns.length;
      final avgEventRate =
          eventRates.reduce((a, b) => a + b) / eventRates.length;
      final avgCollapseRate =
          collapseRates.reduce((a, b) => a + b) / collapseRates.length;

      // --- 밸런스 리포트 ---
      // ignore: avoid_print
      print('=== 몬테카를로 밸런스 리포트 (${seeds.length}회 x $nDays일, 국장15+미장10) ===');
      // ignore: avoid_print
      print('균등 바이앤홀드 수익률: '
          '중앙값 ${(medianReturn * 100).toStringAsFixed(1)}% | '
          '평균 ${(avgReturn * 100).toStringAsFixed(1)}% | '
          '최소 ${(buyHoldReturns.reduce(min) * 100).toStringAsFixed(1)}% | '
          '최대 ${(buyHoldReturns.reduce(max) * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('이벤트 발생: 평균 ${avgEventRate.toStringAsFixed(2)}건/일');
      // ignore: avoid_print
      print('붕괴 종목(가격 <10%) 비율: '
          '${(avgCollapseRate * 100).toStringAsFixed(1)}%');

      // --- 밸런스 어서션 (넉넉한 밴드) ---
      expect(avgEventRate, greaterThan(0.5));
      expect(avgEventRate, lessThan(1.5));

      // 1,000일 ≈ 게임 내 4.2년. 분산투자 기대수익이 양수이되
      // 아무 조작 없이 수 배가 되는 인플레 밸런스는 아님을 확인.
      // 수익률 분포는 롱테일이므로 평균 대신 중앙값으로 판정한다.
      expect(medianReturn, greaterThan(-0.3));
      expect(medianReturn, lessThan(1.5));

      // 무작위 붕괴가 게임을 망칠 수준(절반 이상)은 아님
      expect(avgCollapseRate, lessThan(0.5));
    });

    test('국장은 낮에만, 미장은 밤에만 움직인다', () {
      final random = Random(42);
      final clock = GameClock();
      final stocks = createInitialStocks();
      final market = Market(
        stocks: stocks,
        priceEngine: PriceEngine(random: random),
        eventEngine: EventEngine(random: random, specs: []), // 이벤트 차단
      );
      final kr = stocks.firstWhere((s) => s.exchangeId == ExchangeId.krx);
      final us = stocks.firstWhere((s) => s.exchangeId == ExchangeId.us);

      market.openDay(1);
      final krOpen = kr.price;
      final usOpen = us.price;

      // 아침(07:15~08:45): 아무도 안 움직임
      while (clock.minuteOfDay < 9 * 60 - 15) {
        clock.advanceTick();
        market.advanceTick(clock.minuteOfDay);
      }
      expect(kr.price, krOpen);
      expect(us.price, usOpen);

      // 국장 세션(09:00~15:30): 국장만 움직임
      while (clock.minuteOfDay < 15 * 60 + 30) {
        clock.advanceTick();
        market.advanceTick(clock.minuteOfDay);
      }
      expect(kr.price, isNot(krOpen));
      expect(us.price, usOpen);
      final krClose = kr.price;

      // 저녁~미장(23:30~01:45): 미장만 움직임
      while (clock.advanceTick()) {
        market.advanceTick(clock.minuteOfDay);
      }
      expect(kr.price, krClose);
      expect(us.price, isNot(usOpen));

      // 오버나이트 정산(02:00~06:00): 미장만 추가로 움직임
      final usBeforeSleep = us.price;
      market.settleOvernight();
      expect(kr.price, krClose);
      expect(us.price, isNot(usBeforeSleep));

      // 매매 가능 여부는 거래소 개장 시각을 따른다
      expect(market.isTradableAt(kr, 10 * 60), isTrue); // 10:00
      expect(market.isTradableAt(kr, 16 * 60), isFalse); // 16:00
      expect(market.isTradableAt(us, 10 * 60), isFalse);
      expect(market.isTradableAt(us, 24 * 60), isTrue); // 00:00
    });

    test('시뮬레이션 중 매매·정산이 무결성을 유지한다', () {
      final random = Random(99);
      final clock = GameClock();
      final stocks = createInitialStocks();
      final market = Market(
        stocks: stocks,
        priceEngine: PriceEngine(random: random),
        eventEngine: EventEngine(random: random),
      );
      final portfolio = Portfolio(initialCash: 10000000);
      final trader = Random(100);

      for (var day = 1; day <= 200; day++) {
        if (day > 1) market.settleOvernight();
        market.openDay(day);
        while (clock.advanceTick()) {
          market.advanceTick(clock.minuteOfDay);

          // 무작위 매매 (게임 플레이 흉내) - 개장 중인 종목만
          if (trader.nextDouble() < 0.1) {
            final stock = stocks[trader.nextInt(stocks.length)];
            if (!market.isTradableAt(stock, clock.minuteOfDay)) continue;
            if (trader.nextBool()) {
              final budget = portfolio.cash * 0.2;
              final priceKrw = market.priceKrwOf(stock);
              final qty = budget ~/ priceKrw;
              if (qty > 0) {
                portfolio.buy(stock.code, priceKrw, qty,
                    day: day, tick: clock.minuteOfDay);
              }
            } else {
              final position = portfolio.positionOf(stock.code);
              if (position != null) {
                portfolio.sell(
                    stock.code, market.priceKrwOf(stock), position.quantity,
                    day: day, tick: clock.minuteOfDay);
              }
            }
          }
        }
        market.closeDay();
        clock.nextDay();
      }

      // 무결성: 현금은 음수가 될 수 없고, 총자산은 유한해야 한다
      expect(portfolio.cash, greaterThanOrEqualTo(0));
      expect(portfolio.totalAssets(market.prices).isFinite, isTrue);

      // 검산: 총자산 = 초기자산 + 실현손익 + 미실현손익
      final assets = portfolio.totalAssets(market.prices);
      final reconstructed = portfolio.initialAssets +
          portfolio.realizedPnl +
          portfolio.unrealizedPnl(market.prices);
      expect(assets, closeTo(reconstructed, 1.0));
    });
  });
}
