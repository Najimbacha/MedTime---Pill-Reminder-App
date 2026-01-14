import 'package:flutter/material.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // Color Palette (Deep Navy System)
  // ---------------------------------------------------------------------------
  
  // Primary Backgrounds
  static const Color navyPrimary = Color(0xFF0D1B2A); // Deepest Navy (Background)
  static const Color navySurface = Color(0xFF1B263B); // Lighter Navy (Cards/Surface)
  static const Color navyLight = Color(0xFF415A77);   // Muted Blue (Secondary)
  
  // Accents & Functionals
  static const Color accentTeal = Color(0xFF00B4D8);  // Cyan/Teal Highlight
  static const Color textLight = Color(0xFFE0E1DD);   // Off-white text on Dark
  static const Color textDark = Color(0xFF0D1B2A);    // Dark Blue text on Light
  
  // Light Mode Equivalents
  static const Color lightBackground = Color(0xFFF0F4F8);
  static const Color lightSurface = Colors.white;
  static const Color lightTextBody = Color(0xFF4A5568);

  // Status Colors
  static const Color error = Color(0xFFEF5350);
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFA726);

  // ---------------------------------------------------------------------------
  // Text Styles (Roboto / Clean )
  // ---------------------------------------------------------------------------
  
  static const TextTheme _lightTextTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textDark),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark),
    displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textDark),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: lightTextBody),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: lightTextBody),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white), // Button text
  );

  static const TextTheme _darkTextTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textLight),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textLight),
    displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textLight),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textLight),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textLight),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Color(0xFFB0B8C1)),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFB0B8C1)),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark), // Button text (on accent)
  );

  // ---------------------------------------------------------------------------
  // Theme Data Builders
  // ---------------------------------------------------------------------------

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: navyPrimary,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: navyPrimary,
        secondary: accentTeal,
        surface: lightSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
      ),
      
      // Typography
      textTheme: _lightTextTheme,
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0, // Flat style with border preference or subtle shadow managed manually
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.grey.withAlpha(20), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navyPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: navyPrimary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: navyPrimary,
        ),
      ),
      
      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withAlpha(30)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: navyPrimary, width: 2),
        ),
        labelStyle: const TextStyle(color: navyLight),
      ),

      // Page Transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: navyPrimary,
      scaffoldBackgroundColor: navyPrimary,
      colorScheme: const ColorScheme.dark(
        primary: accentTeal,    // Accent is primary in dark mode for contrast
        secondary: navyLight,
        surface: navySurface,
        error: error,
        onPrimary: navyPrimary, // Text on accent
        onSecondary: textLight,
        onSurface: textLight,
      ),
      
      // Typography
      textTheme: _darkTextTheme,
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textLight),
        titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textLight),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: navySurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withAlpha(13), width: 1), // Subtle border
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentTeal,
          foregroundColor: navyPrimary, // Dark text on bright button
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: accentTeal, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: accentTeal,
        ),
      ),
      
      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: navySurface,
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withAlpha(13)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentTeal, width: 2),
        ),
        labelStyle: TextStyle(color: textLight.withAlpha(179)),
      ),

      // Page Transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
