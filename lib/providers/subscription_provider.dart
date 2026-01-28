import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionProvider with ChangeNotifier {
  static const String _premiumKey = 'is_premium_user';
  bool _isPremium = false;
  bool _isLoading = true;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;

  SubscriptionProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_premiumKey) ?? false;
    _isLoading = false;
    notifyListeners();
  }

  /// MOCK: Simulate purchasing premium
  Future<void> purchasePremium() async {
    _isLoading = true;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);

    _isLoading = false;
    notifyListeners();
  }

  /// MOCK: Simulate restoring purchases
  Future<void> restorePurchases() async {
    _isLoading = true;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // For mock purposes, let's say restore always succeeds if we previously set it, 
    // but here we just re-read or force true for testing "Restore" flow. 
    // Let's just re-read from prefs or assume success for demo.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_premiumKey)) {
        _isPremium = prefs.getBool(_premiumKey) ?? false;
    } else {
        // If not found, maybe they are not premium.
        _isPremium = false;
    }

    _isLoading = false;
    notifyListeners();
  }
  
  /// DEBUG ONLY: Reset premium status
  Future<void> debugResetPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_premiumKey);
    _isPremium = false;
    notifyListeners();
  }
}
