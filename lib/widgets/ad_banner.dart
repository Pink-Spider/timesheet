import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../services/ad_service.dart';
import '../services/purchase_service.dart';

/// 화면 하단 앵커드 적응형 배너.
///
/// 광고 제거를 구매했거나, SDK가 초기화되지 않았거나(오프라인·위젯 테스트),
/// 로드에 실패하면 공간을 차지하지 않고 사라진다.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // PurchaseService가 없는 트리(위젯 테스트)에서는 광고를 그리지 않는다.
    final purchases = context.watch<PurchaseService?>();
    if (purchases == null || purchases.adsRemoved) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: AdService.instance.ready,
      builder: (context, ready, _) =>
          ready ? const _BannerLoader() : const SizedBox.shrink(),
    );
  }
}

class _BannerLoader extends StatefulWidget {
  const _BannerLoader();

  @override
  State<_BannerLoader> createState() => _BannerLoaderState();
}

class _BannerLoaderState extends State<_BannerLoader> {
  BannerAd? _ad;
  bool _loaded = false;
  Orientation? _loadedFor;

  /// 실제 렌더된 광고 높이. 요청한 (large) 적응형 박스보다 작은 광고가
  /// 오면 그 높이로 줄여서 배너 아래에 빈 띠가 생기지 않게 한다.
  double? _height;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면 회전 시 적응형 배너 크기가 달라지므로 다시 로드한다.
    final orientation = MediaQuery.orientationOf(context);
    if (_loadedFor != orientation) {
      _loadedFor = orientation;
      _load(orientation);
    }
  }

  Future<void> _load(Orientation orientation) async {
    _ad?.dispose();
    _ad = null;
    if (_loaded) setState(() => _loaded = false);

    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
        orientation, width);
    if (size == null || !mounted) return;

    final ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          final actual = await (ad as BannerAd).getPlatformAdSize();
          if (!mounted) return;
          setState(() {
            _height = (actual ?? ad.size).height.toDouble();
            _loaded = true;
          });
        },
        // 실패하면 조용히 접힌 상태를 유지한다. 다음 화면 진입 때 재시도.
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    // 배너 아래에는 항상 MainShell의 NavigationBar가 있으므로 SafeArea 불필요.
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: _height ?? ad.size.height.toDouble(),
      child: Center(child: AdWidget(ad: ad)),
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }
}
