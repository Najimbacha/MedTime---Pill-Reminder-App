import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../providers/routine_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/log_provider.dart';
import 'main_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // M3 Staggered Animations
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Run initialization tasks in parallel with the minimum splash duration
    final minSplashDuration = Future.delayed(const Duration(seconds: 3));

    // Healing Logic: Ensure all alarms are scheduled correctly
    final initializationTask = Future(() async {
      try {
        if (!mounted) return;
        debugPrint('🔄 Starting Self-Healing process...');

        final settings = Provider.of<SettingsService>(context, listen: false);
        final routineProvider = Provider.of<RoutineProvider>(
          context,
          listen: false,
        );
        final scheduleProvider = Provider.of<ScheduleProvider>(
          context,
          listen: false,
        );
        final logProvider = Provider.of<LogProvider>(context, listen: false);
        await settings.ensureInitialized();

        // Ensure fresh data
        await Future.wait([
          routineProvider.loadRoutines(),
          scheduleProvider.loadSchedules(),
          logProvider.loadLogs(),
        ]);

        // Reschedule all notifications
        if (routineProvider.routines.isNotEmpty) {
          await scheduleProvider.rescheduleAllNotifications(
            routineProvider.routines,
          );
          debugPrint('✅ Self-Healing complete: All notifications rescheduled');
        } else {
          debugPrint('No routines to reschedule');
        }
      } catch (e) {
        debugPrint('⚠️ Self-Healing failed: $e');
        // Non-critical failure, app can still start
      }
    });

    // Wait for both timer and init (whichever is longer, but usually timer)
    await Future.wait([minSplashDuration, initializationTask]);

    if (!mounted) return;

    final settings = Provider.of<SettingsService>(context, listen: false);
    final navigator = Navigator.of(context);
    try {
      await settings.ensureInitialized();
    } catch (e) {
      debugPrint('⚠️ Settings initialization failed in splash route: $e');
    }

    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => settings.onboardingCompleted
            ? const MainScreen()
            : const OnboardingScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Icon
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: FadeTransition(
                    opacity: _scaleAnimation,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.15),
                            blurRadius: 30,
                            spreadRadius: 8,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: Hero(
                          tag: 'splash_icon',
                          child: Image.asset(
                            'assets/images/splash_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Animated Typography
                FadeTransition(
                  opacity: _opacityAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        Text(
                          'RoutineTime',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Simple recurring reminders',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            strokeCap: StrokeCap.round,
                            color: colorScheme.primary,
                            backgroundColor: colorScheme.surfaceContainerHigh,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
