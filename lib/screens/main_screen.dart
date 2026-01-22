import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/glass_bottom_nav.dart';
import 'dashboard_screen.dart';
import 'cabinet_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../utils/haptic_helper.dart';

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
    
    // Set system UI overlay style usually handled by main/theme, 
    // but good to reinforce here since we draw behind nav
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return Scaffold(
      extendBody: true, // Key: Allows body to draw behind the Bottom Nav
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
