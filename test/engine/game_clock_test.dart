import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/engine/engine.dart';

void main() {
  group('GameClock', () {
    test('하루는 07:00에 시작해 02:00에 끝난다 (76틱)', () {
      final clock = GameClock();
      expect(clock.minuteOfDay, 7 * 60);
      expect(GameClock.ticksPerDay, 76);

      var ticks = 0;
      while (clock.advanceTick()) {
        ticks++;
      }
      // 마지막 advanceTick은 02:00 도달로 false를 반환하므로 75회 true + 1회 false
      expect(ticks, GameClock.ticksPerDay - 1);
      expect(clock.isDayOver, isTrue);
      expect(clock.timeLabel, '02:00');
    });

    test('시각에 따라 페이즈가 결정된다 (근무 09~18시 고정)', () {
      final clock = GameClock();

      clock.minuteOfDay = 7 * 60 + 30; // 07:30
      expect(clock.phase, DayPhase.morning);

      clock.minuteOfDay = 9 * 60; // 09:00 출근
      expect(clock.phase, DayPhase.work);
      expect(clock.isWorking, isTrue);

      clock.minuteOfDay = 17 * 60 + 45; // 17:45
      expect(clock.phase, DayPhase.work);

      clock.minuteOfDay = 18 * 60; // 18:00 퇴근
      expect(clock.phase, DayPhase.evening);

      clock.minuteOfDay = 23 * 60 + 30; // 23:30 미장 개장
      expect(clock.phase, DayPhase.night);

      clock.minuteOfDay = 25 * 60; // 01:00
      expect(clock.phase, DayPhase.night);
      expect(clock.timeLabel, '01:00');
    });

    test('nextDay로 다음 날 아침 07:00이 된다', () {
      final clock = GameClock();
      while (clock.advanceTick()) {}
      clock.nextDay();

      expect(clock.day, 2);
      expect(clock.minuteOfDay, GameClock.dayStartMinute);
      expect(clock.phase, DayPhase.morning);
    });

    test('거래소 세션: 국장은 근무시간과 겹치고 미장은 밤에 열린다', () {
      expect(kKrxExchange.isOpenAt(9 * 60), isTrue); // 09:00
      expect(kKrxExchange.isOpenAt(15 * 60 + 30), isFalse); // 15:30 폐장
      expect(kKrxExchange.isOpenAt(8 * 60 + 59), isFalse);

      expect(kUsExchange.isOpenAt(23 * 60 + 30), isTrue); // 23:30
      expect(kUsExchange.isOpenAt(25 * 60), isTrue); // 01:00
      expect(kUsExchange.isOpenAt(22 * 60), isFalse);

      // 국장·미장 모두 세션 26틱 (연환산 dt 일관성)
      expect(kKrxExchange.ticksPerSession(15), 26);
      expect(kUsExchange.ticksPerSession(15), 26);
    });
  });
}
