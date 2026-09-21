import 'package:flutter/services.dart';

/// Reads and persists the currently selected voice name.
///
/// The voice string lives natively (SharedPreferences `kay_voice`) because
/// both the Dart TTS path and the native foreground service apply it. This
/// wrapper keeps the platform channel in one place.
class VoiceSelectionService {
  static const _channel = MethodChannel('kay/voice');

  Future<String?> current() async {
    try {
      return await _channel.invokeMethod<String>('get');
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> select(String name) async {
    try {
      await _channel.invokeMethod<void>('set', {'name': name});
    } on MissingPluginException {
      /* Voice persistence is Android only. */
    }
  }
}