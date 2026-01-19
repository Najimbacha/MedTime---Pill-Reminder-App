import 'package:audioplayers/audioplayers.dart';
import '../services/settings_service.dart';

/// Utility class for audio feedback using bundled assets
class SoundHelper {
  static final AudioPlayer _clickPlayer = AudioPlayer(playerId: 'click_player');
  static final AudioPlayer _successPlayer = AudioPlayer(
    playerId: 'success_player',
  );
  static final AudioPlayer _alertPlayer = AudioPlayer(playerId: 'alert_player');

  static Future<void> _playAsset(AudioPlayer player, AssetSource source) async {
    if (!SettingsService.instance.soundEnabled) return;
    try {
      await player.play(source);
    } catch (_) {
      // ignore failures; sound is optional
    }
  }

  static Future<void> playClick() async {
    await _playAsset(_clickPlayer, AssetSource('sounds/click.mp3'));
  }

  static Future<void> playSuccess() async {
    await _playAsset(_successPlayer, AssetSource('sounds/success.mp3'));
  }

  static Future<void> playAlert() async {
    await _playAsset(_alertPlayer, AssetSource('sounds/alert.mp3'));
  }
}
