import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../character/character_avatar.dart';
import '../sound.dart';

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
    this.video,
  });

  final String bgEmoji;
  final String title;
  final List<CutsceneLine> lines;
  final List<String> choices;

  /// `assets/videos/*.mp4` — 파일이 있으면 배경 영상으로 재생(무음 루프),
  /// 없으면 [bgEmoji] Ken Burns 연출로 폴백.
  final String? video;
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
  bool _typing = true; // 마지막 줄이 타자기 연출 중인지
  VideoPlayerController? _video;

  bool get _done => _shown >= widget.data.lines.length;

  @override
  void initState() {
    super.initState();
    Sfx.play('cutscene', volume: 0.5);
    final path = widget.data.video;
    if (path != null) {
      final c = VideoPlayerController.asset(path);
      c
          .initialize()
          .then((_) {
            if (!mounted) {
              c.dispose();
              return;
            }
            c
              ..setLooping(true)
              ..setVolume(0)
              ..play();
            setState(() => _video = c);
          })
          .catchError((_) {
            c.dispose(); // 영상 없음 → 이모지 폴백
          });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  void _advance() {
    if (_typing) {
      setState(() => _typing = false); // 타이핑 중 탭 → 즉시 전체 표시
    } else if (!_done) {
      setState(() {
        _shown++;
        _typing = true;
      });
    }
  }

  Widget _background() {
    final video = _video;
    if (video != null && video.value.isInitialized) {
      final size = video.value.size;
      return Opacity(
        opacity: 0.5,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(video),
          ),
        ),
      );
    }
    // Ken Burns: 배경 이모지가 아주 천천히 커진다 (1회, 무한 반복 아님).
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.18),
        duration: const Duration(seconds: 20),
        curve: Curves.easeOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Opacity(
          opacity: 0.14,
          child: Text(
            widget.data.bgEmoji,
            style: const TextStyle(fontSize: 150),
          ),
        ),
      ),
    );
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
          body: Stack(
            fit: StackFit.expand,
            children: [
              _background(),
              // 레터박스 (시네마틱 상하 검은 띠).
              const Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 24,
                  width: double.infinity,
                  child: ColoredBox(color: Colors.black),
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 24,
                  width: double.infinity,
                  child: ColoredBox(color: Colors.black),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView(
                          children: [
                            for (var i = 0; i < _shown; i++)
                              _LineBubble(
                                line: data.lines[i],
                                // 마지막 줄만 타자기 연출.
                                typing: _typing && i == _shown - 1,
                                onTypingDone: () {
                                  if (mounted) {
                                    setState(() => _typing = false);
                                  }
                                },
                              ),
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
                                      backgroundColor: Colors.blueGrey,
                                    ),
                              onPressed: () => Navigator.pop(context, i),
                              child: Text(data.choices[i]),
                            ),
                          )
                      else
                        const Text(
                          '탭해서 계속 ▼',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 글자가 한 자씩 나타나는 텍스트. [enabled]가 false면 즉시 전체 표시.
class _TypewriterText extends StatelessWidget {
  const _TypewriterText(
    this.text, {
    required this.style,
    this.textAlign,
    this.enabled = true,
    this.onDone,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final bool enabled;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return Text(text, textAlign: textAlign, style: style);
    final chars = text.characters;
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: chars.length),
      duration: Duration(milliseconds: (chars.length * 28).clamp(200, 1600)),
      onEnd: onDone,
      builder: (_, n, _) =>
          Text(chars.take(n).toString(), textAlign: textAlign, style: style),
    );
  }
}

class _LineBubble extends StatelessWidget {
  const _LineBubble({
    required this.line,
    this.typing = false,
    this.onTypingDone,
  });

  final CutsceneLine line;
  final bool typing;
  final VoidCallback? onTypingDone;

  @override
  Widget build(BuildContext context) {
    if (line.speaker == null) {
      // 내레이션.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: _TypewriterText(
          line.text,
          textAlign: TextAlign.center,
          enabled: typing,
          onDone: onTypingDone,
          style: const TextStyle(
            color: Colors.white60,
            fontStyle: FontStyle.italic,
            fontSize: 14,
          ),
        ),
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
                Text(
                  line.speaker!,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _TypewriterText(
                    line.text,
                    enabled: typing,
                    onDone: onTypingDone,
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
