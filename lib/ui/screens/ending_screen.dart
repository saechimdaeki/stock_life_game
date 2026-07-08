import 'package:flutter/material.dart';

import '../../data/achievements.dart';
import '../../data/game_session.dart';
import '../character/character_avatar.dart';
import '../format.dart';
import '../sound.dart';

/// 경제적 자유(총자산 10억) 엔딩 시퀀스를 전체 화면으로 띄운다.
Future<void> showEnding(BuildContext context, GameSession session) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder(
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, _, _) => EndingScreen(session: session),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// 검은 화면 위로 왕관·타이틀·자산 카운트업·스탯이 순서대로 떠오르는 엔딩.
/// 탭하면 연출을 건너뛰고 바로 끝 상태를 보여준다.
class EndingScreen extends StatefulWidget {
  const EndingScreen({super.key, required this.session});

  final GameSession session;

  @override
  State<EndingScreen> createState() => _EndingScreenState();
}

class _EndingScreenState extends State<EndingScreen> {
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    Sfx.play('ending');
  }

  /// [a]~[b] 구간을 0~1로 정규화한 진행도.
  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  Widget _content(BuildContext context, double t) {
    final s = widget.session;
    final gold = Colors.amber.shade300;

    Widget fade(double a, double b, Widget child) =>
        Opacity(opacity: _seg(t, a, b), child: child);

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.4,
          colors: [
            Color.lerp(Colors.black, Colors.amber.shade900, 0.25 * t)!,
            Colors.black,
          ],
        ),
      ),
      child: SafeArea(
        // 작은 화면에서도 잘리지 않게 세로 중앙 + 스크롤 허용.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale:
                      0.5 + 0.5 * Curves.elasticOut.transform(_seg(t, 0, 0.2)),
                  child: fade(
                    0,
                    0.12,
                    const Text('👑', style: TextStyle(fontSize: 72)),
                  ),
                ),
                const SizedBox(height: 12),
                fade(
                  0.1,
                  0.22,
                  Text(
                    '경제적 자유',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: gold,
                    ),
                  ),
                ),
                fade(
                  0.15,
                  0.27,
                  const Text(
                    '— ENDING —',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 6,
                      color: Colors.white38,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                fade(
                  0.22,
                  0.35,
                  Column(
                    children: [
                      CharacterAvatar(avatarId: s.avatarId, size: 72),
                      const SizedBox(height: 8),
                      Text(
                        '${s.rankTitle} ${s.playerName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // 총자산 카운트업.
                fade(
                  0.3,
                  0.4,
                  Text(
                    won(s.totalAssets * _seg(t, 0.32, 0.62)),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: gold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                fade(
                  0.6,
                  0.75,
                  Column(
                    children: [
                      _StatRow('걸린 날', 'Day ${s.clock.day}'),
                      _StatRow('실현손익 누계', signedWon(s.portfolio.realizedPnl)),
                      _StatRow(
                        '업적',
                        '${s.achievements.length}/${kAchievements.length}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                fade(
                  0.72,
                  0.88,
                  const Text(
                    '월급쟁이 개미에서 시작해 마침내 10억을 만들었다.\n'
                    '이제 상사 눈치도, 몰래보기 30초도 필요 없다.\n\n'
                    '…물론 내일도 출근은 해야 한다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Colors.white54,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                fade(
                  0.88,
                  1.0,
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: t >= 1
                        ? () => Navigator.of(context).pop()
                        : null,
                    child: const Text('계속 달린다 🏃'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _skipped = true),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _skipped
            ? _content(context, 1)
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(seconds: 7),
                builder: (context, t, _) => _content(context, t),
              ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white38),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
