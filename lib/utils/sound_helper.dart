import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';

/// Utility class for audio feedback using system sounds
class SoundHelper {
  /// Play a standard click/tap sound
  static Future<void> playClick() async {
    if (SettingsService.instance.soundEnabled) {
      debugPrint('Playing system click sound');
      await SystemSound.play(SystemSoundType.click);
    } else {
      debugPrint('Sound is disabled in settings');
    }
  }

  /// Play a success-like sound (if available via system sound)
  static Future<void> playSuccess() async {
    if (SettingsService.instance.soundEnabled) {
      debugPrint('Playing success sound (click)');
      await SystemSound.play(SystemSoundType.click);
    }
  }

  /// Play an alert/warning sound
  static Future<void> playAlert() async {
    if (SettingsService.instance.soundEnabled) {
      debugPrint('Playing alert sound');
      await SystemSound.play(SystemSoundType.alert);
    }
  }
}
