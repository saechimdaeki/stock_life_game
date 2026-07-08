import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/ui/character/character_avatar.dart';

void main() {
  // 벡터 아바타 8종이 예외 없이 그려지는지 스모크 체크.
  // (--update-goldens와 matchesGoldenFile로 바꾸면 PNG 미리보기 생성 가능)
  testWidgets('모든 아바타 스타일이 렌더링된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(460, 240));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              // PNG 에셋이 없는 id → 벡터 폴백 경로를 강제.
              for (var i = 0; i < avatarCount; i++)
                CharacterAvatar(avatarId: i + avatarCount, size: 96),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CharacterAvatar), findsNWidgets(avatarCount));
    expect(tester.takeException(), isNull);
  });
}
