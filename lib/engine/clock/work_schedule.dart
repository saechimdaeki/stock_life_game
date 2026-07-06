import 'dart:math';

import 'game_clock.dart';

/// 근무 블록 종류. [canTrade]는 종류에서 파생된다.
/// (bossAway/lunch = 눈치매매 가능, 나머지 = 불가)
enum WorkBlockKind {
  /// 회의 — 회의실로 이동. 매매 불가.
  meeting,

  /// 업무 몰입 — 자리에서 집중. 매매 불가.
  focus,

  /// 보고서 마감 — 상사가 지켜봄. 매매 불가.
  report,

  /// 상사 외근 — 눈치매매 찬스. 매매 가능.
  bossAway,

  /// 점심시간 — 자유. 매매 가능.
  lunch,
}

extension WorkBlockKindX on WorkBlockKind {
  bool get canTrade =>
      this == WorkBlockKind.bossAway || this == WorkBlockKind.lunch;

  String get label {
    switch (this) {
      case WorkBlockKind.meeting:
        return '회의 중';
      case WorkBlockKind.focus:
        return '업무 몰입';
      case WorkBlockKind.report:
        return '보고서 마감';
      case WorkBlockKind.bossAway:
        return '상사 외근 — 눈치매매 찬스';
      case WorkBlockKind.lunch:
        return '점심시간';
    }
  }
}

/// 근무시간 중 한 구간.
class WorkBlock {
  const WorkBlock({
    required this.startMin,
    required this.endMin,
    required this.kind,
  });

  final int startMin;
  final int endMin;
  final WorkBlockKind kind;

  bool get canTrade => kind.canTrade;
  String get label => kind.label;
  bool contains(int minute) => minute >= startMin && minute < endMin;
}

/// 하루 근무 일정표 (09:00~18:00). 아침마다 랜덤 생성한다.
class WorkSchedule {
  WorkSchedule(this.blocks);

  final List<WorkBlock> blocks;

  /// 점심 12:00~13:00 고정.
  static const int lunchStart = 12 * 60;
  static const int lunchEnd = 13 * 60;

  /// 블록 길이 후보(분). 15분 틱에 정렬되도록 15의 배수.
  static const List<int> _durations = [30, 45, 60, 90];

  WorkBlock? blockAt(int minute) {
    for (final b in blocks) {
      if (b.contains(minute)) return b;
    }
    return null;
  }

  /// 근무시간 밖이면 일정 제약 없음(true). 근무 중이면 현재 블록의 [canTrade].
  bool canTradeAt(int minute) {
    if (minute < GameClock.workStartMinute ||
        minute >= GameClock.workEndMinute) {
      return true;
    }
    return blockAt(minute)?.canTrade ?? true;
  }

  /// 아침 추첨. 국장 마감(15:30) 전에 최소 1개 '찬스' 구간을 보장한다.
  factory WorkSchedule.roll(Random random) {
    final blocks = <WorkBlock>[
      ..._fillSegment(GameClock.workStartMinute, lunchStart, random),
      const WorkBlock(
          startMin: lunchStart, endMin: lunchEnd, kind: WorkBlockKind.lunch),
      ..._fillSegment(lunchEnd, GameClock.workEndMinute, random),
    ];

    // 회의실 씬을 볼 수 있도록 하루 최소 1개 '회의'를 보장한다.
    // (찬스 보장보다 먼저 — 이후 찬스 보장이 필요 시 별 블록을 찬스로 되돌린다.)
    // ponytail: 매일 회의 1개 고정. 지겨우면 확률제로 낮추면 됨.
    if (!blocks.any((b) => b.kind == WorkBlockKind.meeting)) {
      final candidates = [
        for (var i = 0; i < blocks.length; i++)
          if (blocks[i].kind != WorkBlockKind.lunch) i
      ];
      final i = candidates[random.nextInt(candidates.length)];
      final b = blocks[i];
      blocks[i] = WorkBlock(
          startMin: b.startMin, endMin: b.endMin, kind: WorkBlockKind.meeting);
    }

    // 국장 개장 시간(09:00~15:30) 안에 매매 찬스가 하나도 없으면 하나를 찬스로 교체.
    const marketClose = 15 * 60 + 30;
    final hasChance = blocks.any((b) =>
        b.canTrade && b.startMin < marketClose && b.kind != WorkBlockKind.lunch);
    if (!hasChance) {
      final candidates = [
        for (var i = 0; i < blocks.length; i++)
          if (blocks[i].startMin < marketClose &&
              blocks[i].kind != WorkBlockKind.lunch)
            i
      ];
      final i = candidates[random.nextInt(candidates.length)];
      final b = blocks[i];
      blocks[i] =
          WorkBlock(startMin: b.startMin, endMin: b.endMin, kind: WorkBlockKind.bossAway);
    }
    return WorkSchedule(blocks);
  }

  /// [start, end) 구간을 랜덤 길이·종류의 블록으로 빈틈없이 채운다.
  static List<WorkBlock> _fillSegment(int start, int end, Random random) {
    const kinds = [
      WorkBlockKind.meeting,
      WorkBlockKind.focus,
      WorkBlockKind.report,
      WorkBlockKind.bossAway,
    ];
    final result = <WorkBlock>[];
    var cursor = start;
    while (cursor < end) {
      var dur = _durations[random.nextInt(_durations.length)];
      // 남은 구간이 짧으면 끝까지 채운다.
      if (cursor + dur > end) dur = end - cursor;
      result.add(WorkBlock(
        startMin: cursor,
        endMin: cursor + dur,
        kind: kinds[random.nextInt(kinds.length)],
      ));
      cursor += dur;
    }
    return result;
  }
}
