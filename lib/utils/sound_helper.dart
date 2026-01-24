import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/settings_service.dart';

/// Utility class for audio feedback using bundled sound assets
/// Uses AudioPlayer for consistent high-quality feedback
class SoundHelper {
  static final AudioPlayer _player = AudioPlayer();
  
  // Cache players for low latency? 
  // AudioCache is deprecated in v6, now AudioPlayer uses AssetSource

  static Future<void> playClick() async {
    if (!SettingsService.instance.soundEnabled) return;
    try {
      if (_player.state == PlayerState.playing) await _player.stop();
      await _player.play(AssetSource('sounds/click.mp3'), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('SoundHelper: click failed: $e');
    }
  }

  static Future<void> playSuccess() async {
    if (!SettingsService.instance.soundEnabled) return;
    try {
       // Stop previous sound to prevent overlap muddiness
      if (_player.state == PlayerState.playing) await _player.stop();
      await _player.play(AssetSource('sounds/success.mp3'), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('SoundHelper: success failed: $e');
    }
  }

  static Future<void> playAlert() async {
    if (!SettingsService.instance.soundEnabled) return;
    try {
      if (_player.state == PlayerState.playing) await _player.stop();
      await _player.play(AssetSource('sounds/alert.mp3'), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('SoundHelper: alert failed: $e');
    }
  }
}
