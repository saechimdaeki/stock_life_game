import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ads.dart';
import '../../ads/reward_gate.dart';
import '../../data/achievements.dart';
import '../../data/game_session.dart';
import '../../data/news_feed.dart';
import '../../engine/engine.dart';
import '../format.dart';
import '../game_controller.dart';
import '../sound.dart';
import 'scene_view.dart';

/// 홈: 시각/페이즈, 자산 요약, 오늘의 뉴스, 하루 진행 컨트롤.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(gameControllerProvider);
    final session = controller.session;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 컨트롤만 하단 고정, 나머지는 함께 스크롤(작은 화면 오버플로 방지).
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SceneView(controller: controller),
                  const SizedBox(height: 12),
                  _ClockCard(controller: controller),
                  const SizedBox(height: 8),
                  _AssetCard(session: session),
                  const SizedBox(height: 8),
                  _ScheduleTimeline(
                    session: session,
                    currentMinute: session.clock.phase == DayPhase.work
                        ? session.clock.minuteOfDay
                        : null,
                  ),
                  _AdRewardCard(controller: controller),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('📢', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text('속보 피드',
                          style: Theme.of(context).textTheme.titleSmall),
                      const Spacer(),
                      ValueListenableBuilder<bool>(
                        valueListenable: Sfx.muted,
                        builder: (_, muted, _) => IconButton(
                          onPressed: Sfx.toggleMute,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(muted ? Icons.volume_off : Icons.volume_up,
                              size: 18, color: Colors.grey),
                          tooltip: muted ? '소리 켜기' : '음소거',
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showAchievements(context, session),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.emoji_events_outlined,
                            size: 18, color: Colors.amber),
                        tooltip: '업적',
                      ),
                      TextButton(
                        onPressed: () => _confirmNewGame(context, controller),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        child: const Text('새 게임',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    ],
                  ),
                  _NewsFeed(session: session),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _DayControls(controller: controller),
          ],
        ),
      ),
    );
  }

  void _showAchievements(BuildContext context, GameSession session) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
                '🏆 업적  ${session.achievements.length}/${kAchievements.length}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final a in kAchievements)
              Builder(builder: (context) {
                final done = session.achievements.contains(a.id);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Opacity(
                    opacity: done ? 1 : 0.45,
                    child: Row(
                      children: [
                        Text(a.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(a.desc,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text(done ? '✅' : '🔒',
                            style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmNewGame(
      BuildContext context, GameController controller) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 게임'),
        content: const Text('현재 진행 상황이 삭제됩니다. 새로 시작할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('새로 시작')),
        ],
      ),
    );
    if (yes == true) await controller.newGame();
  }
}

class _ClockCard extends StatelessWidget {
  const _ClockCard({required this.controller});

  final GameController controller;

  static const _phaseLabels = {
    DayPhase.morning: '아침 - 출근 준비',
    DayPhase.work: '근무 중 (09~18시)',
    DayPhase.evening: '저녁 - 자유시간',
    DayPhase.night: '심야 - 미장 시간',
  };

  static const _phaseIcons = {
    DayPhase.morning: '🌅',
    DayPhase.work: '💼',
    DayPhase.evening: '🌆',
    DayPhase.night: '🌙',
  };

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    final clock = session.clock;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day ${clock.day}',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(_phaseLabels[clock.phase]!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const Spacer(),
                // 현재 시각을 알약형 배지로 강조: 페이즈 아이콘 + 큰 고정폭 숫자.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_phaseIcons[clock.phase]!,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        clock.timeLabel,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _ConditionBar(condition: session.condition),
          ],
        ),
      ),
    );
  }
}

/// 컨디션 게이지. 회식·심야 매매로 깎이고 자면 회복된다.
class _ConditionBar extends StatelessWidget {
  const _ConditionBar({required this.condition});

  final int condition;

  @override
  Widget build(BuildContext context) {
    final color = condition >= 70
        ? Colors.teal
        : (condition >= 40 ? Colors.amber : Colors.redAccent);
    return Row(
      children: [
        const Text('🔋', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: condition / 100,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$condition',
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final pnl = session.todayPnl;
    final pnlColor = pnl > 0
        ? Colors.redAccent
        : (pnl < 0 ? Colors.blueAccent : Colors.grey);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('총자산', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (session.fired ? Colors.redAccent : Colors.teal)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                      session.fired
                          ? '무직 (해고됨)'
                          : '직급 ${session.rankTitle} · 고과 '
                              '${session.performanceScore >= 0 ? '+' : ''}'
                              '${session.performanceScore}'
                              '${session.warnings > 0 ? ' ⚠️${session.warnings}' : ''}',
                      style: TextStyle(
                          fontSize: 12,
                          color: session.fired
                              ? Colors.redAccent
                              : Colors.teal)),
                ),
              ],
            ),
            Text(won(session.totalAssets),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('현금 ${won(session.portfolio.cash)}',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Text('💱 ${session.market.usdKrw.round()}원',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Text('오늘 ${signedWon(pnl)}',
                    style: TextStyle(color: pnlColor, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 오늘의 근무 일정을 가로 타임라인 바(09~18시, 길이 비례)로 그린다.
/// 근무 중이면 현재 블록을 밝게 강조하고 상단에 "지금" 라벨을 띄운다.
class _ScheduleTimeline extends StatelessWidget {
  const _ScheduleTimeline({required this.session, this.currentMinute});

  final GameSession session;

  /// 근무 시간이면 현재 시각(분), 아니면 null.
  final int? currentMinute;

  static String _emoji(WorkBlockKind kind) => switch (kind) {
        WorkBlockKind.meeting => '🗣',
        WorkBlockKind.focus => '💻',
        WorkBlockKind.report => '📝',
        WorkBlockKind.bossAway => '👀',
        WorkBlockKind.lunch => '🍚',
      };

  static Color _color(WorkBlockKind kind) => switch (kind) {
        WorkBlockKind.meeting => Colors.deepOrangeAccent,
        WorkBlockKind.focus => Colors.blueGrey,
        WorkBlockKind.report => Colors.indigoAccent,
        WorkBlockKind.bossAway => Colors.teal,
        WorkBlockKind.lunch => Colors.amber,
      };

  @override
  Widget build(BuildContext context) {
    final blocks = session.todaySchedule.blocks;
    final current = currentMinute == null
        ? null
        : session.todaySchedule.blockAt(currentMinute!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note, size: 15),
                const SizedBox(width: 6),
                Text('오늘 근무', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  current != null ? '지금: ${current.label}' : '09:00 ~ 18:00',
                  style: TextStyle(
                      fontSize: 11,
                      color: current != null ? Colors.teal : Colors.grey,
                      fontWeight:
                          current != null ? FontWeight.w700 : FontWeight.normal),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  for (final b in blocks)
                    Expanded(
                      flex: b.endMin - b.startMin,
                      child: Tooltip(
                        message:
                            '${_hhmm(b.startMin)}~${_hhmm(b.endMin)} ${b.label}',
                        child: Builder(builder: (context) {
                          final active = currentMinute != null &&
                              b.contains(currentMinute!);
                          return Container(
                            margin: const EdgeInsets.only(right: 2),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _color(b.kind)
                                  .withValues(alpha: active ? 0.85 : 0.28),
                              borderRadius: BorderRadius.circular(6),
                              border: active
                                  ? Border.all(color: Colors.white70)
                                  : null,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(_emoji(b.kind),
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            const Row(
              children: [
                Text('09:00', style: TextStyle(fontSize: 9, color: Colors.grey)),
                Spacer(),
                Text('12:00', style: TextStyle(fontSize: 9, color: Colors.grey)),
                Spacer(),
                Text('18:00', style: TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _hhmm(int minute) {
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

/// 광고 보상 진입점 카드: 애널리스트 리포트(하루 1회) + 구제금융(파산 위기).
/// 둘 다 불가능하면 아예 표시하지 않는다.
class _AdRewardCard extends StatelessWidget {
  const _AdRewardCard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    final report = session.analystReportAvailable;
    final bailout = session.bailoutAvailable;
    if (!report && !bailout) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Column(
          children: [
            if (report)
              _AdRewardRow(
                emoji: '📊',
                title: '애널리스트 리포트',
                desc: '재료가 살아있는 종목의 진짜 방향 (하루 1회)',
                onRewarded: controller.grantAnalystReport,
              ),
            if (bailout)
              _AdRewardRow(
                emoji: '🆘',
                title: '구제금융',
                desc: '긴급 자금 ${won(GameSession.bailoutAmount)} '
                    '(남은 ${GameSession.maxBailouts - session.bailoutsUsed}회)',
                onRewarded: controller.grantBailout,
              ),
          ],
        ),
      ),
    );
  }
}

class _AdRewardRow extends StatelessWidget {
  const _AdRewardRow({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.onRewarded,
  });

  final String emoji;
  final String title;
  final String desc;
  final VoidCallback onRewarded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(desc,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () async {
            if (await watchRewardedAd(context)) onRewarded();
          },
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          icon: const Icon(Icons.smart_display, size: 15),
          label: const Text('광고', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

/// 텔레그램형 속보 피드. 최신 항목이 위. 장중에 실시간으로 쌓인다.
class _NewsFeed extends StatelessWidget {
  const _NewsFeed({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final items = session.feed;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: Text('아직 올라온 소식이 없습니다',
                style: TextStyle(color: Colors.grey))),
      );
    }
    // 바깥 ListView 안이므로 자체 스크롤 없이 Column으로 쌓는다(최신 위).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items.reversed) _FeedBubble(item: item),
      ],
    );
  }
}

class _FeedBubble extends StatelessWidget {
  const _FeedBubble({required this.item});

  final FeedItem item;

  String get _hhmm {
    final h = (item.minute ~/ 60) % 24;
    final m = item.minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Color get _accent => item.tone > 0
      ? Colors.redAccent
      : (item.tone < 0 ? Colors.blueAccent : Colors.grey);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: _accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(item.channel,
                    style: TextStyle(fontSize: 10, color: _accent)),
              ),
              const SizedBox(width: 6),
              Text(_hhmm,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 3),
          Text(item.text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// (디버그 빌드 전용) 테스트 편의 점프 버튼. 릴리즈엔 안 보인다.
class _DebugJumpRow extends StatelessWidget {
  const _DebugJumpRow({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    final now = session.clock.minuteOfDay;
    WorkBlock? nextMeeting;
    for (final b in session.todaySchedule.blocks) {
      if (b.kind == WorkBlockKind.meeting && b.startMin >= now) {
        nextMeeting = b;
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: nextMeeting == null
                  ? null
                  // 블록 진입 틱에서 인터랙션이 트리거되도록 시작+1틱까지 진행.
                  : () => controller.debugJumpTo(nextMeeting!.startMin + 15),
              child: const Text('🛠 회의⏩', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: now >= GameClock.workEndMinute
                  ? null
                  : () => controller.debugJumpTo(GameClock.workEndMinute + 15),
              child: const Text('🛠 저녁⏩', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayControls extends ConsumerWidget {
  const _DayControls({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (controller.stage) {
      case DayStage.morning:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: controller.startDay,
              icon: const Icon(Icons.wb_sunny),
              label: const Text('하루 시작'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                if (await watchRewardedAd(context)) controller.skipWholeDay();
              },
              icon: const Icon(Icons.smart_display, size: 18),
              label: const Text('광고 보고 오늘 하루 통째로 스킵'),
            ),
          ],
        );
      case DayStage.running:
        // 하루가 계속 흐른다. 급하면 일시정지·배속, 죽은 시간은 스킵.
        final marketOpen = controller.session.anyExchangeOpen;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.isPlaying
                        ? controller.pause
                        : controller.play,
                    icon: Icon(
                        controller.isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(controller.isPlaying ? '일시정지' : '재생'),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1x')),
                    ButtonSegment(value: 2, label: Text('2x')),
                    ButtonSegment(value: 4, label: Text('4x')),
                  ],
                  selected: {controller.speed},
                  onSelectionChanged: (s) => controller.setSpeed(s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    // 개장 중엔 스킵할 죽은 시간이 없음.
                    onPressed:
                        marketOpen ? null : controller.skipToNextOpen,
                    icon: const Icon(Icons.fast_forward, size: 18),
                    label: const Text('다음 개장까지'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: controller.skipToDayEnd,
                    icon: const Icon(Icons.bedtime, size: 18),
                    label: const Text('하루 끝'),
                  ),
                ),
              ],
            ),
            if (kDebugMode) _DebugJumpRow(controller: controller),
          ],
        );
      case DayStage.dayOver:
        return FilledButton.icon(
          onPressed: () => _showSettlement(context, controller),
          icon: const Icon(Icons.bedtime),
          label: const Text('하루 정산 보기'),
        );
    }
  }

  Future<void> _showSettlement(
      BuildContext context, GameController controller) async {
    final session = controller.session;
    final pnl = session.todayPnl;
    final banner = Ads.settlementBanner();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Day ${session.clock.day} 정산'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('총자산: ${won(session.totalAssets)}'),
            Text('오늘 손익: ${signedWon(pnl)}',
                style: TextStyle(
                    color: pnl >= 0 ? Colors.redAccent : Colors.blueAccent)),
            Text('실현손익 누계: ${signedWon(session.portfolio.realizedPnl)}'),
            const SizedBox(height: 8),
            const Text('취침 중에도 미장은 계속됩니다...',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            if (banner != null) ...[
              const SizedBox(height: 12),
              Center(child: banner),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취침 (다음 날로)'),
          ),
        ],
      ),
    );
    await controller.confirmDayEnd();
  }
}
