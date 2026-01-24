import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/glass_bottom_nav.dart';
import 'dashboard_screen.dart';
import 'cabinet_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../utils/haptic_helper.dart';
import '../core/theme/app_colors.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // Keep tabs alive
  final List<Widget> _screens = const [
    DashboardScreen(),
    CabinetScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    // Clear any lingering SnackBars when switching tabs so messages don't stick across screens.
    ScaffoldMessenger.of(context).clearSnackBars();
    
    HapticHelper.selection();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return Scaffold(
      extendBody: true,
      body: Container(
        color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: _screens[_currentIndex],
          ),
        ),
      ),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
