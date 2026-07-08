import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 미니게임이 끝나면 성공 여부를 알린다.
typedef MiniGameResult = void Function(bool success);

/// 회의 미니게임 한 종류. 회의 진입 시 랜덤으로 하나 뽑힌다.
/// [build]의 handicap(0=정상 ~ 1=최악)은 컨디션 페널티 — 게임별로 난이도를 올린다.
class MiniGameSpec {
  const MiniGameSpec({
    required this.name,
    required this.howTo,
    required this.build,
  });

  final String name;
  final String howTo;
  final Widget Function(MiniGameResult onResult, double handicap) build;
}

const List<MiniGameSpec> kMiniGames = [
  MiniGameSpec(
    name: '눈치 타이밍',
    howTo: '마커가 초록 구간일 때 [지금!] 탭',
    build: _buildTiming,
  ),
  MiniGameSpec(
    name: '초고속 연타',
    howTo: '3초 안에 목표만큼 연타!',
    build: _buildMash,
  ),
  MiniGameSpec(
    name: '몰래 폰 보기',
    howTo: '상사가 발표 볼 때만 꾹! 이쪽을 보면 손 떼라',
    build: _buildSneak,
  ),
  MiniGameSpec(
    name: '순서 기억',
    howTo: '깜빡이는 순서를 기억했다가 그대로 탭!',
    build: _buildSequence,
  ),
  MiniGameSpec(
    name: '숫자 찾기',
    howTo: '1부터 9까지 순서대로 빠르게 탭!',
    build: _buildNumberHunt,
  ),
];

Widget _buildTiming(MiniGameResult r, double h) =>
    TimingGame(onResult: r, handicap: h);
Widget _buildMash(MiniGameResult r, double h) =>
    MashGame(onResult: r, handicap: h);
Widget _buildSneak(MiniGameResult r, double h) =>
    SneakPeekGame(onResult: r, handicap: h);
Widget _buildSequence(MiniGameResult r, double h) =>
    SequenceGame(onResult: r, handicap: h);
Widget _buildNumberHunt(MiniGameResult r, double h) =>
    NumberHuntGame(onResult: r, handicap: h);

// ---------------------------------------------------------------------------
// 1) 눈치 타이밍: 좌우로 스윕하는 마커를 초록 구간에서 멈춘다.
// ---------------------------------------------------------------------------
class TimingGame extends StatefulWidget {
  const TimingGame({super.key, required this.onResult, this.handicap = 0});

  final MiniGameResult onResult;
  final double handicap;

  @override
  State<TimingGame> createState() => _TimingGameState();
}

class _TimingGameState extends State<TimingGame>
    with SingleTickerProviderStateMixin {
  // 컨디션이 나쁘면 초록 구간이 좁아진다 (0.20 → 0.10).
  double get _zoneLo => 0.50 - 0.10 * (1 - widget.handicap * 0.5);
  double get _zoneHi => 0.50 + 0.10 * (1 - widget.handicap * 0.5);
  late final AnimationController _ac;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _tap() {
    if (_done) return;
    _done = true;
    _ac.stop();
    final v = _ac.value;
    widget.onResult(v >= _zoneLo && v <= _zoneHi);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return SizedBox(
              height: 40,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * _zoneLo,
                    width: w * (_zoneHi - _zoneLo),
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _ac,
                    builder: (context, _) => Positioned(
                      left: (w - 6) * _ac.value,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 6, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _tap,
          style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 48)),
          child: const Text('지금!', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2) 초고속 연타: 3초 안에 목표 횟수만큼 탭.
// ---------------------------------------------------------------------------
class MashGame extends StatefulWidget {
  const MashGame({super.key, required this.onResult, this.handicap = 0});

  final MiniGameResult onResult;
  final double handicap;

  @override
  State<MashGame> createState() => _MashGameState();
}

class _MashGameState extends State<MashGame> {
  // 컨디션이 나쁘면 목표 횟수 증가 (16 → 20).
  int get _target => 16 + (widget.handicap * 4).round();
  int _count = 0;
  double _left = 3.0;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() => _left -= 0.1);
      if (_left <= 0) _finish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    widget.onResult(_count >= _target);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${_left.clamp(0, 3).toStringAsFixed(1)}s',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('$_count / $_target',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _count >= _target ? Colors.green : null)),
        const SizedBox(height: 16),
        GestureDetector(
          onTapDown: (_) {
            if (_done) return;
            setState(() => _count++);
            if (_count >= _target) _finish();
          },
          child: Container(
            width: 140,
            height: 140,
            decoration: const BoxDecoration(
                color: Colors.redAccent, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('연타!',
                style: TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3) 몰래 폰 보기: 상사가 발표를 볼 때만 버튼을 꾹 눌러 게이지를 채운다.
//    상사가 이쪽을 볼 때 누르고 있으면 걸린다. 돌아보기 직전에 ❗ 경고가 뜬다.
// ---------------------------------------------------------------------------
class SneakPeekGame extends StatefulWidget {
  const SneakPeekGame({super.key, required this.onResult, this.handicap = 0});

  final MiniGameResult onResult;
  final double handicap;

  @override
  State<SneakPeekGame> createState() => _SneakPeekGameState();
}

class _SneakPeekGameState extends State<SneakPeekGame> {
  static const _tick = Duration(milliseconds: 50);
  static const _fillSeconds = 2.4; // 누적 홀드 시간 목표
  static const _grace = 0.22; // 상사가 돌아본 뒤 손 뗄 유예(초)

  // 컨디션이 나쁘면 경고가 짧아진다 (0.5s → 0.2s).
  double get _warnTime => 0.5 - widget.handicap * 0.3;

  final _rng = Random();
  Timer? _timer;
  bool _done = false;

  double _gauge = 0;
  double _timeLeft = 15;
  bool _bossLooking = false;
  double _phaseLeft = 2.0; // 현재 상사 상태 남은 시간
  double _graceLeft = _grace;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) => _step(0.05));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _step(double dt) {
    if (_done) return;
    _timeLeft -= dt;
    _phaseLeft -= dt;

    if (_phaseLeft <= 0) {
      _bossLooking = !_bossLooking;
      _phaseLeft = _bossLooking
          ? 0.8 + _rng.nextDouble() * 0.8
          : 1.2 + _rng.nextDouble() * 1.4;
      _graceLeft = _grace;
    }

    if (_bossLooking && _holding) {
      _graceLeft -= dt;
      if (_graceLeft <= 0) {
        _finish(false);
        return;
      }
    } else if (_holding) {
      _gauge += dt / _fillSeconds;
      if (_gauge >= 1) {
        _finish(true);
        return;
      }
    }

    if (_timeLeft <= 0) {
      _finish(false);
      return;
    }
    setState(() {});
  }

  void _finish(bool ok) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    widget.onResult(ok);
  }

  @override
  Widget build(BuildContext context) {
    final warning = !_bossLooking && _phaseLeft <= _warnTime;
    final (emoji, label, color) = _bossLooking
        ? ('👀', '이쪽을 본다!!', Colors.redAccent)
        : warning
            ? ('❗', '곧 돌아본다...', Colors.orange)
            : ('🧑\u200d💼', '발표에 집중 중', Colors.green);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${_timeLeft.clamp(0, 15).toStringAsFixed(1)}s',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(emoji, style: const TextStyle(fontSize: 52)),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _gauge.clamp(0.0, 1.0),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTapDown: (_) => _holding = true,
          onTapUp: (_) => _holding = false,
          onTapCancel: () => _holding = false,
          child: Container(
            width: 150,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _holding ? Colors.teal : Colors.teal.shade700,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('📱 몰래 보기 (꾹)',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4) 순서 기억: 2×2 버튼이 깜빡이는 순서를 기억했다가 그대로 탭.
// ---------------------------------------------------------------------------
class SequenceGame extends StatefulWidget {
  const SequenceGame({super.key, required this.onResult, this.handicap = 0});

  final MiniGameResult onResult;
  final double handicap;

  @override
  State<SequenceGame> createState() => _SequenceGameState();
}

class _SequenceGameState extends State<SequenceGame> {
  static const _colors = [
    Colors.redAccent,
    Colors.amber,
    Colors.tealAccent,
    Colors.lightBlueAccent,
  ];

  late final List<int> _seq;
  int _flashing = -1; // 시연 중 켜진 버튼 (-1 = 꺼짐)
  bool _showing = true;
  int _inputIdx = 0;
  bool _done = false;

  // 시연은 취소 가능한 단발 타이머 체인으로 돌린다 (언마운트 시 잔여 타이머 없음).
  Timer? _timer;
  int _playIdx = 0;
  bool _lit = false;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _seq = List.generate(4, (_) => rng.nextInt(4));
    _timer = Timer(const Duration(milliseconds: 500), _stepPlayback);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _stepPlayback() {
    if (!mounted) return;
    if (_lit) {
      setState(() {
        _flashing = -1;
        _lit = false;
        _playIdx++;
      });
      if (_playIdx >= _seq.length) {
        setState(() => _showing = false);
        return;
      }
      _timer = Timer(const Duration(milliseconds: 160), _stepPlayback);
    } else {
      setState(() {
        _flashing = _seq[_playIdx];
        _lit = true;
      });
      // 컨디션이 나쁘면 깜빡임이 짧아져 외우기 어렵다 (450ms → 270ms).
      final on = Duration(
          milliseconds: (450 * (1 - widget.handicap * 0.4)).round());
      _timer = Timer(on, _stepPlayback);
    }
  }

  void _tap(int i) {
    if (_showing || _done) return;
    if (i != _seq[_inputIdx]) {
      _done = true;
      widget.onResult(false);
      return;
    }
    setState(() => _inputIdx++);
    if (_inputIdx >= _seq.length) {
      _done = true;
      widget.onResult(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_showing ? '잘 봐! 👀' : '따라 눌러! ($_inputIdx/${_seq.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        for (var row = 0; row < 2; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var col = 0; col < 2; col++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _pad(row * 2 + col),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pad(int i) {
    final lit = _flashing == i;
    return GestureDetector(
      onTapDown: (_) => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: _colors[i].withValues(alpha: lit ? 1.0 : 0.30),
          borderRadius: BorderRadius.circular(14),
          boxShadow: lit
              ? [BoxShadow(color: _colors[i], blurRadius: 16)]
              : const [],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5) 숫자 찾기: 3×3에 섞인 1~9를 제한시간 안에 순서대로 탭.
// ---------------------------------------------------------------------------
class NumberHuntGame extends StatefulWidget {
  const NumberHuntGame({super.key, required this.onResult, this.handicap = 0});

  final MiniGameResult onResult;
  final double handicap;

  @override
  State<NumberHuntGame> createState() => _NumberHuntGameState();
}

class _NumberHuntGameState extends State<NumberHuntGame> {
  late final List<int> _grid; // 섞인 1~9
  late double _left; // 남은 초
  int _next = 1;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _grid = List.generate(9, (i) => i + 1)..shuffle();
    // 컨디션이 나쁘면 제한시간 단축 (8s → 5s).
    _left = 8.0 - widget.handicap * 3;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() => _left -= 0.1);
      if (_left <= 0) _finish(false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish(bool ok) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    widget.onResult(ok);
  }

  void _tap(int n) {
    if (_done || n != _next) return;
    setState(() => _next++);
    if (_next > 9) _finish(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${_left.clamp(0, 10).toStringAsFixed(1)}s — 다음: $_next',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (var row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var col = 0; col < 3; col++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _cell(_grid[row * 3 + col]),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(int n) {
    final found = n < _next;
    return GestureDetector(
      onTapDown: (_) => _tap(n),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: found
              ? Colors.teal.withValues(alpha: 0.25)
              : Colors.teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$n',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: found ? Colors.teal : null)),
      ),
    );
  }
}
