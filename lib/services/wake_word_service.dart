abstract class WakeWordService {
  Future<void> start({
    required void Function() onDetected,
    required void Function() onError,
  });
  Future<void> stop();
  Future<void> dispose();
}
