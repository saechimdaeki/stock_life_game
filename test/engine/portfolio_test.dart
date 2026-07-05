import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/engine/engine.dart';

void main() {
  group('Portfolio', () {
    test('매수 시 수수료를 포함해 현금이 차감되고 평단가에 반영된다', () {
      final portfolio = Portfolio(initialCash: 1000000);

      final result = portfolio.buy('110001', 10000, 10);

      expect(result.isSuccess, isTrue);
      // 대금 100,000 + 수수료 15 (0.015%)
      expect(portfolio.cash, closeTo(899985, 0.01));
      final position = portfolio.positionOf('110001')!;
      expect(position.quantity, 10);
      expect(position.avgPrice, closeTo(10001.5, 0.01));
    });

    test('현금 부족 시 매수가 거부된다', () {
      final portfolio = Portfolio(initialCash: 50000);

      final result = portfolio.buy('110001', 10000, 10);

      expect(result.isSuccess, isFalse);
      expect(result.message, isNotNull);
      expect(portfolio.cash, 50000);
      expect(portfolio.positionOf('110001'), isNull);
    });

    test('매도 시 수수료·세금을 반영해 실현손익이 계산된다', () {
      final portfolio = Portfolio(initialCash: 1000000);
      portfolio.buy('110001', 10000, 10);

      final result = portfolio.sell('110001', 11000, 10);

      expect(result.isSuccess, isTrue);
      // 매도 대금 110,000 - 수수료 16.5 - 세금 220 = 109,763.5
      // 취득원가 100,015 -> 실현손익 9,748.5
      expect(portfolio.realizedPnl, closeTo(9748.5, 0.01));
      expect(portfolio.cash, closeTo(1009748.5, 0.01));
      expect(portfolio.positionOf('110001'), isNull);
    });

    test('보유 수량 초과 매도는 거부된다', () {
      final portfolio = Portfolio(initialCash: 1000000);
      portfolio.buy('110001', 10000, 5);

      final result = portfolio.sell('110001', 10000, 10);

      expect(result.isSuccess, isFalse);
      expect(portfolio.positionOf('110001')!.quantity, 5);
    });

    test('분할 매수 시 평단가가 가중평균으로 갱신된다', () {
      final portfolio = Portfolio(initialCash: 1000000);
      portfolio.buy('110001', 10000, 10); // 취득원가 100,015
      portfolio.buy('110001', 20000, 10); // 취득원가 200,030

      final position = portfolio.positionOf('110001')!;
      expect(position.quantity, 20);
      expect(position.avgPrice, closeTo(300045 / 20, 0.01));
    });

    test('부분 매도 후 잔여 포지션의 평단가는 유지된다', () {
      final portfolio = Portfolio(initialCash: 1000000);
      portfolio.buy('110001', 10000, 10);
      final avgBefore = portfolio.positionOf('110001')!.avgPrice;

      portfolio.sell('110001', 12000, 4);

      final position = portfolio.positionOf('110001')!;
      expect(position.quantity, 6);
      expect(position.avgPrice, closeTo(avgBefore, 0.01));
    });

    test('총자산과 미실현손익이 현재가 기준으로 평가된다', () {
      final portfolio = Portfolio(initialCash: 1000000);
      portfolio.buy('110001', 10000, 10); // 현금 899,985

      final prices = {'110001': 12000.0};

      expect(portfolio.stockValue(prices), 120000);
      expect(portfolio.totalAssets(prices), closeTo(1019985, 0.01));
      // 평가액 120,000 - 취득원가 100,015
      expect(portfolio.unrealizedPnl(prices), closeTo(19985, 0.01));
    });

    test('0주 이하 주문은 거부된다', () {
      final portfolio = Portfolio(initialCash: 1000000);

      expect(portfolio.buy('110001', 10000, 0).isSuccess, isFalse);
      expect(portfolio.buy('110001', 10000, -5).isSuccess, isFalse);
      expect(portfolio.sell('110001', 10000, 0).isSuccess, isFalse);
    });
  });
}
