import 'dart:async';

import 'package:kay/services/voice_service.dart';

class FakeVoiceService implements VoiceService {
  bool available = true;
  bool failSpeech = false;
  int listenCount = 0;
  int cancelCount = 0;
  int speakCount = 0;
  Completer<void>? speaking;
  Completer<bool>? initialization;
  void Function(String, bool)? result;
  void Function(String)? error;
  void Function()? done;
  @override
  Future<bool> initialize() async =>
      initialization == null ? available : await initialization!.future;
  @override
  Future<void> listen({
    required void Function(String, bool) onResult,
    required void Function(String) onError,
    required void Function() onDone,
    Duration initialSilenceTimeout = const Duration(seconds: 10),
    Duration silenceAfterWarning = const Duration(seconds: 5),
  }) async {
    listenCount++;
    result = onResult;
    error = onError;
    done = onDone;
  }

  @override
  Future<void> stopListening() async {
    done?.call();
  }

  @override
  Future<void> cancelListening() async {
    cancelCount++;
  }

  @override
  Future<void> speak(String text) async {
    speakCount++;
    if (failSpeech) throw StateError('No voice');
    speaking = Completer<void>();
    await speaking!.future;
  }

  @override
  Future<void> stopSpeaking() async {
    if (speaking != null && !speaking!.isCompleted) speaking!.complete();
  }
}
