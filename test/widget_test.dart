import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kay/controllers/kay_controller.dart';
import 'package:kay/models/kay_state.dart';
import 'package:kay/screens/home_screen.dart';
import 'package:kay/widgets/kay_core.dart';
import 'package:kay/services/ai_service.dart';
import 'package:kay/services/conversation_memory.dart';

import 'fake_voice_service.dart';

class FakeAiService implements AiService {
  String answerText = 'Olá! Como posso ajudar?';
  @override
  Future<String> answer(
    String prompt, {
    List<ChatMessage>? history,
    String? userName,
  }) async => answerText;
}

void main() {
  testWidgets('Toque inicia voz e mostra transcrição e resposta', (
    tester,
  ) async {
    final voice = FakeVoiceService();
    final ai = FakeAiService();
    final controller = KayController(voice, ai: ai);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller)),
    );
    expect(find.text('Toque no K para falar'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(
      tester.widget<KayCore>(find.byType(KayCore)).state,
      KayState.listening,
    );
    voice.result!('Olá Kay', true);
    await tester.pump();
    expect(find.text('Olá Kay'), findsOneWidget);
    expect(find.textContaining('Olá! Como posso ajudar?'), findsOneWidget);
    voice.speaking!.complete();
    await tester.pump();
    expect(tester.widget<KayCore>(find.byType(KayCore)).state, KayState.idle);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Texto ampliado e tela pequena permitem rolagem sem overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final voice = FakeVoiceService()..available = false;
    final controller = KayController(voice);
    addTearDown(controller.dispose);
    await controller.onTap();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(3),
            disableAnimations: true,
          ),
          child: HomeScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('K'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
