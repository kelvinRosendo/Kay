import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kay/controllers/kay_controller.dart';
import 'package:kay/models/kay_state.dart';
import 'package:kay/services/ai_service.dart';
import 'package:kay/services/conversation_memory.dart';

import 'fake_voice_service.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

class FakeAiService implements AiService {
  String answerText = 'Resposta da IA';
  Object? error;
  int callCount = 0;
  List<ChatMessage>? lastHistory;

  @override
  Future<String> answer(
    String prompt, {
    List<ChatMessage>? history,
    String? userName,
  }) async {
    callCount++;
    lastHistory = history;
    if (error != null) throw error!;
    return answerText;
  }
}

class FakeMemory extends ConversationMemory {
  FakeMemory() : super(maxExchanges: 3);
  bool cleared = false;

  @override
  void clear() {
    cleared = true;
    super.clear();
  }
}

void main() {
  late FakeVoiceService voice;
  late KayController controller;
  late FakeAiService ai;
  setUp(() {
    voice = FakeVoiceService();
    ai = FakeAiService();
    controller = KayController(voice, ai: ai);
  });
  tearDown(() => controller.dispose());
  test('ouve, transcreve, fala uma única vez e retorna ao repouso', () async {
    await controller.onTap();
    expect(controller.state, KayState.listening);
    voice.result!('Olá', false);
    expect(controller.transcript, 'Olá');
    voice.result!('Olá Kay', true);
    voice.result!('Olá Kay', true);
    await flush();
    expect(controller.state, KayState.speaking);
    expect(controller.response, 'Resposta da IA');
    expect(voice.speakCount, 1);
    voice.speaking!.complete();
    await flush();
    expect(controller.state, KayState.idle);
  });
  test('permissão negada permite nova tentativa', () async {
    voice.available = false;
    await controller.onTap();
    expect(controller.error, contains('Permita'));
    expect(controller.busy, false);
    voice.available = true;
    await controller.onTap();
    expect(controller.state, KayState.listening);
    expect(controller.error, isNull);
  });
  test('silêncio não dispara fala', () async {
    await controller.onTap();
    voice.result!('', true);
    await flush();
    expect(controller.error, contains('Não ouvi'));
    expect(voice.speakCount, 0);
  });
  test('erro de voz mantém a resposta escrita', () async {
    voice.failSpeech = true;
    await controller.onTap();
    voice.result!('Teste', true);
    await flush();
    expect(controller.state, KayState.idle);
    expect(controller.response, 'Resposta da IA');
    expect(controller.error, contains('não consegui falar'));
  });
  test(
    'cancelar ignora resultado atrasado e permite ouvir novamente',
    () async {
      await controller.onTap();
      final previousResult = voice.result!;
      await controller.cancel();
      await controller.onTap();
      previousResult('antigo', true);
      expect(controller.transcript, isEmpty);
      expect(controller.state, KayState.listening);
    },
  );
  test('cancelar durante inicialização não abre microfone depois', () async {
    voice.initialization = Completer<bool>();
    final pending = controller.onTap();
    await controller.cancel();
    voice.initialization!.complete(true);
    await pending;
    expect(voice.listenCount, 0);
    expect(controller.state, KayState.idle);
  });
  test('toque interrompe resposta falada', () async {
    await controller.onTap();
    voice.result!('Olá', true);
    await flush();
    await controller.onTap();
    expect(controller.state, KayState.idle);
    expect(controller.busy, false);
  });
  testWidgets('fim da escuta espera resultado final e trata ausência de fala', (
    tester,
  ) async {
    await controller.onTap();
    voice.done!();
    await tester.pump(const Duration(milliseconds: 800));
    expect(controller.error, contains('Não ouvi'));
  });

  group('conversa com IA', () {
    test('resposta da IA é exibida e falada', () async {
      ai.answerText = 'Estou bem, obrigado!';
      await controller.onTap();
      voice.result!('Como você está', true);
      await flush();
      expect(controller.response, 'Estou bem, obrigado!');
      expect(controller.state, KayState.speaking);
      voice.speaking!.complete();
      await flush();
      expect(controller.state, KayState.idle);
    });

    test('histórico é enviado para a IA', () async {
      ai.answerText = 'Resposta 1';
      await controller.onTap();
      voice.result!('Pergunta 1', true);
      await flush();
      voice.speaking!.complete();
      await flush();

      ai.answerText = 'Resposta 2';
      await controller.onTap();
      voice.result!('Pergunta 2', true);
      await flush();
      expect(ai.callCount, 2);
      expect(ai.lastHistory, isNotEmpty);
      expect(ai.lastHistory!.length, 2); // first exchange
    });

    test('clearConversation limpa o histórico', () async {
      ai.answerText = 'Resposta';
      await controller.onTap();
      voice.result!('Pergunta', true);
      await flush();
      voice.speaking!.complete();
      await flush();

      controller.clearConversation();
      expect(controller.hasConversation, isFalse);

      // Next call should have empty history
      await controller.onTap();
      voice.result!('Nova pergunta', true);
      await flush();
      expect(ai.lastHistory, isEmpty);
    });

    test('hasConversation retorna false quando vazio', () {
      expect(controller.hasConversation, isFalse);
    });

    test('hasConversation retorna true após troca', () async {
      ai.answerText = 'Ok';
      await controller.onTap();
      voice.result!('Teste', true);
      await flush();
      voice.speaking!.complete();
      await flush();
      expect(controller.hasConversation, isTrue);
    });

    test('erro de IA é exibido e falado', () async {
      ai.error = const AiError.serverUnreachable();
      await controller.onTap();
      voice.result!('Pergunta', true);
      await flush();
      expect(controller.response, contains('servidor'));
      expect(controller.state, KayState.speaking);
      voice.speaking!.complete();
      await flush();
      expect(controller.state, KayState.idle);
    });

    test('timeout de IA é tratado', () async {
      ai.error = const AiError.timeout();
      await controller.onTap();
      voice.result!('Pergunta', true);
      await flush();
      expect(controller.response, contains('demorou muito'));
    });

    test('modelo não encontrado é tratado', () async {
      ai.error = const AiError.modelNotFound('llama3');
      await controller.onTap();
      voice.result!('Pergunta', true);
      await flush();
      expect(controller.response, contains('llama3'));
      expect(controller.response, contains('não foi encontrado'));
    });
  });

  group('cancelar com sessão nativa', () {
    test('cancel() reseta o estado', () async {
      await controller.onTap();
      voice.result!('Teste', true);
      await flush();
      // With AI, state transitions: listening → thinking → speaking (error)
      expect(controller.state, KayState.speaking);
      await controller.cancel();
      expect(controller.state, KayState.idle);
      expect(controller.transcript, isEmpty);
      expect(controller.response, isEmpty);
    });

    test('cancel() interrompe TTS em andamento', () async {
      ai.answerText = 'Resposta longa';
      await controller.onTap();
      voice.result!('Pergunta', true);
      await flush();
      expect(controller.state, KayState.speaking);
      expect(voice.speaking, isNotNull);
      await controller.cancel();
      expect(controller.state, KayState.idle);
      // After cancel, pending AI request should be completed
    });
  });

  group('comandos de data/hora', () {
    late FakeVoiceService voice;
    late KayController controller;
    setUp(() {
      voice = FakeVoiceService();
      controller = KayController(
        voice,
        now: () => DateTime(2026, 9, 21, 14, 7),
      );
    });
    tearDown(() => controller.dispose());

    test('responde data sem chamar IA', () async {
      await controller.onTap();
      voice.result!('qual é a data de hoje', true);
      await flush();
      expect(controller.response, contains('21 de setembro de 2026'));
      voice.speaking!.complete();
      await flush();
      expect(controller.state, KayState.idle);
    });

    test('responde dia da semana sem chamar IA', () async {
      await controller.onTap();
      voice.result!('que dia da semana é hoje', true);
      await flush();
      expect(controller.response, contains('segunda-feira'));
      voice.speaking!.complete();
      await flush();
    });

    test('responde amanhã sem chamar IA', () async {
      await controller.onTap();
      voice.result!('que dia é amanhã', true);
      await flush();
      expect(controller.response, contains('terça-feira'));
      voice.speaking!.complete();
      await flush();
    });
  });
}
