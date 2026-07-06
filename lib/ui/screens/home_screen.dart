import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_session.dart';
import '../../data/news_feed.dart';
import '../../engine/engine.dart';
import '../format.dart';
import '../game_controller.dart';
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
            SceneView(controller: controller),
            const SizedBox(height: 12),
            _ClockCard(controller: controller),
            const SizedBox(height: 12),
            _AssetCard(session: session),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _ScheduleCard(
                    session: session,
                    currentMinute: session.clock.phase == DayPhase.work
                        ? session.clock.minuteOfDay
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('📢', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text('속보 피드',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _NewsFeed(session: session),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _DayControls(controller: controller),
            TextButton(
              onPressed: () => _confirmNewGame(context, controller),
              child: const Text('새 게임 시작',
                  style: TextStyle(color: Colors.grey)),
            ),
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

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    final clock = session.clock;
    final block = clock.phase == DayPhase.work
        ? session.todaySchedule.blockAt(clock.minuteOfDay)
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                Text(clock.timeLabel,
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            if (block != null) ...[
              const SizedBox(height: 8),
              _BlockChip(block: block),
            ],
          ],
        ),
      ),
    );
  }
}

/// 현재 근무 상황 표시(분위기용). 매매는 언제든 가능.
class _BlockChip extends StatelessWidget {
  const _BlockChip({required this.block});

  final WorkBlock block;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.work_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text(block.label,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
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
                    color: Colors.teal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('직급 ${session.rankTitle}',
                      style: const TextStyle(fontSize: 12, color: Colors.teal)),
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

/// 오늘의 근무 일정표. 하루 종일 표시하며, 근무 중이면 현재 블록을 강조한다.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.session, this.currentMinute});

  final GameSession session;

  /// 근무 시간이면 현재 시각(분), 아니면 null.
  final int? currentMinute;

  String _hhmm(int minute) {
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final blocks = session.todaySchedule.blocks;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note, size: 18),
                const SizedBox(width: 6),
                Text('오늘의 근무 일정',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            for (final b in blocks)
              Builder(builder: (context) {
                final active =
                    currentMinute != null && b.contains(currentMinute!);
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                  decoration: active
                      ? BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        )
                      : null,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 92,
                        child: Text('${_hhmm(b.startMin)}~${_hhmm(b.endMin)}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      Icon(Icons.circle,
                          size: 6,
                          color: active ? Colors.teal : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(b.label,
                            style: TextStyle(
                                fontSize: 13,
                                color: active ? Colors.teal : null,
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.normal)),
                      ),
                      if (active)
                        const Text('지금',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.teal,
                                fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
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

class _DayControls extends ConsumerWidget {
  const _DayControls({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (controller.stage) {
      case DayStage.morning:
        return FilledButton.icon(
          onPressed: controller.startDay,
          icon: const Icon(Icons.wb_sunny),
          label: const Text('하루 시작'),
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
