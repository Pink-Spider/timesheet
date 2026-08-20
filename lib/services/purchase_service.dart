import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "광고 제거" 일회성(비소모성) 인앱결제.
///
/// 서버 없이 스토어 결제 API + SharedPreferences 플래그로만 동작한다.
/// 앱 재설치·기기 변경 시에는 설정 화면의 "구매 복원"으로 되찾는다.
/// init()은 main()에서만 호출한다 — 위젯 테스트에서 플랫폼 채널 미사용 유지.
class PurchaseService extends ChangeNotifier {
  PurchaseService(this._prefs);

  /// Play Console / App Store Connect 양쪽에 같은 제품 ID로 등록해야 한다.
  static const productId = 'remove_ads';

  static const _kAdsRemoved = 'adsRemoved';

  final SharedPreferences _prefs;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 광고 제거 구매 여부. AdBanner와 설정 화면이 이 값을 본다.
  bool get adsRemoved => _prefs.getBool(_kAdsRemoved) ?? false;

  ProductDetails? _product;

  /// 스토어에서 조회한 상품(현지 통화 가격 포함). null이면 스토어 연결 실패.
  ProductDetails? get product => _product;

  bool _pending = false;

  /// 결제 진행 중(스토어 시트 표시 중 또는 승인 대기).
  bool get pending => _pending;

  Future<void> init() async {
    _sub = InAppPurchase.instance.purchaseStream.listen(_onPurchases);
    if (!await InAppPurchase.instance.isAvailable()) return;
    final response =
        await InAppPurchase.instance.queryProductDetails({productId});
    if (response.productDetails.isNotEmpty) {
      _product = response.productDetails.first;
      notifyListeners();
    }
  }

  Future<void> buyRemoveAds() async {
    final product = _product;
    if (product == null || _pending) return;
    _pending = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      _pending = false;
      notifyListeners();
    }
  }

  /// 결과는 [InAppPurchase.purchaseStream]으로 (restored 상태) 돌아온다.
  Future<void> restore() => InAppPurchase.instance.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          await _prefs.setBool(_kAdsRemoved, true);
          _pending = false;
        case PurchaseStatus.error || PurchaseStatus.canceled:
          _pending = false;
        case PurchaseStatus.pending:
          _pending = true;
      }
      // 스토어에 구매 처리 완료를 알리지 않으면 일정 시간 후 자동 환불된다.
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
