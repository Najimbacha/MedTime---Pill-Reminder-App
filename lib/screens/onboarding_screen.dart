import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import 'main_screen.dart';
import '../widgets/mesh_gradient_background.dart';
import '../widgets/glass_container.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Smart medication\ntracking.',
      description:
          'Your health, your data. Offline-first medication reminders with zero friction.',
      colors: [
        const Color(0xFF020617), // Black
        const Color(0xFF1E293B), // Slate 800
        const Color(0xFF4F46E5), // Indigo 600
        const Color(0xFF6366F1), // Indigo 500
      ],
      icon: Icons.security_rounded,
    ),
    OnboardingPage(
      title: 'Built with\nintelligence.',
      description:
          'Interaction warnings, refill predictions, and precise scheduling at your fingertips.',
      colors: [
        const Color(0xFF020617), // Black
        const Color(0xFF1E293B), // Slate 800
        const Color(0xFF8B5CF6), // Violet 600
        const Color(0xFF7C3AED), // Violet 500
      ],
      icon: Icons.auto_awesome_rounded,
    ),
    OnboardingPage(
      title: 'Sync with\nyour family.',
      description:
          'Share adherence data securely with loved ones. Keep them in the loop, real-time.',
      colors: [
        const Color(0xFF020617), // Black
        const Color(0xFF1E293B), // Slate 800
        const Color(0xFFDB2777), // Pink 600
        const Color(0xFFBE185D), // Pink 700
      ],
      icon: Icons.favorite_rounded,
    ),
    OnboardingPage(
      title: 'Beautifully\ndesigned.',
      description:
          'Modern UI with glassmorphic cards, mesh gradients, and smooth transitions.',
      colors: [
        const Color(0xFF020617), // Black
        const Color(0xFF1E293B), // Slate 800
        const Color(0xFFEA580C), // Orange 600
        const Color(0xFFF97316), // Orange 500
      ],
      icon: Icons.palette_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Morphing Background
          MeshGradientBackground(
            duration: const Duration(seconds: 15),
            colors: _pages[_currentPage].colors,
            child: const SizedBox.expand(),
          ),

          // Content
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glass Card
                    GlassContainer(
                      padding: const EdgeInsets.all(32),
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              page.icon,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            page.title,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                  letterSpacing: -1,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            page.description,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 18,
                                  height: 1.5,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Controls
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Page Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Buttons
                Row(
                  children: [
                    if (_currentPage < _pages.length - 1)
                      Expanded(
                        child: TextButton(
                          onPressed: () => _completeOnboarding(context),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage < _pages.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutQuart,
                              );
                            } else {
                              _completeOnboarding(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Continue',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOnboarding(BuildContext context) async {
    // Request notification permissions before completing onboarding
    final notificationService = NotificationService.instance;
    await notificationService.requestAllPermissions();

    // Mark onboarding as completed
    if (context.mounted) {
      context.read<SettingsService>().setOnboardingCompleted(true);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final List<Color> colors;
  final IconData icon;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.colors,
    required this.icon,
  });
}
