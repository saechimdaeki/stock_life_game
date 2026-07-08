import 'package:flutter/widgets.dart';

import 'ads_stub.dart' if (dart.library.io) 'ads_real.dart' as impl;

/// AdMob 광고 파사드. 웹 프리뷰·데스크톱·테스트 등 미지원 플랫폼에서는
/// 광고 없이 보상을 지급하는 스텁으로 동작해 개발 흐름이 끊기지 않는다.
class Ads {
  Ads._();

  /// 앱 시작 시 1회: UMP 동의 수집 → SDK 초기화 → 보상형 프리로드.
  /// 실패해도 게임 진행에는 영향이 없도록 내부에서 삼킨다.
  static Future<void> init() => impl.init();

  /// 보상형 광고를 재생하고 보상 조건 충족 여부를 반환한다.
  /// 광고를 불러오지 못했으면 false (보상 지급 금지).
  static Future<bool> showRewarded() => impl.showRewarded();

  /// 하루 정산 다이얼로그에 넣을 배너. 배너를 못 만드는 플랫폼이면 null.
  static Widget? settlementBanner() => impl.settlementBanner();
}
