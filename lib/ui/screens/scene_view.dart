import 'package:flutter/material.dart';

import '../../data/colleague.dart';
import '../../engine/engine.dart';
import '../character/character_avatar.dart';
import '../game_controller.dart';

/// 한 씬 = 배경 이모지 + 말풍선. 애니메이션 없이 교체만 한다.
class _Scene {
  const _Scene(this.bg, this.bubble, {this.colleagues = false});
  final String bg;
  final String bubble;
  final bool colleagues; // 회의 등 동료 아바타 표시
}

/// 하루 페이즈/근무 블록에 따라 씬을 고른다. 매핑은 여기 한 곳뿐.
_Scene _sceneFor(GameController c) {
  final clock = c.session.clock;
  if (c.stage == DayStage.dayOver) {
    return const _Scene('💤', '취침 중... (미장은 계속 흐른다)');
  }
  switch (clock.phase) {
    case DayPhase.morning:
      return const _Scene('📰', '아침 뉴스를 훑어보는 중');
    case DayPhase.evening:
      return const _Scene('🛋️', '퇴근! 소파에서 한숨 돌리는 중');
    case DayPhase.night:
      return const _Scene('💻', '미장 오픈. 노트북 앞에 앉는다');
    case DayPhase.work:
      if (c.session.fired) {
        return const _Scene('🏠', '백수의 아침... 이제 차트가 곧 출근이다');
      }
      final block = c.session.todaySchedule.blockAt(clock.minuteOfDay);
      return _sceneForBlock(block?.kind);
  }
}

_Scene _sceneForBlock(WorkBlockKind? kind) {
  switch (kind) {
    case WorkBlockKind.meeting:
      return const _Scene('🗣️', '회의실... 발표를 흘려들으며', colleagues: true);
    case WorkBlockKind.bossAway:
      return const _Scene('📱', '상사 외근! 몰래 폰으로 눈치매매');
    case WorkBlockKind.lunch:
      return const _Scene('🍜', '점심시간. 밥보다 차트');
    case WorkBlockKind.report:
      return const _Scene('🖥️', '보고서 마감... 상사가 지켜본다');
    case WorkBlockKind.focus:
    case null:
      return const _Scene('⌨️', '책상에서 업무 몰입 중');
  }
}

/// 홈 상단 씬. 배경 이모지 위에 플레이어(+동료) 아바타와 말풍선.
class SceneView extends StatelessWidget {
  const SceneView({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final scene = _sceneFor(controller);
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.teal.withValues(alpha: 0.12),
            Colors.teal.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 씬 이모지
          Positioned(
            top: 8,
            right: 12,
            child: Text(scene.bg, style: const TextStyle(fontSize: 56)),
          ),
          // 캐릭터들
          Positioned(
            left: 16,
            bottom: 12,
            child: Row(
              children: [
                CharacterAvatar(
                    avatarId: controller.session.avatarId, size: 64),
                if (scene.colleagues)
                  for (final c in kColleagues.take(3)) ...[
                    const SizedBox(width: 4),
                    CharacterAvatar(avatarId: c.avatarId, size: 40),
                  ],
              ],
            ),
          ),
          // 말풍선
          Positioned(
            top: 12,
            left: 16,
            right: 84,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(scene.bubble,
                  style: const TextStyle(color: Colors.black87, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
