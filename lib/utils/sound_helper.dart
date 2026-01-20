import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';

/// Utility class for audio feedback using system sounds
/// Uses SystemSound for reliable cross-device compatibility
class SoundHelper {
  
  static Future<void> playClick() async {
    if (!SettingsService.instance.soundEnabled) return;
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('SoundHelper: click failed: $e');
    }
  }

  static Future<void> playSuccess() async {
    if (!SettingsService.instance.soundEnabled) return;
    try {
      // Play click sound as success indicator (system sound)
      await SystemSound.play(SystemSoundType.click);
      // Add a small delay and play again for emphasis
      await Future.delayed(const Duration(milliseconds: 100));
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('SoundHelper: success failed: $e');
    }
  }

  static Future<void> playAlert() async {
    if (!SettingsService.instance.soundEnabled) return;
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('SoundHelper: alert failed: $e');
    }
  }

  static Future<void> dispose() async {
    // Nothing to dispose for system sounds
  }
}
