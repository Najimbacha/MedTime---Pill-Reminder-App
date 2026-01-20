import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
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
    // Simple basic timer - no fancy logic temporarily
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final settings = Provider.of<SettingsService>(context, listen: false);
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => settings.onboardingCompleted ? const DashboardScreen() : const OnboardingScreen(),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD), // Light Blue
              Colors.white,
            ],
          ),
        ),
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
                          // Dynamic Shadow
                          Transform.translate(
                            offset: const Offset(0, 60), // Below the icon
                            child: Container(
                              width: 100 + (_floatAnimation.value * 1.5), // Shrink when going up
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.1 + (_floatAnimation.value * 0.002)), // Fade when going up
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20 - (_floatAnimation.value * 0.5), // Blur more when going up
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 3D Icon Container
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.2),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: Image.asset(
                                'assets/images/splash_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Shiny Overlay (Simulated Reflection)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                                gradient: LinearGradient(
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                  colors: [
                                    Colors.white.withOpacity(0.4),
                                    Colors.transparent,
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.4, 1.0],
                                ),
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
              // Text Fade In
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
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: const Color(0xFF1976D2),
                        fontWeight: FontWeight.bold,
                        fontSize: 36,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Personal Pill Companion',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 16,
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
