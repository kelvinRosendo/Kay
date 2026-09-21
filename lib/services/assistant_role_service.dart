import 'package:flutter/services.dart';

enum AssistantRoleStatus { unknown, unavailable, notHeld, held }

class AssistantRoleService {
  static const _channel = MethodChannel('kay/assistant_role');

  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> isHeld() async {
    try {
      return await _channel.invokeMethod<bool>('isHeld') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> requestRole() async {
    try {
      return await _channel.invokeMethod<bool>('requestRole') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openAssistantSettings() async {
    try {
      await _channel.invokeMethod<void>('openAssistantSettings');
    } on MissingPluginException {
      /* Android only. */
    }
  }

  Future<AssistantRoleStatus> getStatus() async {
    if (!await isAvailable()) return AssistantRoleStatus.unavailable;
    if (await isHeld()) return AssistantRoleStatus.held;
    return AssistantRoleStatus.notHeld;
  }
}
