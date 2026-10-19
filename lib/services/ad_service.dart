import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Firebase-controlled ads toggle
  static bool _adsEnabled = true;

  /// Update ads enabled status from Firebase config
  static void setAdsEnabled(bool enabled) {
    _adsEnabled = enabled;
    log('🎯 Ads enabled: $_adsEnabled');
    if (!_adsEnabled) {
      // Dispose all ads if disabled
      disposeAds();
    }
  }

  /// Check if ads are enabled
  static bool get adsEnabled => _adsEnabled;
  static bool get canLoadAds => _adsEnabled && _sdkInitialized;
  static String get _interstitialAdUnitId => Platform.isAndroid
      ? (kDebugMode
            ? 'ca-app-pub-3940256099942544/1033173712'
            : 'ca-app-pub-3233536447139983/3796226382')
      : (kDebugMode
            ? 'ca-app-pub-3940256099942544/4411468910'
            : 'ca-app-pub-3233536447139983/7088306694');

  static String get _appOpenAdUnitId => Platform.isAndroid
      ? (kDebugMode
            ? 'ca-app-pub-3940256099942544/9257395921'
            : 'ca-app-pub-3233536447139983/9394562646')
      : (kDebugMode
            ? 'ca-app-pub-3940256099942544/5575463023'
            : 'ca-app-pub-3233536447139983/8589293885');

  static String get _bannerAdUnitId => Platform.isAndroid
      ? (kDebugMode
            ? 'ca-app-pub-3940256099942544/6300978111'
            : 'ca-app-pub-3233536447139983/1170063049')
      : (kDebugMode
            ? 'ca-app-pub-3940256099942544/2934735716'
            : 'ca-app-pub-3233536447139983/3100960222');

  static String get _nativeAdUnitId => Platform.isAndroid
      ? (kDebugMode
            ? 'ca-app-pub-3940256099942544/2247696110'
            : 'ca-app-pub-3233536447139983/1170063049')
      : (kDebugMode
            ? 'ca-app-pub-3940256099942544/3986624511'
            : 'ca-app-pub-3233536447139983/9902375551');

  /// Public getter for Banner Ad unit ID
  static String get bannerAdUnitId => _bannerAdUnitId;

  static final ValueNotifier<bool> nativeAdReady = ValueNotifier(false);

  static AppOpenAd? _appOpenAd;
  static NativeAd? _nativeAd;
  static InterstitialAd? _interstitialAd;

  static bool _isAppOpenAdReady = false;
  static bool _isNativeAdReady = false;
  static bool _isInterstitialAdReady = false;
  static bool _isShowingAppOpenAd = false;

  static bool _sdkInitialized = false;
  static Future<void>? _initialization;

  static Future<void> initialize() =>
      _initialization ??= _initializeWithConsent();

  static Future<void> _initializeWithConsent() async {
    final completer = Completer<void>();

    Future<void> finishInitialization() async {
      if (completer.isCompleted) return;
      try {
        final canRequestAds = await ConsentInformation.instance.canRequestAds();
        if (canRequestAds) {
          await MobileAds.instance.initialize();
          _sdkInitialized = true;
          debugPrint('✅ AdMob initialized after privacy consent check');
        } else {
          debugPrint('⚠️ AdMob paused until the user can be shown ads');
        }
      } catch (error) {
        debugPrint('AdMob initialization failed: $error');
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    }

    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            debugPrint(
              'AdMob consent form error ${formError.errorCode}: '
              '${formError.message}',
            );
          }
          await finishInitialization();
        });
      },
      (formError) async {
        debugPrint(
          'AdMob consent update error ${formError.errorCode}: '
          '${formError.message}',
        );
        // A previous valid consent choice may still allow ad requests.
        await finishInitialization();
      },
    );

    await completer.future;
  }

  static void loadAppOpenAd() {
    // App-open test ads can render as an empty Android activity on some OEM
    // devices. They are not needed while developing and must never cover the
    // first Flutter frame.
    if (kDebugMode) return;
    if (!_adsEnabled) {
      debugPrint('⚠️ Ads disabled, skipping App Open Ad load');
      return;
    }
    if (!_sdkInitialized) {
      debugPrint('⏳ AdMob is not ready, skipping App Open Ad load');
      return;
    }

    if (_appOpenAd != null) {
      _appOpenAd!.dispose();
      _appOpenAd = null;
    }
    _isAppOpenAdReady = false;

    debugPrint('⏳ Loading App Open: $_appOpenAdUnitId');
    AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (AppOpenAd ad) {
          _appOpenAd = ad;
          _isAppOpenAdReady = true;
          debugPrint('✅ App Open Ad Loaded');
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ App Open Failed: ${error.message}');
          _isAppOpenAdReady = false;
        },
      ),
    );
  }

  static void showAppOpenAdIfAvailable() {
    if (kDebugMode) return;
    // Check if ads are enabled
    if (!_adsEnabled) {
      debugPrint('⚠️ Ads disabled, skipping App Open Ad show');
      return;
    }

    if (_isShowingAppOpenAd) {
      debugPrint('⚠️ App Open Ad already showing');
      return;
    }

    if (_isAppOpenAdReady && _appOpenAd != null) {
      _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (Ad ad) {
          _isShowingAppOpenAd = true;
        },
        onAdDismissedFullScreenContent: (Ad ad) {
          ad.dispose();
          _isAppOpenAdReady = false;
          _isShowingAppOpenAd = false;
          loadAppOpenAd();
        },
        onAdFailedToShowFullScreenContent: (Ad ad, AdError error) {
          ad.dispose();
          _isAppOpenAdReady = false;
          _isShowingAppOpenAd = false;
          loadAppOpenAd();
        },
      );
      _appOpenAd!.show();
      _appOpenAd = null;
    } else {
      debugPrint('⚠️ App Open Ad not ready, loading...');
      loadAppOpenAd();
    }
  }

  static void loadNativeAd() {
    if (!_adsEnabled) {
      debugPrint('⚠️ Ads disabled, skipping Native Ad load');
      return;
    }
    if (!_sdkInitialized) {
      debugPrint('⏳ AdMob is not ready, skipping Native Ad load');
      return;
    }

    _nativeAd?.dispose();
    _isNativeAdReady = false;
    nativeAdReady.value = false;

    debugPrint('⏳ Loading Native Ad: $_nativeAdUnitId');
    _nativeAd = NativeAd(
      adUnitId: _nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          _isNativeAdReady = true;
          nativeAdReady.value = true;
          debugPrint('✅ Native Ad Loaded');
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('❌ Native Failed: ${error.message}');
          ad.dispose();
          _isNativeAdReady = false;
          nativeAdReady.value = false;
          Future.delayed(const Duration(seconds: 30), loadNativeAd);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 10.0,
      ),
    );
    _nativeAd!.load();
  }

  static NativeAd? getNativeAd() => _isNativeAdReady ? _nativeAd : null;
  static double get nativeAdHeight => 350.0;

  static void loadInterstitialAd() {
    if (!_adsEnabled) {
      debugPrint('⚠️ Ads disabled, skipping Interstitial Ad load');
      return;
    }
    if (!_sdkInitialized) {
      debugPrint('⏳ AdMob is not ready, skipping Interstitial Ad load');
      return;
    }

    _interstitialAd?.dispose();
    _isInterstitialAdReady = false;

    debugPrint('⏳ Loading Interstitial: $_interstitialAdUnitId');
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          debugPrint('✅ Interstitial Ad Loaded');
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ Interstitial Failed: ${error.message}');
          _isInterstitialAdReady = false;
          Future.delayed(const Duration(seconds: 30), loadInterstitialAd);
        },
      ),
    );
  }

  static void showInterstitialAd({VoidCallback? onAdDismissed}) {
    // Check if ads are enabled
    if (!_adsEnabled) {
      debugPrint('⚠️ Ads disabled, skipping Interstitial Ad show');
      onAdDismissed?.call();
      return;
    }

    debugPrint('📺 Attempting to show Interstitial Video/Image...');

    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (InterstitialAd ad) =>
            debugPrint('📺 Ad Showed'),
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _isInterstitialAdReady = false;
          onAdDismissed?.call();
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          _isInterstitialAdReady = false;
          onAdDismissed?.call();
          loadInterstitialAd();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      debugPrint('⚠️ Ad not ready, skipping to next step');
      onAdDismissed?.call();
    }
  }

  static void disposeAds() {
    _appOpenAd?.dispose();
    _nativeAd?.dispose();
    _interstitialAd?.dispose();
    _isAppOpenAdReady = _isNativeAdReady = _isInterstitialAdReady = false;
    nativeAdReady.value = false;
  }
}
