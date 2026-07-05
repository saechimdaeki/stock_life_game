import 'dart:math';

import '../market/sector.dart';
import '../market/stock.dart';
import 'event_table.dart';
import 'game_event.dart';

/// 매일 아침 가중치 테이블에서 이벤트를 추첨하고,
/// 활성 이벤트의 드리프트/변동성 효과를 집계·만료시킨다.
class EventEngine {
  EventEngine({
    required this._random,
    List<EventSpec> specs = kEventTable,
    this._dailyCountDist = kDailyEventCountDist,
  })  : _specs = specs,
        _totalWeight = specs.fold(0.0, (sum, s) => sum + s.weight);

  final Random _random;
  final List<EventSpec> _specs;
  final List<double> _dailyCountDist;
  final double _totalWeight;

  final List<ActiveEvent> active = [];

  /// 아침 추첨. 새로 발생한 이벤트를 반환하고 active에 등록한다.
  /// 점프 적용은 Market 책임 (엔진은 효과 데이터만 관리).
  List<ActiveEvent> rollMorning({
    required int day,
    required List<Stock> listedStocks,
  }) {
    final rolled = <ActiveEvent>[];
    if (_specs.isEmpty) return rolled;
    final count = _rollDailyCount();
    for (var i = 0; i < count; i++) {
      final spec = _pickSpec();
      final event = _instantiate(spec, day, listedStocks);
      if (event == null) continue;
      active.add(event);
      rolled.add(event);
    }
    return rolled;
  }

  /// 하루 종료 시 호출. 잔여 일수를 줄이고 만료 이벤트를 제거한다.
  void endDay() {
    for (final e in active) {
      e.remainingDays -= 1;
    }
    active.removeWhere((e) => e.isExpired);
  }

  /// 해당 종목에 적용되는 드리프트 가산치 합 (연환산).
  double muBonusFor(Stock stock) {
    var bonus = 0.0;
    for (final e in active) {
      if (_applies(e, stock)) bonus += e.spec.effect.muBonus;
    }
    return bonus;
  }

  /// 해당 종목에 적용되는 변동성 배율 곱.
  double sigmaMultFor(Stock stock) {
    var mult = 1.0;
    for (final e in active) {
      if (_applies(e, stock)) mult *= e.spec.effect.sigmaMult;
    }
    return mult;
  }

  bool _applies(ActiveEvent e, Stock stock) {
    switch (e.spec.scope) {
      case EventScope.stock:
        return e.stockCode == stock.code;
      case EventScope.sector:
        return e.sectorId == stock.sectorId;
      case EventScope.exchange:
        return e.exchangeId == stock.exchangeId;
      case EventScope.market:
        return true;
    }
  }

  int _rollDailyCount() {
    var roll = _random.nextDouble();
    for (var count = 0; count < _dailyCountDist.length; count++) {
      roll -= _dailyCountDist[count];
      if (roll < 0) return count;
    }
    return _dailyCountDist.length - 1;
  }

  EventSpec _pickSpec() {
    var roll = _random.nextDouble() * _totalWeight;
    for (final spec in _specs) {
      roll -= spec.weight;
      if (roll < 0) return spec;
    }
    return _specs.last;
  }

  ActiveEvent? _instantiate(EventSpec spec, int day, List<Stock> listedStocks) {
    switch (spec.scope) {
      case EventScope.stock:
        if (listedStocks.isEmpty) return null;
        final target = listedStocks[_random.nextInt(listedStocks.length)];
        return ActiveEvent(spec: spec, startDay: day, stockCode: target.code);
      case EventScope.sector:
        final sector = kSectors[_random.nextInt(kSectors.length)];
        return ActiveEvent(spec: spec, startDay: day, sectorId: sector.id);
      case EventScope.exchange:
      case EventScope.market:
        return ActiveEvent(spec: spec, startDay: day);
    }
  }
}
