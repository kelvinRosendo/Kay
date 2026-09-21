import 'package:flutter_test/flutter_test.dart';
import 'package:kay/controllers/kay_controller.dart';
import 'package:kay/models/kay_state.dart';

import 'fake_voice_service.dart';
import 'sprint9_fakes.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeVoiceService voice;
  late RecordingAi ai;
  late FakeWakeWord wake;
  late KayController controller;

  setUp(() {
    voice = FakeVoiceService();
    ai = RecordingAi();
    wake = FakeWakeWord();
    controller = KayController(voice, ai: ai, wakeWord: wake);
  });
  tearDown(() => controller.dispose());

  group('tempo de resposta configurável', () {
    test('espera inicial nunca fica abaixo de 10 s', () {
      controller.setTiming(
        initialWait: const Duration(seconds: 2),
        silenceAfterWarning: const Duration(seconds: 1),
      );
      expect(controller.initialWait, const Duration(seconds: 10));
      expect(controller.silenceAfterWarning, const Duration(seconds: 3));
    });

    test('valores altos são mantidos', () {
      controller.setTiming(
        initialWait: const Duration(seconds: 25),
        silenceAfterWarning: const Duration(seconds: 12),
      );
      expect(controller.initialWait, const Duration(seconds: 25));
      expect(
        controller.silenceAfterWarning,
        const Duration(seconds: 12),
      );
    });

    test('alterar o timing reinicia o prazo da escuta ativa', () async {
      await controller.onTap();
      expect(controller.state, KayState.listening);
      controller.setTiming(
        initialWait: const Duration(seconds: 20),
        silenceAfterWarning: const Duration(seconds: 8),
      );
      voice.result!('Olá', true);
      await flush();
      expect(controller.state, KayState.speaking);
      voice.speaking!.complete();
      await flush();
    });
  });

  group('nome do usuário', () {
    test('nome definido chega ao serviço de IA', () async {
      controller.setUserName('  Maria  ');
      expect(controller.userName, 'Maria');
      await controller.onTap();
      voice.result!('Como você está', true);
      await flush();
      expect(ai.lastUserName, 'Maria');
      voice.speaking!.complete();
      await flush();
    });

    test('nome vazio ou nulo desativa personalização', () async {
      controller.setUserName('   ');
      expect(controller.userName, isNull);
      controller.setUserName(null);
      expect(controller.userName, isNull);
      controller.setUserName('Ana');
      controller.setUserName('');
      expect(controller.userName, isNull);
    });

    test('sem nome definido a IA recebe userName nulo', () async {
      await controller.onTap();
      voice.result!('Qual a sua função', true);
      await flush();
      expect(ai.lastUserName, isNull);
      voice.speaking!.complete();
      await flush();
    });
  });

  group('ativação em segundo plano', () {
    test('setWakeEnabled(true) arma a palavra chave e desliga com false', () async {
      await controller.setWakeEnabled(true);
      expect(controller.wakeEnabled, isTrue);
      expect(wake.startCount, 1);
      expect(controller.waitingForWake, isTrue);

      await controller.setWakeEnabled(false);
      expect(controller.wakeEnabled, isFalse);
    });

    test('não inicia escuta por "Kay" quando o microfone falha', () async {
      voice.available = false;
      await controller.setWakeEnabled(true);
      expect(controller.wakeEnabled, isFalse);
      expect(wake.startCount, 0);
      expect(controller.error, contains('microfone'));
      expect(controller.waitingForWake, isFalse);
    });
  });

  test('limpar conversa também zera a memória exposta pela tela', () async {
    await controller.onTap();
    voice.result!('Pergunta um', true);
    await flush();
    voice.speaking!.complete();
    await flush();
    expect(controller.memorySnap, isNotEmpty);

    controller.clearConversation();
    expect(controller.memorySnap, isEmpty);
    expect(controller.hasConversation, isFalse);
  });
}