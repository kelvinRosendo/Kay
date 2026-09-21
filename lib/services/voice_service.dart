abstract class VoiceService {
  Future<bool> initialize();
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String code) onError,
    required void Function() onDone,
    Duration initialSilenceTimeout = const Duration(seconds: 10),
    Duration silenceAfterWarning = const Duration(seconds: 5),
  });
  Future<void> stopListening();
  Future<void> cancelListening();
  Future<void> speak(String text);
  Future<void> stopSpeaking();
}
