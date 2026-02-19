import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';
import '../services/auth_service.dart';

class SubscriptionProvider with ChangeNotifier {
  final RevenueCatService _revenueCat = RevenueCatService();

  bool _isPremium = false;
  bool _isLoading = true;
  Offerings? _offerings;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  Offerings? get offerings => _offerings;

  SubscriptionProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _revenueCat.initialize();

      // Sync identity if already signed in
      final user = AuthService().currentUser;
      if (user != null) {
        await _revenueCat.logIn(user.uid);
      }

      // Check initial status
      _isPremium = await _revenueCat.isPremium();

      // Load offerings (prices, periods, etc.)
      _offerings = await _revenueCat.getOfferings();
    } catch (e) {
      debugPrint('❌ RevenueCat initialization failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Listen for customer info changes
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      final activeEntitlements = customerInfo.entitlements.active;
      _isPremium = activeEntitlements.containsKey('entlad0336decf');
      notifyListeners();
    });
  }

  /// Purchase a package
  Future<bool> purchasePackage(Package package) async {
    _isLoading = true;
    notifyListeners();

    final success = await _revenueCat.purchasePackage(package);

    if (success) {
      _isPremium = true;
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    _isLoading = true;
    notifyListeners();

    _isPremium = await _revenueCat.restorePurchases();

    _isLoading = false;
    notifyListeners();
  }

  /// Helper to get monthly package
  Package? get monthlyPackage => _offerings?.current?.monthly;

  /// Helper to get annual package
  Package? get annualPackage => _offerings?.current?.annual;

  /// Helper to get lifetime package
  Package? get lifetimePackage => _offerings?.current?.lifetime;
}
