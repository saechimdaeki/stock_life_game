import 'package:flutter/material.dart';

import 'ads.dart';

/// 보상형 광고 게이트: 로딩 오버레이를 띄우고 광고를 재생한 뒤
/// 보상 지급 여부를 돌려준다. 실패하면 스낵바로 알린다.
Future<bool> watchRewardedAd(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.maybeOf(context);
  var dialogOpen = true;
  // 광고 SDK가 전면 광고를 띄우기 전까지의 공백을 로딩 표시로 메운다.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  ).whenComplete(() => dialogOpen = false);
  var earned = false;
  try {
    earned = await Ads.showRewarded();
  } finally {
    if (dialogOpen) navigator.pop();
  }
  if (!earned) {
    messenger?.showSnackBar(const SnackBar(
        content: Text('광고를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.')));
  }
  return earned;
}
