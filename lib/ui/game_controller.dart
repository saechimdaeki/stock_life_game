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

/// 근무 블록 진입 시 뜨는 인터랙션 종류.
enum WorkInteractionKind { meeting, smoke, lunch, dinner, coffee }

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
    _maybePushNews();
    _maybeTriggerInteraction();
    _checkAchievements();
    notifyListeners();
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
        // 업무 몰입 중 인싸 동료가 커피 마시러 가자고 꼬신다 (확률적).
        if (kInsiders.isNotEmpty && _rng.nextDouble() < 0.25) {
          final c = kInsiders[_rng.nextInt(kInsiders.length)];
          pending = WorkInteraction(WorkInteractionKind.coffee, colleague: c);
          pause();
        }
      case WorkBlockKind.report:
        break;
    }
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
        notifyListeners();
        return;
      }
    }
    play();
  }

  /// 남은 하루를 즉시 진행해 정산 화면으로 넘어간다.
  void skipToDayEnd() {
    if (_stage != DayStage.running) return;
    pause();
    while (_session.advanceTick()) {}
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
