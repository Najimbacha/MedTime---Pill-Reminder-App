import 'package:flutter/services.dart';
import '../services/settings_service.dart';

/// Utility class for haptic feedback
class HapticHelper {
  /// Provide light haptic feedback
  static Future<void> light() async {
    if (SettingsService.instance.hapticFeedbackEnabled) {
      await HapticFeedback.lightImpact();
    }
  }
  
  /// Provide medium haptic feedback
  static Future<void> medium() async {
    if (SettingsService.instance.hapticFeedbackEnabled) {
      await HapticFeedback.mediumImpact();
    }
  }
  
  /// Provide heavy haptic feedback
  static Future<void> heavy() async {
    if (SettingsService.instance.hapticFeedbackEnabled) {
      await HapticFeedback.heavyImpact();
    }
  }
  
  /// Provide selection haptic feedback
  static Future<void> selection() async {
    if (SettingsService.instance.hapticFeedbackEnabled) {
      await HapticFeedback.selectionClick();
    }
  }
  
  /// Provide vibrate feedback
  static Future<void> vibrate() async {
    if (SettingsService.instance.hapticFeedbackEnabled) {
      await HapticFeedback.vibrate();
    }
  }
  
  /// Success feedback (medium impact)
  static Future<void> success() async {
    await medium();
  }
  
  /// Error feedback (heavy impact)
  static Future<void> error() async {
    await heavy();
  }
  
  /// Warning feedback (light impact)
  static Future<void> warning() async {
    await light();
  }
}
