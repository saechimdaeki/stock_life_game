import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/game_session.dart';

void main() {
  test('특성은 아바타 수와 1:1', () {
    expect(kTraits.length, 8);
  });

  test('월급 배수 — 성실의 아이콘(0)', () {
    final s = GameSession.newGame(seed: 1)..avatarId = 0;
    expect(s.currentSalary, 3000000 * 1.15);
  });

  test('포커페이스(6)는 컨디션 낮아도 핸디캡 0', () {
    final s = GameSession.newGame(seed: 1)
      ..avatarId = 6
      ..condition = 10;
    expect(s.minigameHandicap, 0);
    s.avatarId = 0;
    expect(s.minigameHandicap, greaterThan(0));
  });

  test('인싸(2)는 호감도 2배', () {
    final s = GameSession.newGame(seed: 1)..avatarId = 2;
    s.addRapport('c1', 3);
    expect(s.rapportOf('c1'), 6);
    s.addRapport('c1', -2); // 마이너스는 배수 없음
    expect(s.rapportOf('c1'), 4);
  });
}
