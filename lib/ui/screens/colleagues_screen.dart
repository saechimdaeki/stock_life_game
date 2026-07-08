import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/colleague.dart';
import '../character/character_avatar.dart';
import '../game_controller.dart';

/// 동료 친밀도 탭. 담배타임·회의로 친밀도를 올리면 정보 정확도가 오르고,
/// 100이 되면 매일 아침 정보를 준다.
class ColleaguesScreen extends ConsumerWidget {
  const ColleaguesScreen({super.key});

  static String _reliabilityLabel(double r) {
    if (r >= 0.8) return '정보통';
    if (r >= 0.6) return '믿을 만함';
    return '카더라 통신';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider).session;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('동료', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('친해질수록 정보가 정확해진다. 친밀도 100이면 매일 정보를 준다.',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          for (final c in kColleagues)
            _ColleagueCard(
              colleague: c,
              rapport: session.rapportOf(c.id),
              reliabilityLabel: _reliabilityLabel(c.reliability),
            ),
        ],
      ),
    );
  }
}

class _ColleagueCard extends StatelessWidget {
  const _ColleagueCard({
    required this.colleague,
    required this.rapport,
    required this.reliabilityLabel,
  });

  final Colleague colleague;
  final int rapport;
  final String reliabilityLabel;

  @override
  Widget build(BuildContext context) {
    final maxed = rapport >= 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CharacterAvatar(avatarId: colleague.avatarId, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(colleague.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      _Tag(colleague.trait.label),
                      _Tag(reliabilityLabel),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rapport / 100,
                      minHeight: 8,
                      color: maxed ? Colors.amber : Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    maxed ? '친밀도 100 · 🤝 매일 정보 제공' : '친밀도 $rapport',
                    style: TextStyle(
                        fontSize: 12,
                        color: maxed ? Colors.amber : Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    );
  }
}
