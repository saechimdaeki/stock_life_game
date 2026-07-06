import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/save_repository.dart';
import 'package:stock_life_game/engine/engine.dart';
import 'package:stock_life_game/ui/game_controller.dart';

void main() {
  test('회식(finishDinner)은 취하게 하고 시간을 미장 무렵까지 넘긴다', () {
    final controller = GameController(saveRepository: SaveRepository());
    addTearDown(controller.dispose);

    expect(controller.session.drunk, isFalse);

    controller.finishDinner();

    expect(controller.session.drunk, isTrue);
    // 미장 개장(23:30) 이후로 시간이 흘러 있어야 한다.
    expect(controller.session.clock.minuteOfDay,
        greaterThanOrEqualTo(GameClock.nightStartMinute));
  });
}
