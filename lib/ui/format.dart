import '../engine/engine.dart';

/// 천 단위 콤마.
String comma(num value) {
  final fixed = value is int || value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final buffer = StringBuffer();
  final digits = parts[0].replaceFirst('-', '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final sign = fixed.startsWith('-') ? '-' : '';
  return parts.length > 1 ? '$sign$buffer.${parts[1]}' : '$sign$buffer';
}

/// 원화 금액 (정수 원).
String won(num value) => '${comma(value.round())}원';

/// 거래소 통화로 종목 가격 표기.
String stockPrice(Stock stock) => stock.exchangeId == ExchangeId.us
    ? '\$${comma(stock.price)}'
    : '${comma(stock.price.round())}원';

/// 부호 있는 퍼센트 표기.
String signedPercent(double rate) {
  final sign = rate > 0 ? '+' : '';
  return '$sign${(rate * 100).toStringAsFixed(2)}%';
}

/// 부호 있는 원화 표기.
String signedWon(num value) => value >= 0 ? '+${won(value)}' : won(value);
