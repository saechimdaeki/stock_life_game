import 'dart:math';

import '../game_controller.dart';
import 'cutscene_screen.dart';

/// 근무 인터랙션 진입 컷씬 (장면 전환용).
/// 매일 반복되는 이벤트라 대사 한 줄은 랜덤 변주를 준다.
/// insider는 자체 선택지 컷씬이 따로 있으므로 여기서 다루지 않는다.
final Random _rng = Random();

T _pick<T>(List<T> list) => list[_rng.nextInt(list.length)];

CutsceneData introSceneFor(WorkInteraction i) {
  final c = i.colleague;
  switch (i.kind) {
    case WorkInteractionKind.meeting:
      return CutsceneData(
        bgEmoji: '🗣️',
        title: '회의 소집',
        lines: [
          const CutsceneLine('📢 사내 메신저가 울린다: "전원 회의실로."'),
          CutsceneLine(
              _pick([
                '다들 회의실로. 지금 바로.',
                '분기 실적 리뷰 시작하지. 어서들 오게.',
                '오늘은 좀 길어질 거야. 다들 각오하고.',
              ]),
              speaker: '상사', emoji: '🧑‍💼'),
          const CutsceneLine('노트북을 주섬주섬 챙긴다. 차트는... 잠시 안녕.'),
        ],
        choices: const ['회의실로 이동 🚶'],
      );
    case WorkInteractionKind.smoke:
      return CutsceneData(
        bgEmoji: '🚬',
        title: '옥상 흡연장',
        lines: [
          CutsceneLine('어깨를 톡톡. ${c!.name}이(가) 라이터를 흔들어 보인다.'),
          CutsceneLine(
              _pick([
                '한 대 피우고 오자. 머리도 식힐 겸.',
                '옥상 갈래? 바람 좀 쐬자.',
                '혼자 피우기 심심한데. 같이 가자.',
              ]),
              speaker: c.name, avatarId: c.avatarId),
          const CutsceneLine('옥상으로 올라간다. 도시가 한눈에 내려다보인다.'),
        ],
        choices: const ['따라간다 🚶'],
      );
    case WorkInteractionKind.coffee:
      return CutsceneData(
        bgEmoji: '☕',
        title: '커피 타임',
        lines: [
          CutsceneLine('${c!.name}이(가) 슬쩍 메신저를 보낸다: "커피? ☕"'),
          CutsceneLine(
              _pick([
                '아아 한 잔 어때. 내가 쏠게.',
                '탕비실에 새 원두 들어왔대. 가보자.',
                '5분만 쉬자. 당 떨어졌어...',
              ]),
              speaker: c.name, avatarId: c.avatarId),
          const CutsceneLine('따뜻한 컵을 들고 창가에 나란히 섰다.'),
        ],
        choices: const ['한 잔 하지 ☕'],
      );
    case WorkInteractionKind.lunch:
      return CutsceneData(
        bgEmoji: '🍚',
        title: '점심시간',
        lines: [
          const CutsceneLine('12시 정각. 사무실이 우르르 비워진다.'),
          CutsceneLine(
              _pick([
                '오늘 구내식당 제육이래. 줄 서자!',
                '나가서 먹을래? 국밥 어때.',
                '빨리 가자. 늦으면 줄 장난 아니야.',
              ]),
              speaker: c!.name, avatarId: c.avatarId),
          const CutsceneLine('식판을 들고 마주 앉았다.'),
        ],
        choices: const ['같이 먹는다 🍽️'],
      );
    case WorkInteractionKind.dinner:
      return CutsceneData(
        bgEmoji: '🍻',
        title: '회식',
        lines: [
          CutsceneLine('퇴근 직전, ${c!.name}이(가) 어깨동무를 걸어온다.'),
          CutsceneLine(
              _pick([
                '오늘 한잔 어때? 부장님이 쏜대!',
                '삼겹살에 소주. 거절은 거절한다?',
                '요즘 힘들었잖아. 오늘은 달리자.',
              ]),
              speaker: c.name, avatarId: c.avatarId),
          const CutsceneLine('고기 굽는 냄새, 부딪히는 소주잔... 밤이 길어질 예감이다.'),
        ],
        choices: const ['가자! 🍻'],
      );
    case WorkInteractionKind.insider:
      throw ArgumentError('insider는 자체 컷씬 사용');
  }
}
