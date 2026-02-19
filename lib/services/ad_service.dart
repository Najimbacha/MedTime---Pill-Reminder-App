import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  static AdService get instance => _instance;

  AdService._internal();

  // Test Ad Unit IDs
  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return ''; // Fallback for unsupported platforms
  }

  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      // Optional: Set test device IDs if needed
      // MobileAds.instance.updateRequestConfiguration(
      //   RequestConfiguration(testDeviceIds: ['YOUR_DEVICE_ID']),
      // );
      debugPrint('✅ AdService: MobileAds Initialized');
    } catch (e) {
      debugPrint('❌ AdService Initialization Error: $e');
    }
  }

  // Interstitial Ad Unit IDs
  String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return '';
  }

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;

  void loadInterstitialAd() {
    if (_isInterstitialAdLoading || _interstitialAd != null) return;

    _isInterstitialAdLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ Interstitial Ad Loaded');
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _interstitialAd = null;
                  loadInterstitialAd(); // Preload next
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  ad.dispose();
                  _interstitialAd = null;
                  loadInterstitialAd();
                },
              );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Interstitial Ad Failed to Load: $error');
          _isInterstitialAdLoading = false;
        },
      ),
    );
  }

  void showInterstitialAd({bool isPremium = false}) {
    if (isPremium) return;
    if (_interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      debugPrint('⚠️ Interstitial Ad not ready yet');
      loadInterstitialAd();
    }
  }
}
