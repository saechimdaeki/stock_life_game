import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_session.dart';
import '../../engine/engine.dart';
import '../format.dart';
import '../game_controller.dart';

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
            _ClockCard(controller: controller),
            const SizedBox(height: 12),
            _AssetCard(session: session),
            const SizedBox(height: 12),
            Text('오늘의 뉴스', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(child: _NewsList(session: session)),
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
    final clock = controller.session.clock;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
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
            Text('총자산', style: Theme.of(context).textTheme.bodySmall),
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

class _NewsList extends StatelessWidget {
  const _NewsList({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final notices = session.morningNotices;
    final news = session.market.todaysNews;
    if (notices.isEmpty && news.isEmpty) {
      return const Center(
          child: Text('오늘은 조용한 하루입니다',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView(
      children: [
        for (final notice in notices)
          ListTile(
            dense: true,
            leading: const Icon(Icons.payments, color: Colors.amber),
            title: Text(notice),
          ),
        for (final item in news)
          ListTile(
            dense: true,
            leading: Icon(
              item.event.spec.isGood
                  ? Icons.trending_up
                  : Icons.trending_down,
              color: item.event.spec.isGood
                  ? Colors.redAccent
                  : Colors.blueAccent,
            ),
            title: Text(item.headline),
          ),
      ],
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
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    controller.isPlaying ? controller.pause : controller.play,
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
