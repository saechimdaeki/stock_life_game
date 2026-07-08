import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Android/iOS 실제 AdMob 구현. 그 외 dart:io 플랫폼(데스크톱·테스트 VM)은
// 스텁과 동일하게 동작한다.

bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

// 실제 AdMob 광고 단위 ID (Android)는 저장소에 커밋하지 않고 릴리즈 빌드 시
// --dart-define으로 주입한다 (tool/build_release.sh, git 미포함). 미주입이면
// 빈 문자열이라 아래 게터가 테스트 ID로 폴백한다.
const _prodRewardedAndroid = String.fromEnvironment('ADMOB_REWARDED_ANDROID');
const _prodBannerAndroid = String.fromEnvironment('ADMOB_BANNER_ANDROID');

// 구글 공식 테스트 광고 단위 ID. 디버그 빌드에서 실제 광고를 노출/클릭하면
// 무효 트래픽으로 계정이 정지될 수 있어, 디버그에선 항상 테스트 ID를 쓴다.
String get _testRewardedUnitId => Platform.isAndroid
    ? 'ca-app-pub-3940256099942544/5224354917'
    : 'ca-app-pub-3940256099942544/1712485313';
String get _testBannerUnitId => Platform.isAndroid
    ? 'ca-app-pub-3940256099942544/6300978111'
    : 'ca-app-pub-3940256099942544/2934735716';

// 릴리즈에서만 실제 ID. 실제 ID가 비어 있거나(미발급) iOS(앱 미등록)면
// 테스트 ID로 폴백한다.
String get _rewardedUnitId =>
    kDebugMode || !Platform.isAndroid || _prodRewardedAndroid.isEmpty
        ? _testRewardedUnitId
        : _prodRewardedAndroid;
String get _bannerUnitId =>
    kDebugMode || !Platform.isAndroid || _prodBannerAndroid.isEmpty
        ? _testBannerUnitId
        : _prodBannerAndroid;

RewardedAd? _rewarded;
bool _initialized = false;

Future<void> init() async {
  if (!_supported || _initialized) return;
  try {
    // UMP 동의 수집 (EEA 등 필요한 지역에서만 폼이 뜬다). 실패해도 계속.
    final consentDone = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
          }
        } finally {
          if (!consentDone.isCompleted) consentDone.complete();
        }
      },
      (_) {
        if (!consentDone.isCompleted) consentDone.complete();
      },
    );
    await consentDone.future.timeout(const Duration(seconds: 15));
  } catch (_) {
    // 동의 플로우 실패는 무시 — 광고 요청 가능 여부는 SDK가 다시 판단한다.
  }
  try {
    await MobileAds.instance.initialize();
    _initialized = true;
    unawaited(_loadRewarded());
  } catch (_) {}
}

/// 보상형 광고를 미리 로드해 둔다. 로드 완료/실패 시점에 future가 끝난다.
Future<void> _loadRewarded() {
  final done = Completer<void>();
  RewardedAd.load(
    adUnitId: _rewardedUnitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) {
        _rewarded = ad;
        done.complete();
      },
      onAdFailedToLoad: (_) {
        _rewarded = null;
        done.complete();
      },
    ),
  );
  return done.future;
}

Future<bool> showRewarded() async {
  if (!_supported) {
    // 스텁과 동일: 개발 확인용으로 잠깐 기다렸다가 보상 지급.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return true;
  }
  if (!_initialized) await init();
  if (_rewarded == null) {
    await _loadRewarded().timeout(const Duration(seconds: 10),
        onTimeout: () {});
    if (_rewarded == null) return false;
  }
  final ad = _rewarded!;
  _rewarded = null;
  var earned = false;
  final closed = Completer<void>();
  ad.fullScreenContentCallback = FullScreenContentCallback(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      if (!closed.isCompleted) closed.complete();
    },
    onAdFailedToShowFullScreenContent: (ad, _) {
      ad.dispose();
      if (!closed.isCompleted) closed.complete();
    },
  );
  await ad.show(onUserEarnedReward: (_, reward) => earned = true);
  await closed.future;
  unawaited(_loadRewarded()); // 다음 광고 미리 로드
  return earned;
}

Widget? settlementBanner() {
  if (!_supported) {
    return kDebugMode
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
  }
  return const _SettlementBanner();
}

/// 정산 다이얼로그용 320x50 배너. 로드 전엔 자리만 잡고, 실패하면 접힌다.
class _SettlementBanner extends StatefulWidget {
  const _SettlementBanner();

  @override
  State<_SettlementBanner> createState() => _SettlementBannerState();
}

class _SettlementBannerState extends State<_SettlementBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _failed = true);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return SizedBox(
      width: AdSize.banner.width.toDouble(),
      height: AdSize.banner.height.toDouble(),
      child: _loaded ? AdWidget(ad: _ad!) : const SizedBox.shrink(),
    );
  }
}
