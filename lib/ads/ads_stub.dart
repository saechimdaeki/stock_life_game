import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// 웹 등 AdMob 미지원 플랫폼용 스텁.
// google_mobile_ads가 dart:io에 의존해 웹 빌드가 깨지므로 조건부 import로 분리한다.

Future<void> init() async {}

/// 광고를 보는 척 잠깐 기다렸다가 보상을 지급한다 (개발 확인용).
Future<bool> showRewarded() async {
  await Future<void>.delayed(const Duration(milliseconds: 800));
  return true;
}

/// 디버그에선 레이아웃 확인용 플레이스홀더, 릴리즈에선 표시하지 않는다.
Widget? settlementBanner() => kDebugMode
    ? Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('광고 배너 영역 (이 플랫폼은 AdMob 미지원)',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      )
    : null;
