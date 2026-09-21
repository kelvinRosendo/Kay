import 'package:flutter/services.dart';

/// Aggregate of system bits shown on the Status tab.
class SystemStatusService {
  static const _channel = MethodChannel('kay/background');

  /// Whether the native foreground service is currently running and armed.
  Future<bool> isBackgroundRunning() async {
    try {
      return await _channel.invokeMethod<bool>('is_running') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Whether the Vosk wake-word model is loaded in the service.
  Future<bool> isVoskReady() async {
    try {
      return await _channel.invokeMethod<bool>('vosk_ready') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Whether the Android voice interaction service is the active assistant.
  Future<bool> isVoiceServiceActive() async {
    try {
      return await _channel.invokeMethod<bool>('voice_service_active') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Applies the configured wait/silence windows to the native background
  /// recognizer and cancels any stale timers on changed values.
  Future<void> setWaits({
    required int waitMs,
    required int silenceMs,
  }) async {
    try {
      await _channel.invokeMethod<void>('set_waits', {
        'wait_ms': waitMs,
        'silence_ms': silenceMs,
      });
    } on MissingPluginException {
      /* Android only. */
    } on PlatformException {
      /* Ignore: values apply on the next recognition window. */
    }
  }
}