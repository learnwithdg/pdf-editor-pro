import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../utils/app_feedback.dart';

class AdsService with WidgetsBindingObserver {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  static bool get isRunningInWidgetTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  // Actual IDs from your screenshot
  static const String appId = 'ca-app-pub-5724450075816645~6150129506';
  static const String bannerId = 'ca-app-pub-5724450075816645/5188246092';
  static const String bannerId2 = 'ca-app-pub-5724450075816645/6288290912';
  static const String interstitialId = 'ca-app-pub-5724450075816645/7409800896';
  static const String rewardedId = 'ca-app-pub-5724450075816645/5194701093';
  static const String nativeId = 'ca-app-pub-5724450075816645/3664401115';
  static const String nativeId2 = 'ca-app-pub-5724450075816645/4378716981';
  static const String appOpenId = String.fromEnvironment(
    'ADMOB_APP_OPEN_ID',
    defaultValue: 'ca-app-pub-5724450075816645/1038237775',
  );
  static const String rewardedInterstitialId = String.fromEnvironment(
    'ADMOB_REWARDED_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-5724450075816645/8373802313',
  );

  static const Duration _adRefreshInterval = Duration(seconds: 60);
  static const Duration _fullscreenCooldown = Duration(seconds: 60);
  static const Duration _startupNetworkGrace = Duration(seconds: 45);
  static const Duration _appOpenCooldown = Duration(minutes: 8);
  static const Duration _appOpenExpiry = Duration(hours: 4);

  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isAppOpenAdLoading = false;
  bool _isInterstitialAdLoading = false;
  bool _isRewardedAdLoading = false;
  bool _isRewardedInterstitialAdLoading = false;
  bool _isShowingFullscreenAd = false;
  bool _initialized = false;
  bool _observerRegistered = false;
  bool _didLogMissingAppOpenId = false;
  bool _didLogMissingRewardedInterstitialId = false;
  Future<void>? _initializationFuture;
  DateTime? _appOpenLoadedAt;
  DateTime? _lastAppOpenShownAt;
  DateTime? _lastInterstitialShownAt;
  DateTime? _lastAdLoadStartedAt;
  final DateTime _appStartedAt = DateTime.now();
  int _screenVisitCount = 0;
  int _toolLaunchCount = 0;
  int _appOpenRetryCount = 0;
  int _interstitialRetryCount = 0;
  int _rewardedRetryCount = 0;
  int _rewardedInterstitialRetryCount = 0;

  Future<void> _adLoadQueue = Future<void>.value();
  Timer? _refreshTimer;
  Timer? _appOpenRetryTimer;
  Timer? _interstitialRetryTimer;
  Timer? _rewardedRetryTimer;
  Timer? _rewardedInterstitialRetryTimer;
  Timer? _interstitialCadenceTimer;
  Timer? _startupWarmupTimer;
  Timer? _premiumWarmupTimer;
  final _adRefreshStreamController = StreamController<void>.broadcast();
  Stream<void> get adRefreshStream => _adRefreshStreamController.stream;

  static const AdRequest adRequest = AdRequest(
    keywords: ['pdf', 'document', 'office', 'scanner', 'productivity'],
    httpTimeoutMillis: 12000,
  );

  Future<void> init() async {
    if (isRunningInWidgetTest) {
      return;
    }
    if (_initialized) {
      return;
    }
    final existingInit = _initializationFuture;
    if (existingInit != null) {
      await existingInit;
      return;
    }
    _initializationFuture = _initialize();
    try {
      await _initializationFuture;
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    await MobileAds.instance.initialize();
    _initialized = true;
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    _startGlobalTimers();
    _scheduleStartupWarmup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    maybeShowAppOpenAd();
    warmUpPremiumAds();
  }

  Future<bool> waitForAdLoadSlot({
    Duration minSpacing = const Duration(seconds: 6),
    Duration startupQuietPeriod = const Duration(seconds: 12),
  }) async {
    if (isRunningInWidgetTest) {
      return false;
    }
    final appAgeBeforeInit = DateTime.now().difference(_appStartedAt);
    if (appAgeBeforeInit < startupQuietPeriod) {
      await Future<void>.delayed(startupQuietPeriod - appAgeBeforeInit);
    }

    try {
      await init();
    } catch (error) {
      debugPrint('AdMob initialization failed: $error');
      _initializationFuture = null;
      return false;
    }

    final queuedLoad = _adLoadQueue.catchError((_) {}).then((_) async {
      final lastLoadStartedAt = _lastAdLoadStartedAt;
      if (lastLoadStartedAt != null) {
        final elapsed = DateTime.now().difference(lastLoadStartedAt);
        if (elapsed < minSpacing) {
          await Future<void>.delayed(minSpacing - elapsed);
        }
      }

      _lastAdLoadStartedAt = DateTime.now();
    });

    _adLoadQueue = queuedLoad;
    await queuedLoad;
    return true;
  }

  void _startGlobalTimers() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_adRefreshInterval, (timer) {
      _adRefreshStreamController.add(null);
    });

    _interstitialCadenceTimer?.cancel();
    _interstitialCadenceTimer = Timer.periodic(_adRefreshInterval, (timer) {
      if (DateTime.now().difference(_appStartedAt) < _startupNetworkGrace) {
        return;
      }
      _loadAppOpenAd();
      _loadInterstitialAd(force: true);
      maybeShowInterstitial(cooldown: _fullscreenCooldown);
    });
  }

  void _scheduleStartupWarmup() {
    _startupWarmupTimer?.cancel();
    _startupWarmupTimer = Timer(_startupNetworkGrace, () {
      _loadAppOpenAd();
      _loadInterstitialAd(force: true);
      Timer(const Duration(seconds: 10), () => _loadRewardedAd(force: true));
      Timer(
        const Duration(seconds: 18),
        () => _loadRewardedInterstitialAd(force: true),
      );
    });
  }

  bool get _hasFreshAppOpenAd {
    final loadedAt = _appOpenLoadedAt;
    return _appOpenAd != null &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < _appOpenExpiry;
  }

  bool get _isInsideStartupGrace =>
      DateTime.now().difference(_appStartedAt) < _startupNetworkGrace;

  void _schedulePremiumWarmupAfterStartup() {
    if (isRunningInWidgetTest) {
      return;
    }
    if (_premiumWarmupTimer?.isActive == true) {
      return;
    }
    final appAge = DateTime.now().difference(_appStartedAt);
    final delay = appAge >= _startupNetworkGrace
        ? const Duration(seconds: 1)
        : _startupNetworkGrace - appAge;
    _premiumWarmupTimer = Timer(delay, () => warmUpPremiumAds(force: true));
  }

  void _loadAppOpenAd({bool force = false}) {
    if (appOpenId.isEmpty) {
      if (!_didLogMissingAppOpenId) {
        debugPrint(
          'App open ads are wired, but ADMOB_APP_OPEN_ID was not provided at build time.',
        );
        _didLogMissingAppOpenId = true;
      }
      return;
    }
    if (!force && _isInsideStartupGrace) {
      _schedulePremiumWarmupAfterStartup();
      return;
    }
    unawaited(_loadAppOpenAdInternal(force: force));
  }

  Future<void> _loadAppOpenAdInternal({bool force = false}) async {
    if (_isAppOpenAdLoading || _hasFreshAppOpenAd) {
      return;
    }
    _isAppOpenAdLoading = true;
    final canLoad = await waitForAdLoadSlot(
      minSpacing: const Duration(seconds: 8),
      startupQuietPeriod: force
          ? const Duration(seconds: 0)
          : _startupNetworkGrace,
    );
    if (!canLoad) {
      _isAppOpenAdLoading = false;
      return;
    }

    AppOpenAd.load(
      adUnitId: appOpenId,
      request: adRequest,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd?.dispose();
          _appOpenAd = ad;
          _appOpenLoadedAt = DateTime.now();
          _isAppOpenAdLoading = false;
          _appOpenRetryCount = 0;
          _appOpenRetryTimer?.cancel();
        },
        onAdFailedToLoad: (err) {
          _isAppOpenAdLoading = false;
          _appOpenAd = null;
          _appOpenLoadedAt = null;
          _scheduleAppOpenRetry(isNoFill: err.code == 3);
        },
      ),
    );
  }

  void maybeShowAppOpenAd() {
    if (appOpenId.isEmpty || _isShowingFullscreenAd) {
      return;
    }

    if (!_hasFreshAppOpenAd) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _appOpenLoadedAt = null;
      _loadAppOpenAd();
      return;
    }

    final appAge = DateTime.now().difference(_appStartedAt);
    if (appAge < _startupNetworkGrace) {
      return;
    }

    final lastShownAt = _lastAppOpenShownAt;
    if (lastShownAt != null &&
        DateTime.now().difference(lastShownAt) < _appOpenCooldown) {
      return;
    }

    final ad = _appOpenAd;
    if (ad == null) {
      _loadAppOpenAd();
      return;
    }

    _appOpenAd = null;
    _appOpenLoadedAt = null;
    _isShowingFullscreenAd = true;
    _lastAppOpenShownAt = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdDismissedFullScreenContent: (shownAd) {
        _isShowingFullscreenAd = false;
        shownAd.dispose();
        _loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (shownAd, error) {
        _isShowingFullscreenAd = false;
        shownAd.dispose();
        _loadAppOpenAd();
      },
    );
    ad.show();
  }

  void _loadInterstitialAd({bool force = false}) {
    if (!force && _isInsideStartupGrace) {
      _schedulePremiumWarmupAfterStartup();
      return;
    }
    unawaited(_loadInterstitialAdInternal(force: force));
  }

  Future<void> _loadInterstitialAdInternal({bool force = false}) async {
    if (_isInterstitialAdLoading) return;
    if (_interstitialAd != null) return;
    _isInterstitialAdLoading = true;
    final canLoad = await waitForAdLoadSlot(
      minSpacing: const Duration(seconds: 8),
      startupQuietPeriod: force
          ? const Duration(seconds: 0)
          : _startupNetworkGrace,
    );
    if (!canLoad) {
      _isInterstitialAdLoading = false;
      return;
    }
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: adRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          _interstitialRetryCount = 0;
          _interstitialRetryTimer?.cancel();
        },
        onAdFailedToLoad: (err) {
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
          _scheduleInterstitialRetry(isNoFill: err.code == 3);
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (_isShowingFullscreenAd) {
      return;
    }

    if (_interstitialAd == null) {
      _loadInterstitialAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingFullscreenAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingFullscreenAd = false;
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingFullscreenAd = false;
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
    );
    _lastInterstitialShownAt = DateTime.now();
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  void registerScreenVisit() {
    _screenVisitCount++;
    if (_screenVisitCount >= 2) {
      _screenVisitCount = 0;
      maybeShowInterstitial(cooldown: _fullscreenCooldown);
    } else {
      warmUpPremiumAds();
    }
  }

  void registerToolLaunch() {
    _toolLaunchCount++;
    _loadInterstitialAd(force: true);
    _loadRewardedAd(force: true);
    _loadRewardedInterstitialAd(force: true);
    _loadAppOpenAd(force: true);

    if (_toolLaunchCount >= 3) {
      _toolLaunchCount = 0;
      maybeShowInterstitial(cooldown: _fullscreenCooldown);
    }
  }

  Future<bool> showToolGateAds(BuildContext context) async {
    registerToolLaunch();

    await showRewardedInterstitialAd(context);
    if (!context.mounted) {
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) {
      return false;
    }
    await showRewardedAd(context);
    if (!context.mounted) {
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    maybeShowInterstitial(cooldown: _fullscreenCooldown);
    return true;
  }

  void warmUpPremiumAds({bool force = false}) {
    if (!force && _isInsideStartupGrace) {
      _schedulePremiumWarmupAfterStartup();
      return;
    }
    _loadInterstitialAd(force: force);
    _loadAppOpenAd(force: force);
    if (force) {
      _loadRewardedAd(force: true);
      _loadRewardedInterstitialAd(force: true);
    }
  }

  void maybeShowInterstitial({Duration cooldown = _fullscreenCooldown}) {
    if (_isShowingFullscreenAd) {
      return;
    }
    if (DateTime.now().difference(_appStartedAt) < _startupNetworkGrace) {
      warmUpPremiumAds();
      return;
    }
    final lastShownAt = _lastInterstitialShownAt;
    if (lastShownAt != null &&
        DateTime.now().difference(lastShownAt) < cooldown) {
      return;
    }
    showInterstitialAd();
  }

  void _loadRewardedAd({bool force = false}) {
    if (!force && _isInsideStartupGrace) {
      _schedulePremiumWarmupAfterStartup();
      return;
    }
    unawaited(_loadRewardedAdInternal(force: force));
  }

  void _loadRewardedInterstitialAd({bool force = false}) {
    if (rewardedInterstitialId.isEmpty) {
      if (!_didLogMissingRewardedInterstitialId) {
        debugPrint(
          'Rewarded interstitial ads are wired, but ADMOB_REWARDED_INTERSTITIAL_ID was not provided.',
        );
        _didLogMissingRewardedInterstitialId = true;
      }
      return;
    }
    if (!force && _isInsideStartupGrace) {
      _schedulePremiumWarmupAfterStartup();
      return;
    }
    unawaited(_loadRewardedInterstitialAdInternal(force: force));
  }

  Future<void> _loadRewardedAdInternal({bool force = false}) async {
    if (_isRewardedAdLoading) return;
    if (_rewardedAd != null) return;
    _isRewardedAdLoading = true;
    final canLoad = await waitForAdLoadSlot(
      minSpacing: const Duration(seconds: 8),
      startupQuietPeriod: force
          ? const Duration(seconds: 0)
          : _startupNetworkGrace,
    );
    if (!canLoad) {
      _isRewardedAdLoading = false;
      return;
    }
    RewardedAd.load(
      adUnitId: rewardedId,
      request: adRequest,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          _rewardedRetryCount = 0;
          _rewardedRetryTimer?.cancel();
        },
        onAdFailedToLoad: (err) {
          _isRewardedAdLoading = false;
          _rewardedAd = null;
          _scheduleRewardedRetry(isNoFill: err.code == 3);
        },
      ),
    );
  }

  Future<bool> showRewardedAd(BuildContext context) async {
    final completer = Completer<bool>();

    // Show a loading dialog while waiting for ad if not ready
    if (_rewardedAd == null) {
      _loadRewardedAd(force: true);
      AppFeedback.showInfo(
        context,
        'Preparing a quick reward ad. Your action will continue in a moment.',
      );
      // Give it 2 seconds to load
      await Future.delayed(const Duration(seconds: 2));
    }

    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          _isShowingFullscreenAd = true;
        },
        onAdDismissedFullScreenContent: (ad) {
          _isShowingFullscreenAd = false;
          ad.dispose();
          _loadRewardedAd(force: true);
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          _isShowingFullscreenAd = false;
          ad.dispose();
          _loadRewardedAd(force: true);
          if (!completer.isCompleted) {
            completer.complete(true); // Allow as fallback
          }
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
      );
      _rewardedAd = null;
    } else {
      completer.complete(
        true,
      ); // If still no ad, don't block the user (standard practice)
    }

    return completer.future;
  }

  Future<bool> showRewardedInterstitialAd(BuildContext context) async {
    if (rewardedInterstitialId.isEmpty) {
      return showRewardedAd(context);
    }

    final completer = Completer<bool>();
    if (_rewardedInterstitialAd == null) {
      _loadRewardedInterstitialAd(force: true);
      AppFeedback.showInfo(
        context,
        'Preparing a premium reward ad. Your action will continue shortly.',
      );
      await Future.delayed(const Duration(seconds: 2));
    }

    final ad = _rewardedInterstitialAd;
    if (ad == null || _isShowingFullscreenAd) {
      completer.complete(true);
      return completer.future;
    }

    _rewardedInterstitialAd = null;
    ad.fullScreenContentCallback =
        FullScreenContentCallback<RewardedInterstitialAd>(
          onAdShowedFullScreenContent: (shownAd) {
            _isShowingFullscreenAd = true;
          },
          onAdDismissedFullScreenContent: (shownAd) {
            _isShowingFullscreenAd = false;
            shownAd.dispose();
            _loadRewardedInterstitialAd(force: true);
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          },
          onAdFailedToShowFullScreenContent: (shownAd, error) {
            _isShowingFullscreenAd = false;
            shownAd.dispose();
            _loadRewardedInterstitialAd(force: true);
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          },
        );
    await ad.show(
      onUserEarnedReward: (shownAd, reward) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
    );
    return completer.future;
  }

  Future<void> _loadRewardedInterstitialAdInternal({bool force = false}) async {
    if (_isRewardedInterstitialAdLoading) return;
    if (_rewardedInterstitialAd != null) return;
    _isRewardedInterstitialAdLoading = true;
    final canLoad = await waitForAdLoadSlot(
      minSpacing: const Duration(seconds: 8),
      startupQuietPeriod: force
          ? const Duration(seconds: 0)
          : _startupNetworkGrace,
    );
    if (!canLoad) {
      _isRewardedInterstitialAdLoading = false;
      return;
    }

    RewardedInterstitialAd.load(
      adUnitId: rewardedInterstitialId,
      request: adRequest,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _isRewardedInterstitialAdLoading = false;
          _rewardedInterstitialRetryCount = 0;
          _rewardedInterstitialRetryTimer?.cancel();
        },
        onAdFailedToLoad: (err) {
          _isRewardedInterstitialAdLoading = false;
          _rewardedInterstitialAd = null;
          _scheduleRewardedInterstitialRetry(isNoFill: err.code == 3);
        },
      ),
    );
  }

  Future<void> openAdInspector(BuildContext context) async {
    try {
      await init();
    } catch (error) {
      if (context.mounted) {
        AppFeedback.showError(
          context,
          error,
          fallback:
              'Ad diagnostics could not start because AdMob did not initialize.',
        );
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    MobileAds.instance.openAdInspector((error) {
      if (!context.mounted) {
        return;
      }
      if (error == null) {
        AppFeedback.showSuccess(context, 'Ad diagnostics closed successfully.');
      } else {
        AppFeedback.showError(
          context,
          error.message ?? error,
          fallback: 'Ad diagnostics could not open on this device.',
        );
      }
    });
  }

  void _scheduleInterstitialRetry({bool isNoFill = false}) {
    _interstitialRetryTimer?.cancel();
    final delaySeconds = _retryDelayFor(
      _interstitialRetryCount++,
      isNoFill: isNoFill,
    );
    _interstitialRetryTimer = Timer(
      Duration(seconds: delaySeconds),
      _loadInterstitialAd,
    );
  }

  void _scheduleAppOpenRetry({bool isNoFill = false}) {
    if (appOpenId.isEmpty) {
      return;
    }
    _appOpenRetryTimer?.cancel();
    final delaySeconds = _retryDelayFor(
      _appOpenRetryCount++,
      isNoFill: isNoFill,
    );
    _appOpenRetryTimer = Timer(Duration(seconds: delaySeconds), _loadAppOpenAd);
  }

  void _scheduleRewardedRetry({bool isNoFill = false}) {
    _rewardedRetryTimer?.cancel();
    final delaySeconds = _retryDelayFor(
      _rewardedRetryCount++,
      isNoFill: isNoFill,
    );
    _rewardedRetryTimer = Timer(
      Duration(seconds: delaySeconds),
      _loadRewardedAd,
    );
  }

  void _scheduleRewardedInterstitialRetry({bool isNoFill = false}) {
    if (rewardedInterstitialId.isEmpty) {
      return;
    }
    _rewardedInterstitialRetryTimer?.cancel();
    final delaySeconds = _retryDelayFor(
      _rewardedInterstitialRetryCount++,
      isNoFill: isNoFill,
    );
    _rewardedInterstitialRetryTimer = Timer(
      Duration(seconds: delaySeconds),
      _loadRewardedInterstitialAd,
    );
  }

  int _retryDelayFor(int retryCount, {bool isNoFill = false}) {
    final steps = isNoFill
        ? <int>[120, 300, 600, 900]
        : <int>[30, 90, 180, 300, 600];
    if (retryCount < steps.length) {
      return steps[retryCount];
    }
    return steps.last;
  }
}
