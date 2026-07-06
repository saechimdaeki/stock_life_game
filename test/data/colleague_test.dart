import 'package:flutter_test/flutter_test.dart';
import 'package:stock_life_game/data/colleague.dart';
import 'package:stock_life_game/data/game_session.dart';
import 'package:stock_life_game/engine/engine.dart';

void main() {
  test('로스터에 흡연자가 최소 1명 있다', () {
    expect(kSmokers, isNotEmpty);
  });

  test('rapport는 직렬화 라운드트립을 견딘다', () {
    final s = GameSession.newGame(seed: 3);
    s.addRapport('kim', 20);
    s.addRapport('lee', 5);
    final restored = GameSession.fromJson(s.toJson());
    expect(restored.rapportOf('kim'), 20);
    expect(restored.rapportOf('lee'), 5);
    expect(restored.rapportOf('park'), 0);
  });

  test('addRapport는 0~100으로 클램프된다', () {
    final s = GameSession.newGame(seed: 4);
    s.addRapport('kim', 150);
    expect(s.rapportOf('kim'), 100);
    s.addRapport('kim', -200);
    expect(s.rapportOf('kim'), 0);
  });

  test('tipFrom: 신뢰도 높은 동료가 더 정확하다', () {
    final s = GameSession.newGame(seed: 5);
    final stock = s.market.listedStocks.first;
    final goodSpec = kEventTable.firstWhere((e) => e.id == 'earnings_surprise');
    // 알려진 호재 하나만 남긴다 → tipFrom 후보 = 이 종목뿐, 실제 방향 = 상승.
    s.market.eventEngine.active
      ..clear()
      ..add(ActiveEvent(spec: goodSpec, startDay: 1, stockCode: stock.code));

    int correctCount(Colleague c) {
      var hit = 0;
      for (var i = 0; i < 500; i++) {
        final tip = s.tipFrom(c);
        if (tip != null && tip.bullish) hit++;
      }
      return hit;
    }

    final park = kColleagues.firstWhere((c) => c.id == 'park'); // 0.90 정보통
    final lee = kColleagues.firstWhere((c) => c.id == 'lee'); // 0.42 신입
    final parkHit = correctCount(park);
    final leeHit = correctCount(lee);
    expect(parkHit, greaterThan(leeHit));
    expect(parkHit, greaterThan(350)); // ~0.9*500
    expect(leeHit, lessThan(350)); // ~0.42*500
  });

  test('tipFrom: 재료(활성 이벤트)가 없으면 null', () {
    final s = GameSession.newGame(seed: 6);
    s.market.eventEngine.active.clear();
    final kim = kColleagues.firstWhere((c) => c.id == 'kim');
    expect(s.tipFrom(kim), isNull);
  });
}
