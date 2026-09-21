import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kay/controllers/kay_controller.dart';
import 'package:kay/models/kay_state.dart';
import 'package:kay/services/wake_word_service.dart';

import 'fake_voice_service.dart';

class FakeWakeWord implements WakeWordService {
  int starts = 0;
  int stops = 0;
  bool listening = false;
  bool fail = false;
  Completer<void>? pendingStart;
  void Function()? detected;
  void Function()? failed;
  @override
  Future<void> start({
    required void Function() onDetected,
    required void Function() onError,
  }) async {
    starts++;
    detected = onDetected;
    failed = onError;
    if (fail) throw StateError('unavailable');
    listening = true;
    if (pendingStart != null) await pendingStart!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    listening = false;
  }

  @override
  Future<void> dispose() async {
    listening = false;
  }
}

void main() {
  late FakeVoiceService voice;
  late FakeWakeWord wake;
  late KayController controller;
  setUp(() {
    voice = FakeVoiceService();
    wake = FakeWakeWord();
    controller = KayController(voice, wakeWord: wake);
  });
  tearDown(() => controller.dispose());
  testWidgets(
    'detecção para antes de falar, escuta só após confirmação e rearma após resposta',
    (tester) async {
      await controller.setWakeEnabled(true);
      expect(controller.waitingForWake, true);
      expect(voice.listenCount, 0);
      wake.detected!();
      await tester.pump();
      expect(wake.listening, false);
      expect(controller.response, 'Estou ouvindo');
      expect(voice.listenCount, 0);
      wake.detected!();
      expect(voice.speakCount, 1);
      voice.speaking!.complete();
      await tester.pump();
      expect(controller.state, KayState.listening);
      expect(voice.listenCount, 1);
      voice.result!('Olá', true);
      await tester.pump();
      expect(wake.starts, 1);
      voice.speaking!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(wake.starts, 2);
      expect(controller.waitingForWake, true);
    },
  );
  testWidgets('desligar durante confirmação não inicia comando', (
    tester,
  ) async {
    await controller.setWakeEnabled(true);
    wake.detected!();
    await tester.pump();
    await controller.setWakeEnabled(false);
    await tester.pump(const Duration(seconds: 1));
    expect(voice.listenCount, 0);
    expect(wake.listening, false);
    expect(controller.wakeEnabled, false);
  });
  testWidgets('cancelamento de ciclo de vida impede detecção atrasada', (
    tester,
  ) async {
    await controller.setWakeEnabled(true);
    final oldCallback = wake.detected!;
    await controller.cancel();
    oldCallback();
    await tester.pump(const Duration(seconds: 1));
    expect(voice.speakCount, 0);
    expect(controller.wakeEnabled, false);
    expect(wake.listening, false);
  });
  testWidgets('toque manual libera detector antes de ouvir', (tester) async {
    await controller.setWakeEnabled(true);
    await controller.onTap();
    expect(wake.listening, false);
    expect(voice.listenCount, 1);
    expect(controller.state, KayState.listening);
    await controller.cancel();
  });
  testWidgets('erro do detector desliga modo e permite nova tentativa', (
    tester,
  ) async {
    await controller.setWakeEnabled(true);
    wake.failed!();
    await tester.pump();
    expect(controller.wakeEnabled, false);
    expect(controller.error, isNotNull);
    expect(wake.listening, false);
    await controller.setWakeEnabled(true);
    expect(controller.waitingForWake, true);
  });
  testWidgets('desligar durante carregamento não rearma depois', (
    tester,
  ) async {
    wake.pendingStart = Completer<void>();
    final enabling = controller.setWakeEnabled(true);
    await tester.pump();
    await controller.setWakeEnabled(false);
    wake.pendingStart!.complete();
    await enabling;
    wake.detected!();
    await tester.pump();
    expect(controller.waitingForWake, false);
    expect(controller.wakeEnabled, false);
    expect(controller.busy, false);
    expect(voice.speakCount, 0);
  });
  testWidgets('permissão negada não inicia detector', (tester) async {
    voice.available = false;
    await controller.setWakeEnabled(true);
    expect(wake.starts, 0);
    expect(controller.wakeEnabled, false);
    expect(controller.error, contains('Permita'));
  });
}
