import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/notification_service.dart';
import 'dashboard_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeBackgroundServices());
    });
  }

  Future<void> _initializeBackgroundServices() async {
    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return const DashboardScreen();
  }
}
