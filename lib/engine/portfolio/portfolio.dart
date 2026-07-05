import 'trade.dart';

/// 보유 포지션. 평단가는 매수 수수료를 포함한 총 취득원가 기준.
class Position {
  Position({required this.code, this.quantity = 0, this.totalCost = 0});

  final String code;
  int quantity;

  /// 수수료 포함 총 취득원가 (원).
  double totalCost;

  double get avgPrice => quantity == 0 ? 0 : totalCost / quantity;
}

/// 매매 시도 결과. 실패 시 사유 메시지를 담는다.
class TradeResult {
  const TradeResult.success(Trade this.trade) : message = null;

  const TradeResult.failure(String this.message) : trade = null;

  final Trade? trade;
  final String? message;

  bool get isSuccess => trade != null;
}

/// 현금·보유 종목·거래 기록을 관리하고 손익을 정산한다.
/// 시장가 즉시 체결만 지원 (지정가는 이후 확장).
class Portfolio {
  Portfolio({
    required double initialCash,
    this.feeRate = 0.00015,
    this.taxRate = 0.002,
  })  : cash = initialCash,
        initialAssets = initialCash;

  /// 거래 수수료율 (매수·매도 각각 0.015%).
  final double feeRate;

  /// 매도 거래세율 (0.2%).
  final double taxRate;

  final double initialAssets;

  double cash;
  double realizedPnl = 0;

  final Map<String, Position> positions = {};
  final List<Trade> trades = [];

  Position? positionOf(String code) => positions[code];

  TradeResult buy(
    String code,
    double price,
    int quantity, {
    int day = 0,
    int tick = 0,
  }) {
    if (quantity <= 0) return const TradeResult.failure('수량은 1주 이상이어야 합니다');
    if (price <= 0) return const TradeResult.failure('유효하지 않은 가격입니다');

    final amount = price * quantity;
    final fee = amount * feeRate;
    if (amount + fee > cash) return const TradeResult.failure('현금이 부족합니다');

    final trade = Trade(
      day: day,
      tick: tick,
      code: code,
      side: TradeSide.buy,
      quantity: quantity,
      price: price,
      fee: fee,
      tax: 0,
    );

    cash += trade.cashDelta;
    final position = positions.putIfAbsent(code, () => Position(code: code));
    position.quantity += quantity;
    position.totalCost += amount + fee;
    trades.add(trade);
    return TradeResult.success(trade);
  }

  TradeResult sell(
    String code,
    double price,
    int quantity, {
    int day = 0,
    int tick = 0,
  }) {
    if (quantity <= 0) return const TradeResult.failure('수량은 1주 이상이어야 합니다');
    if (price <= 0) return const TradeResult.failure('유효하지 않은 가격입니다');

    final position = positions[code];
    if (position == null || position.quantity < quantity) {
      return const TradeResult.failure('보유 수량이 부족합니다');
    }

    final amount = price * quantity;
    final fee = amount * feeRate;
    final tax = amount * taxRate;

    final trade = Trade(
      day: day,
      tick: tick,
      code: code,
      side: TradeSide.sell,
      quantity: quantity,
      price: price,
      fee: fee,
      tax: tax,
    );

    final costBasis = position.avgPrice * quantity;
    realizedPnl += trade.cashDelta - costBasis;

    cash += trade.cashDelta;
    position.quantity -= quantity;
    position.totalCost -= costBasis;
    if (position.quantity == 0) positions.remove(code);
    trades.add(trade);
    return TradeResult.success(trade);
  }

  /// 보유 종목 평가액 합. [prices]는 종목 코드 -> 현재가.
  /// 가격 정보가 없는 종목(상장폐지 등)은 0원으로 평가된다.
  double stockValue(Map<String, double> prices) {
    var value = 0.0;
    for (final position in positions.values) {
      value += (prices[position.code] ?? 0) * position.quantity;
    }
    return value;
  }

  /// 총 자산 = 현금 + 보유 종목 평가액.
  double totalAssets(Map<String, double> prices) => cash + stockValue(prices);

  /// 미실현 손익 = 평가액 - 보유 취득원가.
  double unrealizedPnl(Map<String, double> prices) {
    var pnl = 0.0;
    for (final position in positions.values) {
      final price = prices[position.code];
      if (price == null) continue;
      pnl += price * position.quantity - position.totalCost;
    }
    return pnl;
  }
}
