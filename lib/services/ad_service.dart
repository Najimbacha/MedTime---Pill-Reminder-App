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
      debugPrint('✅ AdService: MobileAds Initialized');
    } catch (e) {
      debugPrint('❌ AdService Initialization Error: $e');
    }
  }
}
