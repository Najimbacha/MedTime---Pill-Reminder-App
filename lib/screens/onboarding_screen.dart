import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import 'dashboard_screen.dart';

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
      title: 'Welcome to MedTime',
      description: 'Your health, your data. Offline-first medication reminders with zero friction.',
      icon: Icons.security_rounded,
      color: Colors.blue,
    ),
    OnboardingPage(
      title: 'Smart Features',
      description: 'Interact warnings, refill predictions, and AI cabinet scanning at your fingertips.',
      icon: Icons.auto_awesome_rounded,
      color: Colors.purple,
    ),
    OnboardingPage(
      title: 'Beautiful Experience',
      description: 'Modern UI with glassmorphic cards, mesh gradients, and smooth transitions.',
      icon: Icons.palette_rounded,
      color: Colors.orange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
              return Container(
                color: page.color.withAlpha(26),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      page.icon,
                      size: 150,
                      color: page.color,
                    ),
                    const SizedBox(height: 48),
                    Text(
                      page.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: page.color,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      page.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[700],
                            fontSize: 18,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 48,
            left: 32,
            right: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      height: 12,
                      width: _currentPage == index ? 32 : 12,
                      decoration: BoxDecoration(
                        color: _pages[_currentPage].color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _completeOnboarding(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 48,
            right: 24,
            child: TextButton(
              onPressed: () => _completeOnboarding(context),
              child: Text(
                'Skip',
                style: TextStyle(
                  color: _pages[_currentPage].color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _completeOnboarding(BuildContext context) {
    context.read<SettingsService>().setOnboardingCompleted(true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
