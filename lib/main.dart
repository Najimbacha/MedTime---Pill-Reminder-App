import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/log_provider.dart';
import 'providers/medicine_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/snooze_provider.dart';
import 'providers/statistics_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/app_runtime_state.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/streak_service.dart';
import 'widgets/notification_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App Starting...');

  var status = const BootstrapStatus.initial();

  // 1) Firebase (optional for local mode)
  try {
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
    status = status.copyWith(firebaseInitialized: true);
    debugPrint('✅ Firebase Initialized');
  } catch (e) {
    status = status.copyWith(firebaseError: e.toString());
    debugPrint('⚠️ Firebase unavailable. Continuing in local mode. Error: $e');
  }

  // 2) Crashlytics only if Firebase is available.
  if (status.firebaseInitialized) {
    try {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      status = status.copyWith(crashlyticsConfigured: true);
      debugPrint('📊 Crashlytics Initialized');
    } catch (e) {
      debugPrint('⚠️ Crashlytics init skipped: $e');
    }
  }

  // 3) Local/core services should always attempt initialization.
  try {
    debugPrint('🔔 Initializing NotificationService...');
    await NotificationService.instance.initialize().timeout(
      const Duration(seconds: 10),
    );
    status = status.copyWith(notificationServiceInitialized: true);
    debugPrint('✅ NotificationService Initialized');
  } catch (e) {
    debugPrint('⚠️ NotificationService init failed: $e');
  }

  try {
    debugPrint('⚙️ Initializing SettingsService...');
    await SettingsService.instance.ensureInitialized().timeout(
      const Duration(seconds: 5),
    );
    status = status.copyWith(settingsServiceInitialized: true);
    debugPrint('✅ SettingsService Initialized');
  } catch (e) {
    debugPrint('⚠️ SettingsService init failed: $e');
  }

  try {
    debugPrint('🏆 Initializing StreakService...');
    await StreakService.instance.initialize().timeout(
      const Duration(seconds: 5),
    );
    status = status.copyWith(streakServiceInitialized: true);
    debugPrint('✅ StreakService Initialized');
  } catch (e) {
    debugPrint('⚠️ StreakService init failed: $e');
  }

  try {
    debugPrint('💰 Initializing AdService...');
    await AdService.instance.initialize().timeout(const Duration(seconds: 5));
    status = status.copyWith(adServiceInitialized: true);
    debugPrint('✅ AdService Initialized');
  } catch (e) {
    debugPrint('⚠️ AdService init failed: $e');
  }

  AppRuntimeState.instance.updateBootstrapStatus(status);
  runApp(const PrivacyMedsApp());
}

class PrivacyMedsApp extends StatelessWidget {
  const PrivacyMedsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider(create: (_) => SnoozeProvider()..initialize()),
        ChangeNotifierProvider.value(value: SettingsService.instance),

        // ProxyProvider to inject SubscriptionProvider into MedicineProvider
        // ProxyProvider to inject SubscriptionProvider into MedicineProvider
        ChangeNotifierProxyProvider<SubscriptionProvider, MedicineProvider>(
          create: (context) => MedicineProvider()..loadMedicines(),
          update: (context, subscription, medicineProvider) =>
              (medicineProvider ?? MedicineProvider())
                ..updateSubscription(subscription),
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'MedTime - Pill Reminder',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const SplashScreen(),
            builder: (context, child) {
              return NotificationHandler(child: child!);
            },
          );
        },
      ),
    );
  }
}
