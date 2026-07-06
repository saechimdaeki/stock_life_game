import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/save_repository.dart';
import 'package:stock_life_game/ui/game_controller.dart';
import 'package:stock_life_game/ui/screens/meeting_minigame_screen.dart';

void main() {
  testWidgets('회의 화면은 회의실 씬과 함께 정상 렌더된다', (tester) async {
    final controller = GameController(saveRepository: SaveRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: MeetingMinigameScreen(controller: controller),
    ));

    // 화면이 렌더되고 회의 타이틀이 존재한다. 회의실 씬은 에셋 이미지 또는
    // 도형 플레이스홀더로 렌더된다(에셋 유무와 무관하게 크래시 없음).
    expect(find.text('회의 중 🗣️'), findsOneWidget);

    // 타이머/티커 정리를 위해 언마운트.
    await tester.pumpWidget(const SizedBox());
  });
}
