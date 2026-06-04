import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';

class SmartBannerAd extends StatefulWidget {
  const SmartBannerAd({super.key});

  @override
  State<SmartBannerAd> createState() => _SmartBannerAdState();
}

class _SmartBannerAdState extends State<SmartBannerAd> {
  BannerAd? _bannerAd;
  AnchoredAdaptiveBannerAdSize? _adSize;
  bool _isLoaded = false;
  bool _isLoading = false;
  DateTime? _loadedAt;
  int _retryCount = 0;
  int _bannerAdUnitIndex = 0;
  StreamSubscription<void>? _refreshSub;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _refreshSub = AdsService().adRefreshStream.listen((_) {
      final loadedAt = _loadedAt;
      final shouldRefresh =
          loadedAt == null ||
          DateTime.now().difference(loadedAt) >= const Duration(seconds: 70);
      if (!_isLoading && (!_isLoaded || _bannerAd == null || shouldRefresh)) {
        _loadAd();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) {
      _loadAd();
    }
  }

  Future<void> _loadAd({bool allowFallback = true}) async {
    if (_isLoading) {
      return;
    }
    _isLoading = true;
    final canLoad = await AdsService().waitForAdLoadSlot(
      minSpacing: const Duration(seconds: 6),
      startupQuietPeriod: const Duration(seconds: 12),
    );
    if (!mounted || !canLoad) {
      _isLoading = false;
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width.truncate();
    final adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      screenWidth,
    );
    if (!mounted || adSize == null) {
      _isLoading = false;
      return;
    }

    final previousAd = _bannerAd;
    if (previousAd == null) {
      setState(() {
        _isLoaded = false;
        _adSize = adSize;
      });
    }

    final adUnitIds = <String>[AdsService.bannerId, AdsService.bannerId2];
    final adUnitId = adUnitIds[_bannerAdUnitIndex % adUnitIds.length];
    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: AdsService.adRequest,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
            _loadedAt = DateTime.now();
            _adSize = adSize;
          });
          previousAd?.dispose();
          _bannerAdUnitIndex = 0;
          _retryCount = 0;
          _retryTimer?.cancel();
          _isLoading = false;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint(
            'Banner ad failed: unit=$adUnitId code=${error.code} domain=${error.domain} message=${error.message}',
          );
          if (!mounted) {
            return;
          }
          if (allowFallback && _bannerAdUnitIndex < adUnitIds.length - 1) {
            _isLoading = false;
            _bannerAdUnitIndex++;
            unawaited(_loadAd(allowFallback: false));
            return;
          }
          setState(() {
            if (previousAd == null) {
              _bannerAd = null;
              _isLoaded = false;
              _loadedAt = null;
            }
          });
          _bannerAdUnitIndex = 0;
          _isLoading = false;
          _scheduleRetry(isNoFill: error.code == 3);
        },
      ),
    );
    await bannerAd.load();
  }

  void _scheduleRetry({bool isNoFill = false}) {
    _retryTimer?.cancel();
    final retrySteps = isNoFill
        ? <int>[120, 300, 600, 900]
        : <int>[30, 90, 180, 300];
    final delay = _retryCount < retrySteps.length
        ? retrySteps[_retryCount]
        : retrySteps.last;
    _retryCount++;
    _retryTimer = Timer(Duration(seconds: delay), () {
      if (mounted) {
        _loadAd();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null || _adSize == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Text(
                  'Sponsored',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _adSize!.width.toDouble(),
              height: _adSize!.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ],
        ),
      ),
    );
  }
}

class SmartNativeAd extends StatefulWidget {
  const SmartNativeAd({super.key, this.isSmall = false});

  final bool isSmall;

  @override
  State<SmartNativeAd> createState() => _SmartNativeAdState();
}

class _SmartNativeAdState extends State<SmartNativeAd> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  DateTime? _loadedAt;
  int _retryCount = 0;
  int _nativeAdUnitIndex = 0;
  StreamSubscription<void>? _refreshSub;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAd();
      }
    });
    _refreshSub = AdsService().adRefreshStream.listen((_) {
      final loadedAt = _loadedAt;
      final shouldRefresh =
          loadedAt == null ||
          DateTime.now().difference(loadedAt) >= const Duration(seconds: 90);
      if (!_isLoading && (!_isLoaded || _nativeAd == null || shouldRefresh)) {
        _loadAd();
      }
    });
  }

  void _loadAd() {
    unawaited(_loadAdInternal());
  }

  Future<void> _loadAdInternal({bool allowFallback = true}) async {
    if (_isLoading) {
      return;
    }
    _isLoading = true;
    final canLoad = await AdsService().waitForAdLoadSlot(
      minSpacing: const Duration(seconds: 8),
      startupQuietPeriod: const Duration(seconds: 15),
    );
    if (!mounted || !canLoad) {
      _isLoading = false;
      return;
    }

    final previousAd = _nativeAd;
    if (previousAd == null) {
      setState(() {
        _isLoaded = false;
      });
    }

    final adUnitIds = <String>[AdsService.nativeId, AdsService.nativeId2];
    final adUnitId = adUnitIds[_nativeAdUnitIndex % adUnitIds.length];
    final nativeAd = NativeAd(
      adUnitId: adUnitId,
      request: AdsService.adRequest,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoaded = true;
            _loadedAt = DateTime.now();
          });
          previousAd?.dispose();
          _nativeAdUnitIndex = 0;
          _retryCount = 0;
          _retryTimer?.cancel();
          _isLoading = false;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint(
            'Native ad failed: unit=$adUnitId code=${error.code} domain=${error.domain} message=${error.message}',
          );
          if (!mounted) {
            return;
          }
          if (allowFallback && _nativeAdUnitIndex < adUnitIds.length - 1) {
            _isLoading = false;
            _nativeAdUnitIndex++;
            unawaited(_loadAdInternal(allowFallback: false));
            return;
          }
          setState(() {
            if (previousAd == null) {
              _nativeAd = null;
              _isLoaded = false;
              _loadedAt = null;
            }
          });
          _nativeAdUnitIndex = 0;
          _isLoading = false;
          _scheduleRetry(isNoFill: error.code == 3);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.isSmall ? TemplateType.small : TemplateType.medium,
        mainBackgroundColor: const Color(0xFFFFFBF8),
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFFD63A2F),
          style: NativeTemplateFontStyle.bold,
          size: widget.isSmall ? 13 : 15,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF1C1917),
          style: NativeTemplateFontStyle.bold,
          size: widget.isSmall ? 15 : 18,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF57534E),
          size: widget.isSmall ? 12 : 14,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF78716C),
          size: widget.isSmall ? 11 : 13,
        ),
      ),
    );
    nativeAd.load();
  }

  void _scheduleRetry({bool isNoFill = false}) {
    _retryTimer?.cancel();
    final retrySteps = isNoFill
        ? <int>[120, 300, 600, 900]
        : <int>[30, 90, 180, 300];
    final delay = _retryCount < retrySteps.length
        ? retrySteps[_retryCount]
        : retrySteps.last;
    _retryCount++;
    _retryTimer = Timer(Duration(seconds: delay), () {
      if (mounted) {
        _loadAd();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    _retryTimer?.cancel();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      height: widget.isSmall ? 152 : 368,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              'Sponsored',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(child: AdWidget(ad: _nativeAd!)),
        ],
      ),
    );
  }
}
