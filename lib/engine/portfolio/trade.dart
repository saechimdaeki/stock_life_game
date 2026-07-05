enum TradeSide { buy, sell }

/// 체결된 거래 1건의 기록.
class Trade {
  const Trade({
    required this.day,
    required this.tick,
    required this.code,
    required this.side,
    required this.quantity,
    required this.price,
    required this.fee,
    required this.tax,
  });

  final int day;
  final int tick;
  final String code;
  final TradeSide side;
  final int quantity;

  /// 체결 단가 (원).
  final double price;

  /// 거래 수수료 (원).
  final double fee;

  /// 매도 시 거래세 (원). 매수는 0.
  final double tax;

  /// 수수료·세금 제외 거래 대금.
  double get amount => price * quantity;

  /// 현금 변화량. 매수는 음수(대금+수수료 지출), 매도는 양수(대금-수수료-세금 수취).
  double get cashDelta =>
      side == TradeSide.buy ? -(amount + fee) : amount - fee - tax;
}
