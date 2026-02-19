import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  // Confirmation from user for original project
  static const String _googleSdkKey = 'goog_DwiaMOvtMIohMzQdVOfJYAFDqPj';
  static const String _entitlementId = 'entlad0336decf';

  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_googleSdkKey);
    } else if (Platform.isIOS) {
      // User mentioned "no iOS for now", using Android key as placeholder if ever run on iOS
      configuration = PurchasesConfiguration(_googleSdkKey);
    } else {
      return;
    }

    await Purchases.configure(configuration);
    _isInitialized = true;
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } on PlatformException catch (e) {
      print('Error fetching customer info: $e');
      return null;
    }
  }

  Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        debugPrint('⚠️ RevenueCat: No current offering found in dashboard.');
      } else {
        debugPrint(
          '✅ RevenueCat: Offerings retrieved: ${offerings.current?.identifier}',
        );
        debugPrint(
          '📦 Packages found: ${offerings.current?.availablePackages.length}',
        );
        for (var p in offerings.current!.availablePackages) {
          debugPrint(' - ${p.identifier}: ${p.storeProduct.priceString}');
        }
      }
      return offerings;
    } on PlatformException catch (e) {
      debugPrint('❌ Error fetching offerings: $e');
      return null;
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      return customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        print('Error purchasing package: $e');
      }
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
    } on PlatformException catch (e) {
      print('Error restoring purchases: $e');
      return false;
    }
  }

  Future<bool> isPremium() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  Future<void> logIn(String userId) async {
    try {
      await Purchases.logIn(userId);
    } on PlatformException catch (e) {
      debugPrint('Error logging in to RevenueCat: $e');
    }
  }

  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } on PlatformException catch (e) {
      debugPrint('Error logging out from RevenueCat: $e');
    }
  }
}
