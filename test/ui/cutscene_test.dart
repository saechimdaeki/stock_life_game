import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/colleague.dart';
import 'package:stock_life_game/ui/game_controller.dart';
import 'package:stock_life_game/ui/screens/cutscene_screen.dart';
import 'package:stock_life_game/ui/screens/interaction_scenes.dart';

void main() {
  test('모든 근무 인터랙션에 진입 컷씬이 정의돼 있다', () {
    for (final kind in WorkInteractionKind.values) {
      if (kind == WorkInteractionKind.insider) continue; // 자체 컷씬
      final scene = introSceneFor(
          WorkInteraction(kind, colleague: kColleagues.first));
      expect(scene.lines, isNotEmpty, reason: '$kind');
      expect(scene.choices, isNotEmpty, reason: '$kind');
    }
  });

  testWidgets('컷씬: 탭으로 대사 진행, 선택지 인덱스 반환', (tester) async {
    int? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => FilledButton(
          onPressed: () async {
            result = await showCutscene(
              context,
              const CutsceneData(
                bgEmoji: '🤫',
                title: '테스트',
                lines: [
                  CutsceneLine('첫 줄'),
                  CutsceneLine('둘째 줄', speaker: '김대리', avatarId: 0),
                ],
                choices: ['받는다', '거절한다'],
              ),
            );
          },
          child: const Text('열기'),
        ),
      ),
    ));

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('첫 줄'), findsOneWidget);
    expect(find.text('받는다'), findsNothing, reason: '대사가 끝나기 전엔 선택지 없음');

    await tester.tap(find.text('첫 줄')); // 아무 데나 탭 → 다음 줄
    await tester.pumpAndSettle();
    expect(find.text('둘째 줄'), findsOneWidget);
    expect(find.text('받는다'), findsOneWidget);

    await tester.tap(find.text('거절한다'));
    await tester.pumpAndSettle();
    expect(result, 1);
  });
}
