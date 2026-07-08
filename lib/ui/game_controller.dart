import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/colleague.dart';
import '../data/game_session.dart';
import '../data/news_feed.dart';
import '../data/save_repository.dart';
import '../engine/engine.dart';
import 'format.dart';
import 'screens/cutscene_screen.dart';

/// 근무 블록 진입 시 뜨는 인터랙션 종류.
enum WorkInteractionKind { meeting, smoke, lunch, dinner, coffee, insider }

/// 대기 중인 근무 인터랙션 (UI가 감지해 모달로 띄운다).
class WorkInteraction {
  const WorkInteraction(this.kind, {this.colleague});

  final WorkInteractionKind kind;
  final Colleague? colleague; // 담배타임 상대
}

/// 하루 흐름 단계 (UI 표시용).
enum DayStage {
  /// 아침 브리핑: 뉴스 확인 후 하루 시작 대기.
  morning,

  /// 장중 자동 진행 (일시정지 가능).
  running,

  /// 02:00 도달, 하루 정산 확인 대기.
  dayOver,
}

/// 게임 세션의 실시간 진행(타이머)·저장을 관리한다.
/// 엔진 상태 변경 후 notifyListeners로 UI를 갱신한다.
class GameController extends ChangeNotifier {
  GameController({required SaveRepository saveRepository})
      : _saves = saveRepository {
    final saved = _saves.load();
    if (saved != null) {
      _session = GameSession.fromJson(saved);
      _collectMorningScenes(); // 복원 아침에도 평가/조사 컷씬이 뜬다.
    } else {
      _session = GameSession.newGame();
      _persist();
    }
  }

  final SaveRepository _saves;
  late GameSession _session;

  GameSession get session => _session;

  DayStage _stage = DayStage.morning;
  DayStage get stage => _stage;

  Timer? _ticker;
  bool get isPlaying => _ticker != null;

  /// 하루가 처음부터 끝까지 끊김 없이 흐른다. 급하면 일시정지·배속·스킵.
  /// 1x = 5000ms/틱(게임 15분) — 국장 하루(09:00~15:30)가 현실 ~2분 10초.
  int speed = 1;
  static const _tickMs = 5000;

  /// 좌상단 팝업 알림(장 개장 등). [alertSeq]가 바뀌면 새 알림.
  String? alert;
  int alertSeq = 0;

  /// 대기 중인 근무 인터랙션. null이 아니면 하루가 멈춰 있고 UI가 모달을 띄운다.
  WorkInteraction? pending;
  int _lastBlockStart = -1; // 블록당 1회만 트리거
  int _dinnerDay = -1; // 저녁 회식은 하루 1회
  final Random _rng = Random();

  /// 회의 몰래보기 남은 초. >0이면 하루가 멈춘 채 자유 매매 찬스(시간 정지).
  int peekSecondsLeft = 0;
  Timer? _peekTimer;

  /// 경제적 자유(총자산 10억) 달성 — UI가 엔딩 다이얼로그를 띄운다.
  bool pendingEnding = false;

  /// 아침 컷씬 큐 (인사평가·내부자 조사). _SceneHost가 순서대로 소비한다.
  final List<CutsceneData> pendingScenes = [];

  /// 세션이 아침에 남긴 평가/조사 결과를 컷씬 데이터로 바꿔 큐에 넣는다.
  void _collectMorningScenes() {
    final s = _session;
    final insider = s.lastInsiderOutcome;
    if (insider != null) {
      s.lastInsiderOutcome = null;
      if (insider == InsiderOutcome.caught) {
        pendingScenes.add(CutsceneData(
          bgEmoji: '🚨',
          title: '금융감독원',
          lines: [
            const CutsceneLine('출근길, 모르는 번호로 전화가 걸려온다.'),
            CutsceneLine(
                '${s.playerName}님 되시죠? 최근 ${s.lastInsiderStockName} '
                '거래 건으로 확인할 게 있습니다.',
                speaker: '금감원 조사관', emoji: '🕵️'),
            const CutsceneLine('...등에서 식은땀이 흐른다.'),
            CutsceneLine(
                '벌금 ${won(s.lastInsiderFine)}이 부과됐다. 회사에도 소문이 돌았다 (고과 -5).'),
          ],
          choices: const ['...조심하자'],
        ));
      } else {
        pendingScenes.add(CutsceneData(
          bgEmoji: '😮‍💨',
          title: '며칠 뒤',
          lines: const [
            CutsceneLine('그 거래를 묻는 사람은 아무도 없었다.'),
            CutsceneLine('...이번엔 운이 좋았다. 다음에도 그럴까?'),
          ],
        ));
      }
    }
    final review = s.lastReview;
    if (review != null) {
      s.lastReview = null;
      switch (review) {
        case ReviewOutcome.promoted:
          pendingScenes.add(CutsceneData(
            bgEmoji: '🎉',
            title: '분기 인사평가',
            lines: [
              const CutsceneLine('회의실로 불려갔다.'),
              const CutsceneLine('자네 요즘 태도가 아주 좋아. 계속 그렇게만 하게.',
                  speaker: '상사', emoji: '🧑‍💼'),
              CutsceneLine('축하하네. 오늘부로 ${s.rankTitle}일세.',
                  speaker: '상사', emoji: '🧑‍💼'),
              const CutsceneLine('승진했다! 월급이 오른다.'),
            ],
            choices: const ['감사합니다! 🙇'],
          ));
        case ReviewOutcome.warned:
          pendingScenes.add(CutsceneData(
            bgEmoji: '📉',
            title: '분기 인사평가',
            lines: [
              const CutsceneLine('회의실로 불려갔다. 분위기가 싸늘하다.'),
              const CutsceneLine('요즘 회의 때 정신이 어디 팔려 있나?',
                  speaker: '상사', emoji: '😠'),
              const CutsceneLine('경고장이야. 한 번 더면 짐 싸게 될 걸세.',
                  speaker: '상사', emoji: '😠'),
              CutsceneLine('경고 ${s.warnings}/2 — 다음 평가까지 고과를 올려야 한다.'),
            ],
            choices: const ['...죄송합니다'],
          ));
        case ReviewOutcome.fired:
          pendingScenes.add(CutsceneData(
            bgEmoji: '📦',
            title: '해고 통보',
            lines: const [
              CutsceneLine('책상 위에 봉투가 하나 놓여 있다.'),
              CutsceneLine('...미안하네. 더는 같이 못 가겠어.',
                  speaker: '상사', emoji: '🧑‍💼'),
              CutsceneLine('박스에 짐을 담았다. 이제 월급은 없다.'),
              CutsceneLine('남은 건 계좌 하나. 전업투자자의 삶이 시작됐다.'),
            ],
            choices: const ['...주식으로 복수한다 🔥'],
          ));
        case ReviewOutcome.stay:
          break; // 무난한 평가는 아침 공지로 충분.
      }
    }
  }

  /// 새로 달성한 업적을 알림·피드로 띄우고, 10억 달성이면 엔딩을 건다.
  void _checkAchievements() {
    final newly = _session.checkAchievements();
    for (final a in newly) {
      alert = '🏆 업적 달성: ${a.emoji} ${a.title}';
      alertSeq++;
      _session.pushNews(FeedItem(
        minute: _session.clock.minuteOfDay,
        text: '🏆 업적 달성 — ${a.emoji} ${a.title}',
        tone: 1,
        channel: '업적',
      ));
    }
    if (!_session.endingSeen && _session.achievements.contains('assets_1b')) {
      _session.endingSeen = true;
      pendingEnding = true;
      pause();
    }
  }

  /// 엔딩 다이얼로그 닫음 — 계속 플레이.
  void resolveEnding() {
    pendingEnding = false;
    if (_stage == DayStage.running) play();
    notifyListeners();
  }

  /// 아침 브리핑 종료, 하루 진행 자동 시작(계속 흐름).
  void startDay() {
    if (_stage != DayStage.morning) return;
    _stage = DayStage.running;
    play();
  }

  void play() {
    if (_stage != DayStage.running || isPlaying) return;
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    final interval = (_tickMs ~/ speed).clamp(1, _tickMs).toInt();
    _ticker = Timer.periodic(
      Duration(milliseconds: interval),
      (_) => _onTick(),
    );
  }

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void setSpeed(int value) {
    speed = value;
    if (isPlaying) _startTicker();
    notifyListeners();
  }

  void _onTick() {
    final beforeMin = _session.clock.minuteOfDay;
    final hasMore = _session.advanceTick();
    if (!hasMore) {
      pause();
      _stage = DayStage.dayOver;
      notifyListeners();
      return;
    }
    _maybeAlertOnOpen(beforeMin, _session.clock.minuteOfDay);
    _drainIntradayNews(withAlert: true);
    _maybePushNews();
    _maybeTriggerInteraction();
    _checkAchievements();
    notifyListeners();
  }

  /// 장중 돌발 이벤트 속보를 피드로 옮긴다. 실시간 틱이면 알림 팝업도 띄운다.
  void _drainIntradayNews({bool withAlert = false}) {
    final buffer = _session.market.intradayNewsBuffer;
    if (buffer.isEmpty) return;
    for (final item in buffer) {
      _session.pushNews(FeedItem(
        minute: _session.clock.minuteOfDay,
        text: '🚨 ${item.headline}',
        tone: item.event.spec.isGood ? 1 : -1,
        channel: '돌발',
      ));
    }
    if (withAlert) {
      alert = '🚨 ${buffer.last.headline}';
      alertSeq++;
    }
    buffer.clear();
  }

  /// 출근 후(아침 이후) 장중에 텔레그램 속보를 간간히 올린다.
  /// 30%는 진행 중인 진짜 이벤트 방향을 흘리는 '단독' 힌트, 나머지는 노이즈.
  void _maybePushNews() {
    if (_session.clock.phase == DayPhase.morning) return;
    if (_rng.nextDouble() >= 0.28) return;
    final minute = _session.clock.minuteOfDay;
    final item = _rng.nextDouble() < 0.30
        ? (rollHintNews(_rng, _session.market, minute) ??
            rollFlavorNews(_rng, _session.market, minute))
        : rollFlavorNews(_rng, _session.market, minute);
    _session.pushNews(item);
  }

  /// 근무 블록에 새로 진입하면 회의(미니게임)·상사외근(담배타임) 인터랙션을 띄운다.
  void _maybeTriggerInteraction() {
    if (pending != null) return;
    if (_session.fired) return; // 백수는 회사 인터랙션 없음.
    final clock = _session.clock;
    // 저녁: 회식러 동료가 회식에 부른다(하루 1회, 확률적). 죽은 저녁시간 채우기.
    if (clock.phase == DayPhase.evening) {
      if (_dinnerDay != clock.day && kFoodies.isNotEmpty) {
        _dinnerDay = clock.day;
        if (_rng.nextDouble() < 0.6) {
          final c = kFoodies[_rng.nextInt(kFoodies.length)];
          pending = WorkInteraction(WorkInteractionKind.dinner, colleague: c);
          pause();
        }
      }
      return;
    }
    if (clock.phase != DayPhase.work) {
      _lastBlockStart = -1;
      return;
    }
    final block = _session.todaySchedule.blockAt(clock.minuteOfDay);
    if (block == null || block.startMin == _lastBlockStart) return;
    _lastBlockStart = block.startMin; // 이 블록은 처리 완료(재트리거 방지)
    switch (block.kind) {
      case WorkBlockKind.meeting:
        pending = const WorkInteraction(WorkInteractionKind.meeting);
        pause();
      case WorkBlockKind.bossAway:
        // 흡연 동료와 담배타임 (스팸 방지: 확률적으로만).
        if (_rng.nextDouble() < 0.6) {
          final c = kSmokers[_rng.nextInt(kSmokers.length)];
          pending = WorkInteraction(WorkInteractionKind.smoke, colleague: c);
          pause();
        }
      case WorkBlockKind.lunch:
        // 점심 식사: 아무 동료와 대화 → 정보. 하루 1회(점심 블록 고정).
        final c = kColleagues[_rng.nextInt(kColleagues.length)];
        pending = WorkInteraction(WorkInteractionKind.lunch, colleague: c);
        pause();
      case WorkBlockKind.focus:
        // 내부자 제안: 친한(40+) 고신뢰 동료가 낮은 확률로 은밀히 찌른다.
        final whisperers = [
          for (final c in kColleagues)
            if (c.reliability >= 0.85 && _session.rapportOf(c.id) >= 40) c
        ];
        if (_session.insiderStockCode == null &&
            whisperers.isNotEmpty &&
            _rng.nextDouble() < 0.10) {
          final c = whisperers[_rng.nextInt(whisperers.length)];
          pending = WorkInteraction(WorkInteractionKind.insider, colleague: c);
          pause();
        } else if (kInsiders.isNotEmpty && _rng.nextDouble() < 0.25) {
          // 업무 몰입 중 인싸 동료가 커피 마시러 가자고 꼬신다 (확률적).
          final c = kInsiders[_rng.nextInt(kInsiders.length)];
          pending = WorkInteraction(WorkInteractionKind.coffee, colleague: c);
          pause();
        }
      case WorkBlockKind.report:
        break;
    }
  }

  /// 내부자 정보 수락: 랜덤 종목을 찍어주고, 내일 아침 pendingFollowUps로
  /// 잭팟(85%)/헛소문(15%)이 터진다. 3일 뒤 아침에 조사 판정.
  void acceptInsiderTip(Colleague from) {
    final session = _session;
    final stocks = session.market.listedStocks;
    if (stocks.isEmpty) return;
    final stock = stocks[_rng.nextInt(stocks.length)];
    session.market.eventEngine.pendingFollowUps
        .add((specId: 'insider_tip', stockCode: stock.code));
    session.insiderStockCode = stock.code;
    session.insiderResolveDay = session.clock.day + 3;
    session.insiderFromId = from.id;
    session.addRapport(from.id, 6);
    session.pushNews(FeedItem(
      minute: session.clock.minuteOfDay,
      text: '🤫 「${from.name}」: ${stock.name}... 내일 아침 큰 거 떠. 진짜야.',
      tone: 1,
      channel: '귓속말',
    ));
    alert = '🤫 내부 정보 입수: ${stock.name}';
    alertSeq++;
    notifyListeners();
  }

  /// 인터랙션 종료(보상은 UI가 세션에 직접 적용). 몰래보기 중이면 재개하지 않는다.
  void resolveInteraction() {
    pending = null;
    if (_stage == DayStage.running && peekSecondsLeft == 0) play();
    notifyListeners();
  }

  /// 회식 후: 취하고, 시간이 훌쩍 지난다(미장 개장 무렵까지 시세 시뮬).
  /// 인터랙션 해제는 UI가 시트를 닫을 때 [resolveInteraction]로 처리.
  void finishDinner() {
    _session.drunk = true;
    _session.applyDinnerFatigue();
    // 회식하느라 밤 늦게(미장 개장 직후)까지 시간이 흘러 있다.
    const target = GameClock.nightStartMinute + 30; // 24:00 무렵
    while (_session.clock.minuteOfDay < target) {
      if (!_session.advanceTick()) {
        _stage = DayStage.dayOver;
        break;
      }
    }
    _drainIntradayNews();
    notifyListeners();
  }

  /// 회의 미니게임 성공 보상: [seconds]초 동안 시간을 멈춘 채 자유 매매.
  /// 카운트다운이 끝나면 하루가 다시 흐른다.
  void startPeek({int seconds = 30}) {
    peekSecondsLeft = seconds;
    _peekTimer?.cancel();
    _peekTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      peekSecondsLeft -= 1;
      if (peekSecondsLeft <= 0) {
        peekSecondsLeft = 0;
        _peekTimer?.cancel();
        _peekTimer = null;
        if (_stage == DayStage.running) play();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  /// 거래소가 방금 개장했으면 좌상단 팝업 알림.
  void _maybeAlertOnOpen(int before, int now) {
    if (!kKrxExchange.isOpenAt(before) && kKrxExchange.isOpenAt(now)) {
      alert = '🔔 국장 개장! 매매 가능';
      alertSeq++;
    } else if (!kUsExchange.isOpenAt(before) && kUsExchange.isOpenAt(now)) {
      alert = '🌙 미장 개장! 매매 가능';
      alertSeq++;
    }
  }

  /// 장이 닫혀 있으면 다음 개장 시각까지 빠르게 건너뛰고 정상 흐름 재개.
  /// (개장 중엔 스킵할 게 없으므로 무시.)
  void skipToNextOpen() {
    if (_stage != DayStage.running || _session.anyExchangeOpen) return;
    pause();
    while (true) {
      final before = _session.clock.minuteOfDay;
      if (!_session.advanceTick()) {
        _stage = DayStage.dayOver;
        notifyListeners();
        return;
      }
      _maybeAlertOnOpen(before, _session.clock.minuteOfDay);
      if (_session.anyExchangeOpen) break;
    }
    _drainIntradayNews();
    _checkAchievements();
    play(); // 개장 도달 -> 정상 흐름 재개
  }

  /// (디버그 전용) [minuteOfDay]까지 즉시 진행. 인터랙션이 뜨면 거기서 멈춘다.
  void debugJumpTo(int minuteOfDay) {
    if (_stage != DayStage.running) return;
    pause();
    while (_session.clock.minuteOfDay < minuteOfDay) {
      if (!_session.advanceTick()) {
        _stage = DayStage.dayOver;
        notifyListeners();
        return;
      }
      _maybeTriggerInteraction();
      if (pending != null) {
        _drainIntradayNews();
        notifyListeners();
        return;
      }
    }
    _drainIntradayNews();
    play();
  }

  /// 남은 하루를 즉시 진행해 정산 화면으로 넘어간다.
  void skipToDayEnd() {
    if (_stage != DayStage.running) return;
    pause();
    while (_session.advanceTick()) {}
    _drainIntradayNews();
    _checkAchievements();
    _stage = DayStage.dayOver;
    notifyListeners();
  }

  /// 정산 확인 -> 다음 날 아침으로.
  Future<void> confirmDayEnd() async {
    if (_stage != DayStage.dayOver) return;
    _session.endDay();
    await _persist();
    _session.startDay();
    _collectMorningScenes(); // 평가·조사 결과 → 컷씬 큐
    _checkAchievements(); // Day 30 도달 등 아침 시점 업적
    _stage = DayStage.morning;
    notifyListeners();
  }

  /// 캐릭터 생성 화면에서 이름·아바타 확정.
  Future<void> setIdentity(String name, int avatarId) async {
    _session.playerName = name;
    _session.avatarId = avatarId;
    await _persist();
    notifyListeners();
  }

  /// 새 게임 (기존 세이브 삭제).
  Future<void> newGame() async {
    pause();
    await _saves.clear();
    _session = GameSession.newGame();
    _stage = DayStage.morning;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _saves.save(_session.toJson());

  /// 매매 후 UI 갱신용. 매매 직후 업적(첫 매매·자산 등)도 바로 반영한다.
  void refresh() {
    _checkAchievements();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _peekTimer?.cancel();
    super.dispose();
  }
}

final saveRepositoryProvider =
    Provider<SaveRepository>((ref) => throw UnimplementedError('main에서 주입'));

final gameControllerProvider =
    ChangeNotifierProvider<GameController>((ref) {
  return GameController(saveRepository: ref.watch(saveRepositoryProvider));
});
