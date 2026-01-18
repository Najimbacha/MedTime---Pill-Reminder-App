import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);
  
  // Action Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF29B6F6);
  
  // Medicine Status
  static const Color taken = Color(0xFF66BB6A);
  static const Color pending = Color(0xFF42A5F5);
  static const Color overdue = Color(0xFFEF5350);
  static const Color skipped = Color(0xFF9E9E9E);
  
  // Surface Colors (Light Mode)
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surface1Light = Color(0xFFF5F5F5);
  static const Color surface2Light = Color(0xFFEEEEEE);
  static const Color surface3Light = Color(0xFFE0E0E0);
  static const Color backgroundLight = Color(0xFFFAFAFA);
  
  // Surface Colors (Dark Mode)
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surface1Dark = Color(0xFF2C2C2C);
  static const Color surface2Dark = Color(0xFF3A3A3A);
  static const Color surface3Dark = Color(0xFF484848);
  static const Color backgroundDark = Color(0xFF121212);
  
  // Text Colors (Light Mode)
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textDisabledLight = Color(0xFFBDBDBD);
  
  // Text Colors (Dark Mode)
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textDisabledDark = Color(0xFF6E6E6E);
  
  // Border Colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF3A3A3A);
  
  // Medicine Colors (for color picker)
  static const List<Color> medicineColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFFEF5350), // Red
    Color(0xFF66BB6A), // Green
    Color(0xFFFFA726), // Orange
    Color(0xFFAB47BC), // Purple
    Color(0xFF26C6DA), // Cyan
    Color(0xFFFFEE58), // Yellow
    Color(0xFFEC407A), // Pink
  ];
}
