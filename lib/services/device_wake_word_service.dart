import 'package:flutter/services.dart';

import 'wake_word_service.dart';

class DeviceWakeWordService implements WakeWordService {
  static const _background = MethodChannel('kay/background');
  static const _events = MethodChannel('kay/service_events');
  int _generation = 0;

  @override
  Future<void> start({
    required void Function() onDetected,
    required void Function() onError,
  }) async {
    final generation = ++_generation;
    _events.setMethodCallHandler((call) async {
      if (generation != _generation) return;
      if (call.method == 'wake_detected') onDetected();
      if (call.method == 'error') onError();
    });
    await _background.invokeMethod<void>('start');
  }

  @override
  Future<void> stop() async {
    ++_generation;
    _events.setMethodCallHandler(null);
    await _background.invokeMethod<void>('pause_wake');
  }

  @override
  Future<void> dispose() async {
    ++_generation;
    _events.setMethodCallHandler(null);
    try {
      await _background.invokeMethod<void>('stop');
    } on MissingPluginException {
      /* Android only. */
    }
  }

  Future<void> stopService() async {
    ++_generation;
    _events.setMethodCallHandler(null);
    try {
      await _background.invokeMethod<void>('stop');
    } on MissingPluginException {
      /* Android only. */
    }
  }
}
