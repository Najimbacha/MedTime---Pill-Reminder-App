import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/caregiver.dart';

/// Service for managing app settings and preferences
class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._init();
  
  SharedPreferences? _prefs;
  
  // Settings keys
  static const String _themeModeKey = 'theme_mode';
  static const String _hapticFeedbackKey = 'haptic_feedback';
  static const String _soundEnabledKey = 'sound_enabled';
  static String get _lowStockThresholdKey => 'low_stock_threshold';
  static String get _onboardingCompletedKey => 'onboarding_complete';
  static String get _caregiverKey => 'caregiver';
  
  // Default values
  ThemeMode _themeMode = ThemeMode.system;
  bool _hapticFeedbackEnabled = true;
  bool _soundEnabled = true;
  int _lowStockThreshold = 7;
  bool _onboardingCompleted = false;
  Caregiver? _caregiver;
  
  SettingsService._init();
  
  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;
  bool get soundEnabled => _soundEnabled;
  int get lowStockThreshold => _lowStockThreshold;
  bool get onboardingCompleted => _onboardingCompleted;
  Caregiver? get caregiver => _caregiver;
  
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;
  bool get isLightMode => _themeMode == ThemeMode.light;
  
  /// Initialize settings service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
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
    _soundEnabled = _prefs!.getBool(_soundEnabledKey) ?? true;
    _lowStockThreshold = _prefs!.getInt(_lowStockThresholdKey) ?? 7;
    _onboardingCompleted = _prefs!.getBool(_onboardingCompletedKey) ?? false;
    
    // Load caregiver
    final caregiverJson = _prefs!.getString(_caregiverKey);
    if (caregiverJson != null) {
      try {
        _caregiver = Caregiver.fromJson(caregiverJson);
      } catch (e) {
        debugPrint('Error loading caregiver: $e');
      }
    }
    
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
  
  /// Set sound enabled
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _prefs?.setBool(_soundEnabledKey, enabled);
    notifyListeners();
  }
  
  /// Set low stock threshold
  Future<void> setLowStockThreshold(int threshold) async {
    _lowStockThreshold = threshold;
    await _prefs?.setInt(_lowStockThresholdKey, threshold);
    notifyListeners();
  }
  
  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await setThemeMode(ThemeMode.system);
    await setHapticFeedback(true);
    await setSoundEnabled(true);
    await setLowStockThreshold(7);
    await setOnboardingCompleted(false);
  }

  /// Complete onboarding
  Future<void> setOnboardingCompleted(bool completed) async {
    _onboardingCompleted = completed;
    await _prefs?.setBool(_onboardingCompletedKey, completed);
    notifyListeners();
  }

  /// Save caregiver settings
  Future<void> saveCaregiver(Caregiver caregiver) async {
    _caregiver = caregiver;
    await _prefs?.setString(_caregiverKey, caregiver.toJson());
    notifyListeners();
  }

  /// Delete caregiver
  Future<void> deleteCaregiver() async {
    _caregiver = null;
    await _prefs?.remove(_caregiverKey);
    notifyListeners();
  }
}
