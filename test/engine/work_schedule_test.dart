import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/engine/engine.dart';

void main() {
  group('WorkSchedule', () {
    test('roll은 근무시간(09~18)을 빈틈·겹침 없이 채운다', () {
      for (var seed = 0; seed < 200; seed++) {
        final s = WorkSchedule.roll(Random(seed));
        expect(s.blocks.first.startMin, GameClock.workStartMinute);
        expect(s.blocks.last.endMin, GameClock.workEndMinute);
        for (var i = 1; i < s.blocks.length; i++) {
          // 연속: 이전 블록 끝 == 다음 블록 시작
          expect(s.blocks[i].startMin, s.blocks[i - 1].endMin,
              reason: 'seed=$seed 블록 사이 빈틈/겹침');
        }
      }
    });

    test('roll은 국장 마감(15:30) 전에 매매 찬스를 최소 1개 보장한다', () {
      const marketClose = 15 * 60 + 30;
      for (var seed = 0; seed < 200; seed++) {
        final s = WorkSchedule.roll(Random(seed));
        final hasChance = s.blocks.any((b) =>
            b.canTrade &&
            b.kind != WorkBlockKind.lunch &&
            b.startMin < marketClose);
        expect(hasChance, isTrue, reason: 'seed=$seed 눈치매매 찬스 없음');
      }
    });

    test('canTradeAt: 근무시간 밖은 항상 허용, 안은 블록에 따름', () {
      final s = WorkSchedule.roll(Random(1));
      // 근무 전/후는 일정 제약 없음
      expect(s.canTradeAt(GameClock.workStartMinute - 1), isTrue); // 08:59
      expect(s.canTradeAt(GameClock.workEndMinute), isTrue); // 18:00
      // 점심(12:00~13:00)은 매매 가능
      expect(s.canTradeAt(12 * 60 + 30), isTrue);
      // 근무 중 임의 시각은 그 시각 블록의 canTrade와 일치
      const t = 10 * 60 + 15;
      expect(s.canTradeAt(t), s.blockAt(t)!.canTrade);
    });
  });
}
