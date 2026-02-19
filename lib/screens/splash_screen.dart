import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/settings_service.dart';
import '../services/notification_service.dart'; // Keep if used (though mainly used in ScheduleProvider)
import '../providers/medicine_provider.dart';
import '../providers/schedule_provider.dart';
import 'main_screen.dart';
import 'onboarding_screen.dart';
import '../widgets/mesh_gradient_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    // Floating effect (up and down)
    _floatAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    // Breathing effect (slight scale)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    // Initial fade in
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

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

        final medicineProvider = Provider.of<MedicineProvider>(
          context,
          listen: false,
        );
        final scheduleProvider = Provider.of<ScheduleProvider>(
          context,
          listen: false,
        );

        // Ensure fresh data
        await medicineProvider.loadMedicines();
        await scheduleProvider.loadSchedules();

        // Reschedule all notifications
        if (medicineProvider.medicines.isNotEmpty) {
          await scheduleProvider.rescheduleAllNotifications(
            medicineProvider.medicines,
          );
          debugPrint('✅ Self-Healing complete: All notifications rescheduled');
        } else {
          debugPrint('ℹ️ No medicines to reschedule');
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

    Navigator.of(context).pushReplacement(
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
    return Scaffold(
      body: MeshGradientBackground(
        colors: const [
          Color(0xFF020617), // Deep Slate/Black
          Color(0xFF1E293B), // Slate 800
          Color(0xFF4F46E5), // Indigo 600
          Color(0xFF6366F1), // Indigo 500
        ],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatAnimation.value),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 3D Icon Container with Shimmer
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withOpacity(0.3),
                                  blurRadius: 40,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: Stack(
                                children: [
                                  Image.asset(
                                    'assets/images/splash_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                  // Shimmering reflection
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, child) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white.withOpacity(0.0),
                                                Colors.white.withOpacity(0.2),
                                                Colors.white.withOpacity(0.0),
                                              ],
                                              stops: [
                                                0.0,
                                                _controller.value,
                                                1.0,
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 60),
              // Premium Typography
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 1),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Text(
                      'MedTime',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SMART • SECURE • PRIVATE',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
