import 'package:flutter/material.dart';

import '../character/character_avatar.dart';

/// 컷씬 대사 한 줄. speaker가 null이면 내레이션(중앙 회색).
class CutsceneLine {
  const CutsceneLine(this.text, {this.speaker, this.avatarId, this.emoji});

  final String text;
  final String? speaker;

  /// 말풍선 옆 얼굴: 아바타 id 또는 이모지(상사 등 비동료) 중 하나.
  final int? avatarId;
  final String? emoji;
}

/// 컷씬 하나. 탭할 때마다 대사가 한 줄씩 나오고, 다 나오면 선택지가 뜬다.
class CutsceneData {
  const CutsceneData({
    required this.bgEmoji,
    required this.title,
    required this.lines,
    this.choices = const ['계속'],
  });

  final String bgEmoji;
  final String title;
  final List<CutsceneLine> lines;
  final List<String> choices;
}

/// 컷씬을 전체 화면으로 띄우고 선택한 버튼 인덱스를 반환한다.
Future<int?> showCutscene(BuildContext context, CutsceneData data) {
  return Navigator.of(context).push<int>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => _CutsceneView(data: data),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _CutsceneView extends StatefulWidget {
  const _CutsceneView({required this.data});

  final CutsceneData data;

  @override
  State<_CutsceneView> createState() => _CutsceneViewState();
}

class _CutsceneViewState extends State<_CutsceneView> {
  int _shown = 1;

  bool get _done => _shown >= widget.data.lines.length;

  void _advance() {
    if (!_done) setState(() => _shown++);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return PopScope(
      canPop: false, // 선택으로만 닫는다.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: Scaffold(
          backgroundColor: const Color(0xEE10141A),
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Opacity(
                    opacity: 0.14,
                    child: Text(data.bgEmoji,
                        style: const TextStyle(fontSize: 150)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(data.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: Colors.white70)),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView(
                          children: [
                            for (var i = 0; i < _shown; i++)
                              _LineBubble(line: data.lines[i]),
                          ],
                        ),
                      ),
                      if (_done)
                        for (var i = 0; i < data.choices.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: FilledButton(
                              style: i == 0
                                  ? null
                                  : FilledButton.styleFrom(
                                      backgroundColor: Colors.blueGrey),
                              onPressed: () => Navigator.pop(context, i),
                              child: Text(data.choices[i]),
                            ),
                          )
                      else
                        const Text('탭해서 계속 ▼',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LineBubble extends StatelessWidget {
  const _LineBubble({required this.line});

  final CutsceneLine line;

  @override
  Widget build(BuildContext context) {
    if (line.speaker == null) {
      // 내레이션.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(line.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white60,
                fontStyle: FontStyle.italic,
                fontSize: 14)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line.avatarId != null)
            CharacterAvatar(avatarId: line.avatarId!, size: 40)
          else
            Text(line.emoji ?? '🙂', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.speaker!,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54)),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(line.text,
                      style:
                          const TextStyle(fontSize: 15, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
