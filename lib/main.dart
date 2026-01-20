import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/medicine_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/log_provider.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/notification_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App Starting...');

  try {
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

    runApp(const PrivacyMedsApp());
  } catch (e, stack) {
    debugPrint('🔴 Application Init Error: $e');
    debugPrint(stack.toString());
  }
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
