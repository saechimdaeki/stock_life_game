import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/game_session.dart';
import 'package:stock_life_game/ui/screens/ending_screen.dart';

void main() {
  testWidgets('엔딩 시퀀스: 연출 후 통계와 계속하기 버튼이 뜬다', (tester) async {
    final session = GameSession.newGame()
      ..playerName = '김주식'
      ..portfolio.cash = 1000000000;

    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              await showEnding(context, session);
              popped = true;
            },
            child: const Text('엔딩'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('엔딩'));
    await tester.pumpAndSettle();

    expect(find.text('경제적 자유'), findsOneWidget);
    expect(find.textContaining('Day '), findsOneWidget);
    expect(find.text('계속 달린다 🏃'), findsOneWidget);

    await tester.ensureVisible(find.text('계속 달린다 🏃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('계속 달린다 🏃'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
  });
}
