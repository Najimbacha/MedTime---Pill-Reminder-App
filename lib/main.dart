import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For PlatformDispatcher
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/medicine_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/log_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/sync_provider.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/streak_service.dart';
import 'providers/subscription_provider.dart';
import 'providers/statistics_provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/notification_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App Starting...');

  try {
    // Initialize Firebase
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('⚠️ Firebase init timed out - continuing without cloud features');
        throw TimeoutException('Firebase init timed out');
      },
    );
    debugPrint('✅ Firebase Initialized');
    
    // Initialize Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    debugPrint('📊 Crashlytics Initialized');

    // Initialize services
    debugPrint('🔔 Initializing NotificationService...');
    await NotificationService.instance.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint('⚠️ NotificationService init timed out'),
    );
    debugPrint('✅ NotificationService Initialized');

    debugPrint('⚙️ Initializing SettingsService...');
    await SettingsService.instance.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () => debugPrint('⚠️ SettingsService init timed out'),
    );
    debugPrint('✅ SettingsService Initialized');

    debugPrint('🏆 Initializing StreakService...');
    await StreakService.instance.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () => debugPrint('⚠️ StreakService init timed out'),
    );
    debugPrint('✅ StreakService Initialized');

    runApp(const PrivacyMedsApp());
  } catch (e, stack) {
    debugPrint('🔴 Application Init Error: $e');
    debugPrint(stack.toString());
    // Run app anyway - Firebase features will be unavailable
    runApp(const PrivacyMedsApp());
  }
}

/// Custom timeout exception
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}

class PrivacyMedsApp extends StatelessWidget {
  const PrivacyMedsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MedicineProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider.value(value: SettingsService.instance),
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
