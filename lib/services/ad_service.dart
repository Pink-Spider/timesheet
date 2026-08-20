import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 초기화와 UMP(개인정보 동의) 흐름.
///
/// init()은 main()에서만 호출한다 — 위젯 테스트에서 플랫폼 채널을 건드리지
/// 않기 위한 앱 전체 규칙(NotificationService와 동일). 초기화 전이거나
/// 실패하면 [ready]가 false로 남아 배너가 아예 그려지지 않는다.
class AdService {
  AdService._();

  static final instance = AdService._();

  static const _bannerAndroidRelease =
      'ca-app-pub-6450383918866901/2882914243';
  static const _bannerIosRelease = 'ca-app-pub-6450383918866901/5696779849';

  /// 디버그 빌드는 구글 공식 테스트 광고 단위를 쓴다 — 실광고를 개발 중에
  /// 노출/클릭하면 AdMob 계정이 정지될 수 있다.
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/9214589741' // 테스트: 적응형 배너
          : 'ca-app-pub-3940256099942544/2435281174';
    }
    return Platform.isAndroid ? _bannerAndroidRelease : _bannerIosRelease;
  }

  /// SDK 초기화 완료 여부. AdBanner는 true일 때만 로드를 시도한다.
  final ready = ValueNotifier<bool>(false);

  bool _initStarted = false;

  /// 동의 수집(UMP) → SDK 초기화. 오프라인 등으로 실패해도 앱 동작에는
  /// 영향이 없다 — 이번 세션은 광고 없이 동작하고 다음 실행에서 재시도된다.
  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      await _gatherConsent();
      if (await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.initialize();
        ready.value = true;
      }
    } catch (_) {
      // 광고는 부가 기능: 초기화 실패를 사용자에게 알리지 않는다.
    }
  }

  /// GDPR(EEA/영국) 등 동의가 필요한 지역에서만 UMP 양식이 표시된다.
  /// 그 외 지역에서는 두 호출 모두 즉시 통과한다.
  Future<void> _gatherConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => updated.complete(),
      (FormError error) => updated.complete(),
    );
    await updated.future;

    final formDone = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired(
      (FormError? error) => formDone.complete(),
    );
    await formDone.future;
  }
}