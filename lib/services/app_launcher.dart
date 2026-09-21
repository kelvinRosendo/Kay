import 'package:flutter/services.dart';

import 'command_router.dart';

enum LaunchResult { opened, unavailable, unsupported, failed }

abstract class AppLauncher {
  Future<LaunchResult> open(LocalCommand command);
}

class DeviceAppLauncher implements AppLauncher {
  static const _channel = MethodChannel('kay/local_commands');
  @override
  Future<LaunchResult> open(LocalCommand command) async {
    try {
      final result = await _channel.invokeMethod<String>('open', command.name);
      return switch (result) {
        'opened' => LaunchResult.opened,
        'unavailable' => LaunchResult.unavailable,
        _ => LaunchResult.failed,
      };
    } on MissingPluginException {
      return LaunchResult.unsupported;
    } on PlatformException {
      return LaunchResult.failed;
    }
  }
}
