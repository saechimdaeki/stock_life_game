import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_session.dart';
import '../character/character_avatar.dart';
import '../game_controller.dart';

/// 첫 실행/새 게임 시 이름·아바타를 정한다. 확정하면 홈으로 전환.
class CharacterCreationScreen extends ConsumerStatefulWidget {
  const CharacterCreationScreen({super.key});

  @override
  ConsumerState<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState
    extends ConsumerState<CharacterCreationScreen> {
  final _name = TextEditingController();
  int _avatarId = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _name.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 작은 화면에서도 넘치지 않도록 콘텐츠는 스크롤, 버튼은 하단 고정.
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 16),
                    Text('캐릭터 만들기',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    const Text('주식 인생을 시작할 당신의 분신을 정하세요.',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 32),
                    Center(
                        child:
                            CharacterAvatar(avatarId: _avatarId, size: 96)),
                    const SizedBox(height: 12),
                    // 선택한 아바타의 고유 특성.
                    Center(
                      child: Column(
                        children: [
                          Text('✨ ${kTraits[_avatarId].name}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.teal)),
                          const SizedBox(height: 2),
                          Text(kTraits[_avatarId].desc,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < avatarCount; i++)
                          GestureDetector(
                            onTap: () => setState(() => _avatarId = i),
                            child: CharacterAvatar(
                                avatarId: i,
                                size: 56,
                                selected: i == _avatarId),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.done,
                      maxLength: 12,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        hintText: '예: 김주식',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: canStart
                    ? () => ref
                        .read(gameControllerProvider)
                        .setIdentity(_name.text.trim(), _avatarId)
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
