import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings and preferences
class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._init();

  SharedPreferences? _prefs;
  Future<void>? _initializationFuture;
  bool _isInitialized = false;

  // Settings keys
  static const String _themeModeKey = 'theme_mode';
  static const String _hapticFeedbackKey = 'haptic_feedback';
  static String get _onboardingCompletedKey => 'onboarding_complete';

  // Default values
  ThemeMode _themeMode = ThemeMode.system;
  bool _hapticFeedbackEnabled = true;
  bool _onboardingCompleted = false;

  SettingsService._init();

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get isInitialized => _isInitialized;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;
  bool get isLightMode => _themeMode == ThemeMode.light;

  /// Initialize settings service
  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
    _isInitialized = true;
  }

  /// Ensure settings are initialized once and wait on in-flight initialization.
  Future<void> ensureInitialized() {
    if (_isInitialized) return Future.value();
    _initializationFuture ??= initialize();
    return _initializationFuture!;
  }

  /// Publicly accessible reload settings
  Future<void> reloadSettings() async {
    await _loadSettings();
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    // Load theme mode
    final themeModeIndex = _prefs!.getInt(_themeModeKey) ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];

    // Load other settings
    _hapticFeedbackEnabled = _prefs!.getBool(_hapticFeedbackKey) ?? true;
    _onboardingCompleted = _prefs!.getBool(_onboardingCompletedKey) ?? false;

    notifyListeners();
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  /// Toggle dark mode (Cycles through System -> Light -> Dark)
  Future<void> toggleDarkMode() async {
    if (_themeMode == ThemeMode.system) {
      await setThemeMode(ThemeMode.light);
    } else if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.system);
    }
  }

  /// Set haptic feedback
  Future<void> setHapticFeedback(bool enabled) async {
    _hapticFeedbackEnabled = enabled;
    await _prefs?.setBool(_hapticFeedbackKey, enabled);
    notifyListeners();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await setThemeMode(ThemeMode.system);
    await setHapticFeedback(true);
    await setOnboardingCompleted(false);
  }

  /// Complete onboarding
  Future<void> setOnboardingCompleted(bool completed) async {
    _onboardingCompleted = completed;
    await _prefs?.setBool(_onboardingCompletedKey, completed);
    notifyListeners();
  }
}
