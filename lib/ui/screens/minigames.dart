import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 미니게임이 끝나면 성공 여부를 알린다.
typedef MiniGameResult = void Function(bool success);

/// 회의 미니게임 한 종류. 회의 진입 시 랜덤으로 하나 뽑힌다.
class MiniGameSpec {
  const MiniGameSpec({
    required this.name,
    required this.howTo,
    required this.build,
  });

  final String name;
  final String howTo;
  final Widget Function(MiniGameResult onResult) build;
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
    name: '블록 부수기',
    howTo: '패들을 움직여 공으로 블록을 모두 부숴라',
    build: _buildBreakout,
  ),
];

Widget _buildTiming(MiniGameResult r) => TimingGame(onResult: r);
Widget _buildMash(MiniGameResult r) => MashGame(onResult: r);
Widget _buildBreakout(MiniGameResult r) => BreakoutGame(onResult: r);

// ---------------------------------------------------------------------------
// 1) 눈치 타이밍: 좌우로 스윕하는 마커를 초록 구간에서 멈춘다.
// ---------------------------------------------------------------------------
class TimingGame extends StatefulWidget {
  const TimingGame({super.key, required this.onResult});

  final MiniGameResult onResult;

  @override
  State<TimingGame> createState() => _TimingGameState();
}

class _TimingGameState extends State<TimingGame>
    with SingleTickerProviderStateMixin {
  static const _zoneLo = 0.40;
  static const _zoneHi = 0.60;
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
  const MashGame({super.key, required this.onResult});

  final MiniGameResult onResult;

  @override
  State<MashGame> createState() => _MashGameState();
}

class _MashGameState extends State<MashGame> {
  static const _target = 16;
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
                color: _count >= _target ? Colors.green : Colors.white)),
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
// 3) 블록 부수기: 패들을 드래그해 공으로 블록을 전부 부순다. 공을 놓치면 실패.
// ---------------------------------------------------------------------------
class BreakoutGame extends StatefulWidget {
  const BreakoutGame({super.key, required this.onResult});

  final MiniGameResult onResult;

  @override
  State<BreakoutGame> createState() => _BreakoutGameState();
}

class _BreakoutGameState extends State<BreakoutGame>
    with SingleTickerProviderStateMixin {
  static const _r = 7.0;
  static const _paddleW = 78.0;
  static const _paddleH = 12.0;
  static const _paddleBottom = 20.0;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size _size = Size.zero;
  bool _init = false;
  bool _done = false;

  Offset _ball = Offset.zero;
  Offset _vel = Offset.zero;
  double _paddleCx = 0;
  final List<Rect> _blocks = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _setup(Size s) {
    _size = s;
    _paddleCx = s.width / 2;
    _ball = Offset(s.width / 2, s.height * 0.62);
    final speed = s.height * 0.55;
    _vel = Offset(speed * 0.45, -speed);
    _vel = _vel / _vel.distance * speed;
    _blocks.clear();
    const cols = 5, rows = 2, gap = 6.0, bh = 16.0, top = 14.0;
    final bw = (s.width - gap * (cols + 1)) / cols;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        _blocks.add(
            Rect.fromLTWH(gap + c * (bw + gap), top + r * (bh + gap), bw, bh));
      }
    }
    _init = true;
  }

  void _tick(Duration now) {
    if (!_init || _done) {
      _last = now;
      return;
    }
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.033);
    _last = now;
    if (dt <= 0) return;

    var p = _ball + _vel * dt;
    var v = _vel;
    if (p.dx < _r) {
      p = Offset(_r, p.dy);
      v = Offset(v.dx.abs(), v.dy);
    } else if (p.dx > _size.width - _r) {
      p = Offset(_size.width - _r, p.dy);
      v = Offset(-v.dx.abs(), v.dy);
    }
    if (p.dy < _r) {
      p = Offset(p.dx, _r);
      v = Offset(v.dx, v.dy.abs());
    }

    final paddleTop = _size.height - _paddleBottom - _paddleH;
    if (v.dy > 0 &&
        p.dy + _r >= paddleTop &&
        p.dy < paddleTop + _paddleH &&
        p.dx > _paddleCx - _paddleW / 2 &&
        p.dx < _paddleCx + _paddleW / 2) {
      final off = ((p.dx - _paddleCx) / (_paddleW / 2)).clamp(-1.0, 1.0);
      final speed = v.distance;
      v = Offset(off * speed * 0.7, -v.dy.abs());
      v = v / v.distance * speed;
      p = Offset(p.dx, paddleTop - _r);
    }

    for (var i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      if (p.dx > b.left - _r &&
          p.dx < b.right + _r &&
          p.dy > b.top - _r &&
          p.dy < b.bottom + _r) {
        _blocks.removeAt(i);
        v = Offset(v.dx, -v.dy);
        break;
      }
    }

    if (p.dy > _size.height + _r) {
      _finish(false);
      return;
    }
    if (_blocks.isEmpty) {
      _finish(true);
      return;
    }
    setState(() {
      _ball = p;
      _vel = v;
    });
  }

  void _finish(bool ok) {
    if (_done) return;
    _done = true;
    widget.onResult(ok);
  }

  void _movePaddle(double x) {
    setState(() =>
        _paddleCx = x.clamp(_paddleW / 2, _size.width - _paddleW / 2));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = Size(constraints.maxWidth, constraints.maxHeight);
        if (s.isFinite && (!_init || s != _size)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _setup(s));
          });
        }
        return GestureDetector(
          onPanUpdate: (d) => _movePaddle(d.localPosition.dx),
          onTapDown: (d) => _movePaddle(d.localPosition.dx),
          child: CustomPaint(
            painter: _BreakoutPainter(
              ball: _ball,
              paddleCx: _paddleCx,
              paddleTop: s.height - _paddleBottom - _paddleH,
              paddleW: _paddleW,
              paddleH: _paddleH,
              r: _r,
              blocks: _blocks,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _BreakoutPainter extends CustomPainter {
  _BreakoutPainter({
    required this.ball,
    required this.paddleCx,
    required this.paddleTop,
    required this.paddleW,
    required this.paddleH,
    required this.r,
    required this.blocks,
  });

  final Offset ball;
  final double paddleCx;
  final double paddleTop;
  final double paddleW;
  final double paddleH;
  final double r;
  final List<Rect> blocks;

  @override
  void paint(Canvas canvas, Size size) {
    final blockPaint = Paint()..color = Colors.tealAccent;
    for (final b in blocks) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(b, const Radius.circular(3)), blockPaint);
    }
    final paddle = Rect.fromLTWH(
        paddleCx - paddleW / 2, paddleTop, paddleW, paddleH);
    canvas.drawRRect(
        RRect.fromRectAndRadius(paddle, const Radius.circular(6)),
        Paint()..color = Colors.amber);
    canvas.drawCircle(ball, r, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_BreakoutPainter old) => true;
}
