import 'package:flutter/services.dart';

/// Whether a runtime permission is currently usable.
///
/// * [granted] — the user already granted the permission.
/// * [denied] — the user denied it (or it was never requested). Android
///   reports a single "denied" state for both "ask again" and "never ask",
///   so the UI offers a button to open the settings screen.
/// * [unavailable] — the platform cannot check/request this permission
///   (e.g. desktop, or Android versions where the permission does not exist).
enum PermissionGrant { granted, denied, unavailable }

/// Contract for the runtime permissions the Kay interface surfaces.
///
/// Kept abstract so widget tests can inject deterministic fakes without
/// touching platform channels.
abstract class AppPermissions {
  Future<PermissionGrant> microphoneStatus();
  Future<PermissionGrant> notificationStatus();
  Future<void> requestMicrophone();
  Future<void> requestNotifications();
  Future<void> openAppSettings();
  Future<void> openNotificationSettings();
}

/// Android implementation backed by the `kay/permissions` MethodChannel.
class DeviceAppPermissions implements AppPermissions {
  static const _channel = MethodChannel('kay/permissions');

  @override
  Future<PermissionGrant> microphoneStatus() async =>
      _status('microphone');

  @override
  Future<PermissionGrant> notificationStatus() async =>
      _status('notifications');

  Future<PermissionGrant> _status(String kind) async {
    try {
      final raw = await _channel.invokeMethod<String>(kind);
      return switch (raw) {
        'granted' => PermissionGrant.granted,
        'denied' => PermissionGrant.denied,
        _ => PermissionGrant.unavailable,
      };
    } on MissingPluginException {
      return PermissionGrant.unavailable;
    }
  }

  @override
  Future<void> requestMicrophone() => _request('requestMicrophone');

  @override
  Future<void> requestNotifications() => _request('requestNotifications');

  Future<void> _request(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      /* Android only. */
    } on PlatformException {
      /* Request rejected by the system. */
    }
  }

  @override
  Future<void> openAppSettings() => _open('openAppSettings');

  @override
  Future<void> openNotificationSettings() => _open('openNotificationSettings');

  Future<void> _open(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      /* Android only. */
    } on PlatformException {
      /* Settings screen could not be opened. */
    }
  }
}