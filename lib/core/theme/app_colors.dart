import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand
  // Primary Brand - Modern Indigo/Violet
  static const Color primary = Color(0xFF6366F1); // Indigo 500
  static const Color primaryDark = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFF818CF8); // Indigo 400
  
  // Action Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color info = Color(0xFF3B82F6); // Blue 500
  
  // Medicine Status - Softer pastel tones for UI
  static const Color taken = Color(0xFF34D399); // Emerald 400
  static const Color pending = Color(0xFF60A5FA); // Blue 400
  static const Color overdue = Color(0xFFF87171); // Red 400
  static const Color skipped = Color(0xFF9CA3AF); // Gray 400
  
  // Surface Colors (Light Mode)
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surface1Light = Color(0xFFF8FAFC); // Slate 50
  static const Color surface2Light = Color(0xFFF1F5F9); // Slate 100
  static const Color surface3Light = Color(0xFFE2E8F0); // Slate 200
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  
  // Surface Colors (Dark Mode)
  static const Color surfaceDark = Color(0xFF0F172A); // Slate 900
  static const Color surface1Dark = Color(0xFF1E293B); // Slate 800
  static const Color surface2Dark = Color(0xFF334155); // Slate 700
  static const Color surface3Dark = Color(0xFF475569); // Slate 600
  static const Color backgroundDark = Color(0xFF020617); // Slate 950
  
  // Text Colors (Light Mode)
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color textDisabledLight = Color(0xFF94A3B8); // Slate 400
  
  // Text Colors (Dark Mode)
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textDisabledDark = Color(0xFF64748B); // Slate 500
  
  // Border Colors
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color borderDark = Color(0xFF1E293B); // Slate 800
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradientLight = LinearGradient(
    colors: [Colors.white, Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient surfaceGradientDark = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Medicine Colors (for color picker)
  static const List<Color> medicineColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFFEF4444), // Red
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFFF43F5E), // Rose
  ];
}
