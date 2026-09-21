import 'package:flutter/foundation.dart';
import 'package:kay/services/ai_service.dart';
import 'package:kay/services/assistant_role_service.dart';
import 'package:kay/services/conversation_memory.dart';
import 'package:kay/services/permission_service.dart';
import 'package:kay/services/system_status_service.dart';
import 'package:kay/services/wake_word_service.dart';

/// Deterministic permissions double: requests succeed immediately and flip the
/// matching state to granted.
class FakeAppPermissions implements AppPermissions {
  bool micGranted = true;
  bool notifGranted = true;
  int micRequests = 0;
  int notifRequests = 0;
  int openAppSettingsCalls = 0;
  int openNotificationSettingsCalls = 0;

  @override
  Future<PermissionGrant> microphoneStatus() async =>
      micGranted ? PermissionGrant.granted : PermissionGrant.denied;

  @override
  Future<PermissionGrant> notificationStatus() async =>
      notifGranted ? PermissionGrant.granted : PermissionGrant.denied;

  @override
  Future<void> requestMicrophone() async {
    micRequests++;
    micGranted = true;
  }

  @override
  Future<void> requestNotifications() async {
    notifRequests++;
    notifGranted = true;
  }

  @override
  Future<void> openAppSettings() async {
    openAppSettingsCalls++;
  }

  @override
  Future<void> openNotificationSettings() async {
    openNotificationSettingsCalls++;
  }
}

/// System status double that never touches the platform channel.
class FakeSystemStatus implements SystemStatusService {
  bool running = false;
  bool voskReady = false;
  bool voiceServiceActive = false;
  int? lastWaitMs;
  int? lastSilenceMs;

  @override
  Future<bool> isBackgroundRunning() async => running;

  @override
  Future<bool> isVoskReady() async => voskReady;

  @override
  Future<bool> isVoiceServiceActive() async => voiceServiceActive;

  @override
  Future<void> setWaits({required int waitMs, required int silenceMs}) async {
    lastWaitMs = waitMs;
    lastSilenceMs = silenceMs;
  }
}

/// Assistant role double.
class FakeRoleService extends AssistantRoleService {
  AssistantRoleStatus status = AssistantRoleStatus.notHeld;
  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  Future<AssistantRoleStatus> getStatus() async => status;

  @override
  Future<bool> isAvailable() async => status != AssistantRoleStatus.unavailable;

  @override
  Future<bool> isHeld() async => status == AssistantRoleStatus.held;

  @override
  Future<bool> requestRole() async {
    requestCount++;
    return true;
  }

  @override
  Future<void> openAssistantSettings() async {
    openSettingsCount++;
  }
}

/// Wake-word double: never errors and records calls.
class FakeWakeWord implements WakeWordService {
  int startCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  VoidCallback? onDetected;
  VoidCallback? onError;

  @override
  Future<void> start({
    required void Function() onDetected,
    required void Function() onError,
  }) async {
    startCount++;
    this.onDetected = onDetected;
    this.onError = onError;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

/// AI double that records whether the user name reached the model.
class RecordingAi implements AiService {
  String answerText = 'Resposta da IA';
  Object? error;
  int callCount = 0;
  String? lastPrompt;
  String? lastUserName;

  @override
  Future<String> answer(
    String prompt, {
    List<ChatMessage>? history,
    String? userName,
  }) async {
    callCount++;
    lastPrompt = prompt;
    lastUserName = userName;
    if (error != null) throw error!;
    return answerText;
  }
}