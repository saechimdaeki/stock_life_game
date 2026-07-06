import 'dart:math';

import '../engine/engine.dart';
import 'colleague.dart';
import 'news_feed.dart';

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
    final stocks = createInitialStocks();
    // 초반에도 차트 흐름이 보이도록 과거 일봉을 합성한다(표시용).
    for (final s in stocks) {
      s.seedHistory(Random(actualSeed ^ s.code.hashCode));
    }
    final session = GameSession._(
      clock: GameClock(),
      market: Market(
        stocks: stocks,
        priceEngine: PriceEngine(random: random, microSteps: 5),
        eventEngine: EventEngine(random: random),
      ),
      portfolio: Portfolio(initialCash: initialCash),
      seed: actualSeed,
    );
    session.startDay();
    return session;
  }

  static const double initialCash = 10000000; // 초기 자금 1,000만원
  static const int salaryIntervalDays = 30; // 30일마다 월급

  /// 직급별 월급 (승진 시스템). 오를수록 인상.
  static const List<({String title, double salary})> ranks = [
    (title: '사원', salary: 3000000),
    (title: '주임', salary: 3600000),
    (title: '대리', salary: 4500000),
    (title: '과장', salary: 6000000),
    (title: '차장', salary: 8000000),
    (title: '부장', salary: 11000000),
    (title: '임원', salary: 16000000),
  ];

  /// 승진 주기: 60일(2개월)마다 한 직급씩.
  static const int promotionIntervalDays = 60;

  /// 일봉 저장 상한 (세이브 용량 관리).
  static const int maxCloseHistory = 120;

  final GameClock clock;
  final Market market;
  final Portfolio portfolio;
  final int seed;

  /// 현재 직급 인덱스 (0=사원).
  int rank = 0;

  /// 플레이어 정체성 (캐릭터 생성 화면에서 설정). 미설정이면 생성 화면 노출.
  String playerName = '';
  int avatarId = 0;

  /// 동료별 친밀도 0~100 (id -> rapport). 저장됨.
  final Map<String, int> rapport = {};

  /// 오늘 얻은 종목 정보(팁). 아침마다 리셋 — 저장 안 함.
  final List<StockTip> todayTips = [];

  /// 회식 등으로 취한 상태. 밤 미장 차트가 흔들려 보인다. 아침이면 술 깸.
  bool drunk = false;

  /// 텔레그램형 속보 피드(오늘). 아침 뉴스 + 장중 실시간 속보. 저장 안 함.
  final List<FeedItem> feed = [];

  static const int maxFeed = 60;

  /// 장중 속보 한 줄 추가(오래된 건 밀어냄).
  void pushNews(FeedItem item) {
    feed.add(item);
    if (feed.length > maxFeed) feed.removeAt(0);
  }

  /// 팁 적중 판정용 난수 (게임 진행마다 달라지도록 비결정).
  final Random _tipRng = Random();

  int rapportOf(String id) => rapport[id] ?? 0;

  void addRapport(String id, int delta) {
    rapport[id] = (rapportOf(id) + delta).clamp(0, 100);
  }

  /// 동료 [c]가 흘리는 정보. 실제 활성 이벤트가 걸린 종목을 골라
  /// 방향을 알려주되, 신뢰도+친밀도 확률로 가끔 틀린다. 재료가 없으면 null.
  StockTip? tipFrom(Colleague c) {
    final candidates = [
      for (final s in market.listedStocks)
        if (market.eventEngine.muBonusFor(s) != 0) s,
    ];
    if (candidates.isEmpty) return null;
    final stock = candidates[_tipRng.nextInt(candidates.length)];
    final realBullish = market.eventEngine.muBonusFor(stock) > 0;
    final p = (c.reliability + rapportOf(c.id) / 200).clamp(0.0, 0.98);
    final hit = _tipRng.nextDouble() < p;
    final tip = StockTip(
      stockCode: stock.code,
      bullish: hit ? realBullish : !realBullish,
      reliable: c.reliability >= 0.7,
      fromName: c.name,
    );
    todayTips.add(tip);
    return tip;
  }

  String get rankTitle => ranks[rank].title;
  double get currentSalary => ranks[rank].salary;

  /// 오늘 아침 기준 총자산 (오늘 손익 표시용).
  double morningAssets = initialCash;

  /// 오늘의 근무 일정표. 아침마다 재생성(저장 안 함).
  WorkSchedule todaySchedule = WorkSchedule(const []);

  /// 월급 등 뉴스 외 아침 알림.
  final List<String> morningNotices = [];

  bool get isDayOver => clock.isDayOver;

  double get totalAssets => portfolio.totalAssets(market.prices);

  double get todayPnl => totalAssets - morningAssets;

  /// 아침: 오버나이트 정산 -> 월급 -> 뉴스 추첨.
  void startDay() {
    morningNotices.clear();
    todayTips.clear();
    drunk = false; // 자고 일어나면 술 깸
    todaySchedule = WorkSchedule.roll(Random(seed ^ (clock.day * 0x9E3779B9)));
    if (clock.day > 1) market.settleOvernight();
    // 승진: 월급보다 먼저 처리해 오른 직급으로 지급.
    if (clock.day > 1 &&
        clock.day % promotionIntervalDays == 0 &&
        rank < ranks.length - 1) {
      final from = rankTitle;
      rank += 1;
      morningNotices.add('🎉 승진! $from → $rankTitle (월급 인상)');
    }
    if (clock.day > 1 && clock.day % salaryIntervalDays == 0) {
      portfolio.cash += currentSalary;
      morningNotices.add(
          '월급날입니다! $rankTitle +${(currentSalary / 10000).round()}만원');
    }
    market.openDay(clock.day);
    // 친밀도 만렙(100) 동료는 아침마다 정보를 하나 흘려준다.
    for (final c in kColleagues) {
      if (rapportOf(c.id) < 100) continue;
      final tip = tipFrom(c);
      if (tip == null) continue;
      final stock = market.stockByCode(tip.stockCode);
      morningNotices.add('🤝 「${c.name}」의 귀띔: ${stock?.name ?? ''} '
          '${tip.bullish ? '상승 우세' : '하락 우세'} (${tip.reliable ? '정보' : '소문'})');
    }
    // 오늘 피드 초기화: 아침 공지 + 오늘 뉴스로 시작(장중엔 실시간 속보가 쌓임).
    feed.clear();
    for (final n in morningNotices) {
      feed.add(FeedItem(
          minute: clock.minuteOfDay, text: n, tone: 0, channel: '회사'));
    }
    for (final item in market.todaysNews) {
      feed.add(FeedItem(
        minute: clock.minuteOfDay,
        text: item.headline,
        tone: item.event.spec.isGood ? 1 : -1,
        channel: '뉴스',
      ));
    }
    morningAssets = totalAssets;
  }

  /// 1틱(15분) 진행. 하루가 끝나면 false.
  bool advanceTick() {
    final hasMore = clock.advanceTick();
    market.advanceTick(clock.minuteOfDay);
    return hasMore;
  }

  /// 현재 시각에 개장 중인 거래소가 있는지.
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
      final c = stock.candleHistory;
      if (c.length > maxCloseHistory) {
        c.removeRange(0, c.length - maxCloseHistory);
      }
    }
    clock.nextDay();
  }

  TradeResult buy(Stock stock, int quantity) {
    final blocked = _tradeBlockReason(stock);
    if (blocked != null) return TradeResult.failure(blocked);
    return portfolio.buy(stock.code, stock.priceKrw, quantity,
        day: clock.day, tick: clock.minuteOfDay);
  }

  TradeResult sell(Stock stock, int quantity) {
    final blocked = _tradeBlockReason(stock);
    if (blocked != null) return TradeResult.failure(blocked);
    return portfolio.sell(stock.code, stock.priceKrw, quantity,
        day: clock.day, tick: clock.minuteOfDay);
  }

  /// 매매 불가 사유 문자열(가능하면 null). 장 개장 여부만 본다.
  /// (근무 중에도 몰래 매매 가능 — 일정은 분위기용일 뿐 매매를 막지 않는다.)
  String? _tradeBlockReason(Stock stock) {
    if (!market.isTradableAt(stock, clock.minuteOfDay)) {
      return '지금은 장이 열려 있지 않습니다';
    }
    return null;
  }

  // ---- 직렬화 (아침 시점 저장 전제: 틱 히스토리는 저장하지 않음) ----

  Map<String, dynamic> toJson() => {
        'version': 1,
        'seed': seed,
        'day': clock.day,
        'rank': rank,
        'playerName': playerName,
        'avatarId': avatarId,
        'rapport': rapport,
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
              'candles': [for (final c in s.candleHistory) c.toJson()],
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
      // candles: 구버전 세이브엔 없을 수 있음(하위호환).
      final candles = map['candles'] as List?;
      if (candles != null) {
        stock.candleHistory
          ..clear()
          ..addAll(candles
              .map((c) => Candle.fromJson((c as Map).cast<String, dynamic>())));
      }
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
        priceEngine: PriceEngine(random: random, microSteps: 5),
        eventEngine: eventEngine,
      ),
      portfolio: portfolio,
      seed: seed,
    )
      ..rank = (json['rank'] as int?) ?? 0 // 구버전 세이브 하위호환
      ..playerName = (json['playerName'] as String?) ?? ''
      ..avatarId = (json['avatarId'] as int?) ?? 0;
    // 친밀도 복원 (구버전 세이브엔 없음).
    final rapportJson = json['rapport'] as Map<String, dynamic>?;
    if (rapportJson != null) {
      rapportJson.forEach((k, v) => session.rapport[k] = (v as num).toInt());
    }
    session.startDay();
    return session;
  }
}
