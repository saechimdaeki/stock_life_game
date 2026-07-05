import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/game_session.dart';
import '../data/save_repository.dart';

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

  /// 배속: 1x = 600ms/틱.
  int speed = 1;
  static const _baseTickMs = 600;

  /// 아침 브리핑 종료, 하루 자동 진행 시작.
  void startDay() {
    if (_stage != DayStage.morning) return;
    _stage = DayStage.running;
    play();
  }

  void play() {
    if (_stage != DayStage.running || isPlaying) return;
    _ticker = Timer.periodic(
      Duration(milliseconds: _baseTickMs ~/ speed),
      (_) => _onTick(),
    );
    notifyListeners();
  }

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void setSpeed(int value) {
    speed = value;
    if (isPlaying) {
      pause();
      play();
    } else {
      notifyListeners();
    }
  }

  void _onTick() {
    var hasMore = _session.advanceTick();
    // 장이 닫힌 시간대(아침·저녁)는 자동으로 빠르게 건너뛴다
    while (hasMore && !_session.anyExchangeOpen) {
      hasMore = _session.advanceTick();
    }
    if (!hasMore) {
      pause();
      _stage = DayStage.dayOver;
    }
    notifyListeners();
  }

  /// 정산 확인 -> 다음 날 아침으로.
  Future<void> confirmDayEnd() async {
    if (_stage != DayStage.dayOver) return;
    _session.endDay();
    await _persist();
    _session.startDay();
    _stage = DayStage.morning;
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

  /// 매매 후 UI 갱신용.
  void refresh() => notifyListeners();

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final saveRepositoryProvider =
    Provider<SaveRepository>((ref) => throw UnimplementedError('main에서 주입'));

final gameControllerProvider =
    ChangeNotifierProvider<GameController>((ref) {
  return GameController(saveRepository: ref.watch(saveRepositoryProvider));
});
