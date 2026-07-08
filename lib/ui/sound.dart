import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 효과음/BGM. `assets/audio/<이름>.wav`를 재생하고, 파일이 없거나
/// 플랫폼이 재생을 지원하지 않으면 조용히 넘어간다(무음 폴백).
/// 플레이스홀더 음원은 같은 파일명으로 덮어쓰면 교체된다.
class Sfx {
  Sfx._();

  /// 음소거 토글 상태 (홈 화면 버튼). ponytail: 세션 한정 — 저장 필요하면 세이브에 추가.
  static final ValueNotifier<bool> muted = ValueNotifier(false);

  static final bool _enabled =
      !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST');

  static AudioPlayer? _sfx;
  static AudioPlayer? _bgm;

  /// 단발 효과음. 연속 호출 시 이전 소리를 끊고 재생한다.
  static Future<void> play(String name, {double volume = 1}) async {
    if (!_enabled || muted.value) return;
    try {
      _sfx ??= AudioPlayer();
      await _sfx!.play(AssetSource('audio/$name.wav'), volume: volume);
    } catch (_) {
      /* 음원 없음/미지원 → 무음 */
    }
  }

  static Future<void> startBgm() async {
    if (!_enabled || muted.value) return;
    try {
      _bgm ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _bgm!.play(AssetSource('audio/bgm.wav'), volume: 0.35);
    } catch (_) {}
  }

  static Future<void> stopBgm() async => _bgm?.stop();

  static void toggleMute() {
    muted.value = !muted.value;
    muted.value ? stopBgm() : startBgm();
  }
}
