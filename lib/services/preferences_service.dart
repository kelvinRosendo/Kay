import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Typed, observable preferences store backed by SharedPreferences.
///
/// All fields are synchronously available after [init] completes.
/// Callers can listen to [addListener] for any changes.
class PreferencesService extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool _initialized = false;
  bool get initialized => _initialized;

  // ── Keys ──────────────────────────────────────────────────────
  static const _kTextScale = 'kay_text_scale'; // small=0, medium=1, large=2
  static const _kUserName = 'kay_user_name';
  static const _kUseNameInReplies = 'kay_use_name_in_replies';
  static const _kWaitSeconds = 'kay_wait_seconds';
  static const _kSilenceSeconds = 'kay_silence_seconds';
  static const _kVoiceName = 'kay_voice_name';
  static const _kAiUrl = 'kay_ai_url';
  static const _kAiModel = 'kay_ai_model';
  static const _kWakeEnabled = 'kay_wake_enabled';

  // ── Defaults ──────────────────────────────────────────────────
  static const defaultTextScale = 1; // medium
  static const defaultUserName = '';
  static const defaultUseNameInReplies = false;
  static const defaultWaitSeconds = 10;
  static const defaultSilenceSeconds = 5;
  static const defaultAiUrl = 'http://192.168.15.16:11434';
  static const defaultAiModel = 'llama3.2:3b';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    notifyListeners();
  }

  SharedPreferences get _p {
    assert(_initialized, 'PreferencesService not initialized');
    return _prefs!;
  }

  // ── Text scale ────────────────────────────────────────────────
  int get textScale => _p.getInt(_kTextScale) ?? defaultTextScale;
  set textScale(int v) {
    _p.setInt(_kTextScale, v);
    notifyListeners();
  }

  // ── User name ─────────────────────────────────────────────────
  String get userName => _p.getString(_kUserName) ?? defaultUserName;
  set userName(String v) {
    if (v.length > 64) v = v.substring(0, 64);
    _p.setString(_kUserName, v);
    notifyListeners();
  }

  /// Whether Kay may personalize replies with the user name.
  bool get useNameInReplies =>
      _p.getBool(_kUseNameInReplies) ?? defaultUseNameInReplies;
  set useNameInReplies(bool v) {
    _p.setBool(_kUseNameInReplies, v);
    notifyListeners();
  }

  // ── Wait seconds (before first silence warning) ──────────────
  int get waitSeconds => _p.getInt(_kWaitSeconds) ?? defaultWaitSeconds;
  set waitSeconds(int v) {
    if (v < 10) v = 10;
    if (v > 30) v = 30;
    _p.setInt(_kWaitSeconds, v);
    notifyListeners();
  }

  // ── Silence seconds (after warning) ──────────────────────────
  int get silenceSeconds =>
      _p.getInt(_kSilenceSeconds) ?? defaultSilenceSeconds;
  set silenceSeconds(int v) {
    if (v < 3) v = 3;
    if (v > 15) v = 15;
    _p.setInt(_kSilenceSeconds, v);
    notifyListeners();
  }

  // ── Voice ─────────────────────────────────────────────────────
  String get voiceName => _p.getString(_kVoiceName) ?? '';
  set voiceName(String v) {
    _p.setString(_kVoiceName, v);
    notifyListeners();
  }

  // ── AI URL ────────────────────────────────────────────────────
  String get aiUrl => _p.getString(_kAiUrl) ?? defaultAiUrl;
  set aiUrl(String v) {
    _p.setString(_kAiUrl, v);
    notifyListeners();
  }

  // ── AI Model ──────────────────────────────────────────────────
  String get aiModel => _p.getString(_kAiModel) ?? defaultAiModel;
  set aiModel(String v) {
    _p.setString(_kAiModel, v);
    notifyListeners();
  }

  // ── Wake enabled ─────────────────────────────────────────────
  bool get wakeEnabled => _p.getBool(_kWakeEnabled) ?? false;
  set wakeEnabled(bool v) {
    _p.setBool(_kWakeEnabled, v);
    notifyListeners();
  }

  // ── Text scale factor ────────────────────────────────────────
  double get textScaleFactor => switch (textScale) {
        0 => 0.85,
        1 => 1.0,
        2 => 1.25,
        _ => 1.0,
      };

  String get textScaleLabel => switch (textScale) {
        0 => 'Pequeno',
        1 => 'Médio',
        2 => 'Grande',
        _ => 'Médio',
      };

  // ── Reset ─────────────────────────────────────────────────────
  Future<void> resetToDefaults() async {
    await _p.remove(_kTextScale);
    await _p.remove(_kUserName);
    await _p.remove(_kUseNameInReplies);
    await _p.remove(_kWaitSeconds);
    await _p.remove(_kSilenceSeconds);
    await _p.remove(_kVoiceName);
    await _p.remove(_kAiUrl);
    await _p.remove(_kAiModel);
    await _p.remove(_kWakeEnabled);
    notifyListeners();
  }
}
