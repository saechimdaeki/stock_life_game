import 'dart:math';

import '../engine/engine.dart';

/// 엔진(시계·시장·포트폴리오)을 하나의 게임 세션으로 묶는다.
/// 하루 루프 오케스트레이션과 저장/복원 직렬화를 담당한다.
class GameSession {
  GameSession._({
    required this.clock,
    required this.market,
    required this.portfolio,
    required this.seed,
  });

  factory GameSession.newGame({int? seed}) {
    final actualSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    final random = Random(actualSeed);
    final session = GameSession._(
      clock: GameClock(),
      market: Market(
        stocks: createInitialStocks(),
        priceEngine: PriceEngine(random: random),
        eventEngine: EventEngine(random: random),
      ),
      portfolio: Portfolio(initialCash: initialCash),
      seed: actualSeed,
    );
    session.startDay();
    return session;
  }

  static const double initialCash = 10000000; // 초기 자금 1,000만원
  static const double monthlySalary = 3000000; // 월급 300만원
  static const int salaryIntervalDays = 30;

  /// 일봉 저장 상한 (세이브 용량 관리).
  static const int maxCloseHistory = 120;

  final GameClock clock;
  final Market market;
  final Portfolio portfolio;
  final int seed;

  /// 오늘 아침 기준 총자산 (오늘 손익 표시용).
  double morningAssets = initialCash;

  /// 월급 등 뉴스 외 아침 알림.
  final List<String> morningNotices = [];

  bool get isDayOver => clock.isDayOver;

  double get totalAssets => portfolio.totalAssets(market.prices);

  double get todayPnl => totalAssets - morningAssets;

  /// 아침: 오버나이트 정산 -> 월급 -> 뉴스 추첨.
  void startDay() {
    morningNotices.clear();
    if (clock.day > 1) market.settleOvernight();
    if (clock.day > 1 && clock.day % salaryIntervalDays == 0) {
      portfolio.cash += monthlySalary;
      morningNotices.add('월급날입니다! +${(monthlySalary / 10000).round()}만원');
    }
    market.openDay(clock.day);
    morningAssets = totalAssets;
  }

  /// 1틱(15분) 진행. 하루가 끝나면 false.
  bool advanceTick() {
    final hasMore = clock.advanceTick();
    market.advanceTick(clock.minuteOfDay);
    return hasMore;
  }

  /// 현재 시각에 개장 중인 거래소가 있는지 (자동 진행 스킵 판단용).
  bool get anyExchangeOpen =>
      kExchanges.any((e) => e.isOpenAt(clock.minuteOfDay));

  /// 취침: 장마감 처리 후 다음 날 아침으로. 호출 후 [startDay]를 호출할 것.
  void endDay() {
    market.closeDay();
    for (final stock in market.stocks) {
      final h = stock.closeHistory;
      if (h.length > maxCloseHistory) {
        h.removeRange(0, h.length - maxCloseHistory);
      }
    }
    clock.nextDay();
  }

  TradeResult buy(Stock stock, int quantity) {
    if (!market.isTradableAt(stock, clock.minuteOfDay)) {
      return const TradeResult.failure('지금은 장이 열려 있지 않습니다');
    }
    return portfolio.buy(stock.code, stock.priceKrw, quantity,
        day: clock.day, tick: clock.minuteOfDay);
  }

  TradeResult sell(Stock stock, int quantity) {
    if (!market.isTradableAt(stock, clock.minuteOfDay)) {
      return const TradeResult.failure('지금은 장이 열려 있지 않습니다');
    }
    return portfolio.sell(stock.code, stock.priceKrw, quantity,
        day: clock.day, tick: clock.minuteOfDay);
  }

  // ---- 직렬화 (아침 시점 저장 전제: 틱 히스토리는 저장하지 않음) ----

  Map<String, dynamic> toJson() => {
        'version': 1,
        'seed': seed,
        'day': clock.day,
        'cash': portfolio.cash,
        'realizedPnl': portfolio.realizedPnl,
        'positions': [
          for (final p in portfolio.positions.values)
            {'code': p.code, 'quantity': p.quantity, 'totalCost': p.totalCost},
        ],
        'stocks': [
          for (final s in market.stocks)
            {
              'code': s.code,
              'price': s.price,
              'delisted': !s.isListed,
              'closeHistory': s.closeHistory,
            },
        ],
        'events': [
          for (final e in market.eventEngine.active)
            {
              'specId': e.spec.id,
              'startDay': e.startDay,
              'remainingDays': e.remainingDays,
              'stockCode': e.stockCode,
              'sectorId': e.sectorId?.name,
            },
        ],
      };

  /// 저장 데이터로 세션을 복원한다. 복원 직후 아침 상태([startDay] 완료)가 된다.
  static GameSession fromJson(Map<String, dynamic> json) {
    final seed = json['seed'] as int;
    // 복원 후 난수열이 저장 전과 겹치지 않도록 day를 섞은 시드 사용
    final random = Random(seed ^ (json['day'] as int) * 0x9E3779B9);

    final stocks = createInitialStocks();
    final stockByCode = {for (final s in stocks) s.code: s};
    for (final item in json['stocks'] as List) {
      final map = item as Map<String, dynamic>;
      final stock = stockByCode[map['code']];
      if (stock == null) continue;
      stock.price = (map['price'] as num).toDouble();
      if (map['delisted'] == true) stock.status = ListingStatus.delisted;
      stock.closeHistory
        ..clear()
        ..addAll((map['closeHistory'] as List)
            .map((v) => (v as num).toDouble()));
    }

    final eventEngine = EventEngine(random: random);
    final specById = {for (final s in kEventTable) s.id: s};
    for (final item in json['events'] as List) {
      final map = item as Map<String, dynamic>;
      final spec = specById[map['specId']];
      if (spec == null) continue;
      final sectorName = map['sectorId'] as String?;
      eventEngine.active.add(ActiveEvent(
        spec: spec,
        startDay: map['startDay'] as int,
        stockCode: map['stockCode'] as String?,
        sectorId: sectorName == null
            ? null
            : SectorId.values.byName(sectorName),
      )..remainingDays = map['remainingDays'] as int);
    }

    final portfolio = Portfolio(initialCash: initialCash)
      ..cash = (json['cash'] as num).toDouble()
      ..realizedPnl = (json['realizedPnl'] as num).toDouble();
    for (final item in json['positions'] as List) {
      final map = item as Map<String, dynamic>;
      final code = map['code'] as String;
      portfolio.positions[code] = Position(
        code: code,
        quantity: map['quantity'] as int,
        totalCost: (map['totalCost'] as num).toDouble(),
      );
    }

    final session = GameSession._(
      clock: GameClock()..day = json['day'] as int,
      market: Market(
        stocks: stocks,
        priceEngine: PriceEngine(random: random),
        eventEngine: eventEngine,
      ),
      portfolio: portfolio,
      seed: seed,
    );
    session.startDay();
    return session;
  }
}
