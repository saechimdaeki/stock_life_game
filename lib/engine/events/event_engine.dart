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

  /// 만료된 루머의 미해결 후속 (다음 날 아침 확정/무산으로 해소). 저장됨.
  final List<({String specId, String? stockCode})> pendingFollowUps = [];

  EventSpec? _specById(String id) {
    for (final s in _specs) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 아침 추첨: ①루머 후속 해소 ②정기 매크로 일정 ③랜덤 추첨.
  /// 새로 발생한 이벤트를 반환하고 active에 등록한다.
  /// 점프 적용은 Market 책임 (엔진은 효과 데이터만 관리).
  List<ActiveEvent> rollMorning({
    required int day,
    required List<Stock> listedStocks,
  }) {
    final rolled = <ActiveEvent>[];
    if (_specs.isEmpty) return rolled;

    // ① 어제 만료된 루머 → 확정/무산 후속 (같은 종목).
    for (final marker in pendingFollowUps) {
      final fu = kFollowUps[marker.specId];
      if (fu == null) continue;
      final spec =
          _specById(_random.nextDouble() < fu.pGood ? fu.goodId : fu.badId);
      if (spec == null) continue;
      // 그 사이 상장폐지됐으면 후속 없음.
      if (marker.stockCode != null &&
          !listedStocks.any((s) => s.code == marker.stockCode)) {
        continue;
      }
      final event =
          ActiveEvent(spec: spec, startDay: day, stockCode: marker.stockCode);
      active.add(event);
      rolled.add(event);
    }
    pendingFollowUps.clear();

    // ② 정기 매크로 일정 (CPI·FOMC — 방향은 당일 50/50).
    for (final entry in kMacroSchedule) {
      if (day % kMacroCycleDays != entry.offset) continue;
      final spec = _specById(
          _random.nextBool() ? entry.goodId : entry.badId);
      if (spec == null) continue;
      final event = ActiveEvent(spec: spec, startDay: day);
      active.add(event);
      rolled.add(event);
    }

    // ③ 랜덤 추첨.
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

  /// 장중 돌발 이벤트: [chance] 확률로 종목 단위 이벤트 하나를 즉시 발생.
  /// (매크로/섹터는 아침·일정 전용 — 장중엔 개별 종목 뉴스만 터진다.)
  ActiveEvent? maybeIntraday({
    required int day,
    required List<Stock> tradableStocks,
    double chance = kIntradayEventChance,
  }) {
    if (tradableStocks.isEmpty || _random.nextDouble() >= chance) return null;
    final pool = [
      for (final s in _specs)
        if (s.scope == EventScope.stock && s.weight > 0) s
    ];
    if (pool.isEmpty) return null;
    final total = pool.fold(0.0, (sum, s) => sum + s.weight);
    var roll = _random.nextDouble() * total;
    var spec = pool.last;
    for (final s in pool) {
      roll -= s.weight;
      if (roll < 0) {
        spec = s;
        break;
      }
    }
    final target = tradableStocks[_random.nextInt(tradableStocks.length)];
    final event = ActiveEvent(spec: spec, startDay: day, stockCode: target.code);
    active.add(event);
    return event;
  }

  /// 하루 종료 시 호출. 잔여 일수를 줄이고 만료 이벤트를 제거한다.
  /// 만료된 루머는 다음 날 아침 후속으로 이어지도록 마킹한다.
  void endDay() {
    for (final e in active) {
      e.remainingDays -= 1;
    }
    for (final e in active) {
      if (e.isExpired && kFollowUps.containsKey(e.spec.id)) {
        pendingFollowUps.add((specId: e.spec.id, stockCode: e.stockCode));
      }
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
