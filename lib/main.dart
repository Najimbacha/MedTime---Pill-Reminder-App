import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/log_provider.dart';
import 'providers/routine_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/snooze_provider.dart';
import 'screens/splash_screen.dart';
import 'services/app_runtime_state.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
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

  AppRuntimeState.instance.updateBootstrapStatus(status);
  runApp(const RoutineTimeApp());
}

class RoutineTimeApp extends StatelessWidget {
  const RoutineTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProvider(create: (_) => SnoozeProvider()..initialize()),
        ChangeNotifierProvider.value(value: SettingsService.instance),
        ChangeNotifierProvider(
          create: (_) => RoutineProvider()..loadRoutines(),
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'RoutineTime',
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
