/// 게임 내 시간. 실제 시각(분 단위) 기반으로 하루를 진행한다.
///
/// 하루 타임라인 (1틱 = 15분):
///   07:00 기상(아침 뉴스) -> 09:00~18:00 근무(고정) -> 저녁 -> 23:30 미장 개장
///   -> 02:00 취침(하루 종료). 취침 중 미장 잔여 세션은 오버나이트 정산.
/// 실시간 타이머는 UI 계층 책임이며, 엔진은 [advanceTick]/[nextDay]만 노출한다.
enum DayPhase {
  /// 07:00~09:00 출근 전.
  morning,

  /// 09:00~18:00 근무 (고정). 국장 눈치 매매 구간.
  work,

  /// 18:00~23:30 퇴근 후 자유시간.
  evening,

  /// 23:30~02:00 미장 시간. 늦게까지 보면 컨디션 대가(Phase 3).
  night,
}

class GameClock {
  /// 기상 07:00.
  static const int dayStartMinute = 7 * 60;

  /// 취침 익일 02:00. 분 축은 자정을 넘어 계속 증가한다 (26:00 = 1560).
  static const int dayEndMinute = 26 * 60;

  /// 근무시간 09:00~18:00 고정.
  static const int workStartMinute = 9 * 60;
  static const int workEndMinute = 18 * 60;

  /// 미장 개장 23:30.
  static const int nightStartMinute = 23 * 60 + 30;

  static const int minutesPerTick = 15;

  /// 하루 진행 가능 틱 수: (26:00 - 07:00) / 15분 = 76틱.
  static const int ticksPerDay =
      (dayEndMinute - dayStartMinute) ~/ minutesPerTick;

  /// 1일차부터 시작.
  int day = 1;

  /// 자정 기준 경과 분. 07:00(420) ~ 26:00(1560).
  int minuteOfDay = dayStartMinute;

  DayPhase get phase {
    if (minuteOfDay < workStartMinute) return DayPhase.morning;
    if (minuteOfDay < workEndMinute) return DayPhase.work;
    if (minuteOfDay < nightStartMinute) return DayPhase.evening;
    return DayPhase.night;
  }

  bool get isWorking => phase == DayPhase.work;

  bool get isDayOver => minuteOfDay >= dayEndMinute;

  /// 15분 진행. 취침 시각(02:00)에 도달하면 false를 반환한다.
  bool advanceTick() {
    if (isDayOver) return false;
    minuteOfDay += minutesPerTick;
    return !isDayOver;
  }

  /// 다음 날 아침 07:00으로 넘어간다.
  void nextDay() {
    day += 1;
    minuteOfDay = dayStartMinute;
  }

  /// 'HH:MM' 표기 (자정 이후는 24를 감산해 00:15처럼 표시).
  String get timeLabel {
    final h = (minuteOfDay ~/ 60) % 24;
    final m = minuteOfDay % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
