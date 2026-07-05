/// 거래소. 세션 시각은 GameClock의 분 축(자정 기준, 자정 초과분은 24시+)을 따른다.
enum ExchangeId { krx, us }

class Exchange {
  const Exchange({
    required this.id,
    required this.nameKo,
    required this.openMinute,
    required this.closeMinute,
    required this.currencySymbol,
  });

  final ExchangeId id;
  final String nameKo;

  /// 개장 시각 (자정 기준 분).
  final int openMinute;

  /// 폐장 시각 (자정 기준 분, 자정 초과 시 24시+ 표기: 30:00 = 1800).
  final int closeMinute;

  final String currencySymbol;

  bool isOpenAt(int minuteOfDay) =>
      minuteOfDay >= openMinute && minuteOfDay < closeMinute;

  /// 하루 세션 틱 수 (연환산 dt 계산용).
  int ticksPerSession(int minutesPerTick) =>
      (closeMinute - openMinute) ~/ minutesPerTick;
}

/// 국장: 09:00~15:30 (근무시간과 겹침 - 눈치 매매의 무대).
const Exchange kKrxExchange = Exchange(
  id: ExchangeId.krx,
  nameKo: '국장',
  openMinute: 9 * 60,
  closeMinute: 15 * 60 + 30,
  currencySymbol: '원',
);

/// 미장: 23:30~06:00 (한국시간). 02:00 취침 이후는 오버나이트 정산.
const Exchange kUsExchange = Exchange(
  id: ExchangeId.us,
  nameKo: '미장',
  openMinute: 23 * 60 + 30,
  closeMinute: 30 * 60, // 익일 06:00
  currencySymbol: r'$',
);

const List<Exchange> kExchanges = [kKrxExchange, kUsExchange];

Exchange exchangeOf(ExchangeId id) =>
    kExchanges.firstWhere((e) => e.id == id);

/// MVP 고정 환율. 변동 환율은 이후 확장.
const double kUsdKrw = 1400.0;
