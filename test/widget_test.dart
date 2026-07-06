import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/save_repository.dart';
import 'package:stock_life_game/main.dart';
import 'package:stock_life_game/ui/game_controller.dart';

void main() {
  testWidgets('앱이 홈 화면(1일차 아침)으로 시작한다', (tester) async {
    // init을 호출하지 않은 SaveRepository는 저장 없음/저장 무시로 동작한다
    final saveRepository = SaveRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveRepositoryProvider.overrideWithValue(saveRepository),
        ],
        child: const StockLifeApp(),
      ),
    );

    // 첫 실행: 캐릭터 생성 화면 -> 이름 입력 후 시작.
    expect(find.text('캐릭터 만들기'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '김주식');
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('하루 시작'), findsOneWidget);
    expect(find.text('총자산'), findsOneWidget);

    // 하단 탭 전환
    await tester.tap(find.text('시장'));
    await tester.pumpAndSettle();
    expect(find.text('국장'), findsOneWidget);
    expect(find.text('미장'), findsOneWidget);

    await tester.tap(find.text('포트폴리오'));
    await tester.pumpAndSettle();
    expect(find.text('보유 종목이 없습니다'), findsOneWidget);
  });
}
