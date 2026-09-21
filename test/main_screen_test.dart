import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kay/controllers/kay_controller.dart';
import 'package:kay/screens/main_screen.dart';
import 'package:kay/services/preferences_service.dart';
import 'package:kay/theme/kay_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_voice_service.dart';
import 'sprint9_fakes.dart';

void main() {
  late PreferencesService prefs;
  late FakeAppPermissions perms;
  late FakeSystemStatus sys;
  late KayController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesService();
    await prefs.init();
    perms = FakeAppPermissions();
    sys = FakeSystemStatus();
    controller = KayController(
      FakeVoiceService(),
      ai: RecordingAi(),
      wakeWord: FakeWakeWord(),
    );
  });

  tearDown(() => controller.dispose());

  /// KayCore runs a repeating glow animation, so pumpAndSettle never settles.
  /// Fixed pumps advance layout, navigation and async setState instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKayTheme(),
        home: MainScreen(
          prefs: prefs,
          controller: controller,
          permissions: perms,
          systemStatus: sys,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> openSidebar(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await settle(tester);
  }

  Future<void> goTo(WidgetTester tester, String item) async {
    await openSidebar(tester);
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  testWidgets('abre a aba Conversa com o botão de iniciar', (tester) async {
    await pumpApp(tester);
    expect(find.text('Iniciar conversa'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('menu lateral navega para Permissões, Configurações, Status e Sobre', (
    tester,
  ) async {
    await pumpApp(tester);

    await goTo(tester, 'Permissões');
    expect(find.text('Microfone'), findsOneWidget);

    await goTo(tester, 'Configurações');
    expect(find.byType(Slider), findsWidgets);

    await goTo(tester, 'Status');
    expect(find.text('Kay em segundo plano'), findsWidgets);

    await goTo(tester, 'Sobre o Kay');
    expect(find.textContaining('Sprint 9'), findsOneWidget);
  });

  testWidgets('barra fixa mostra somente o botão de ativar sem alertas', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byKey(const ValueKey('bg_inactive')), findsOneWidget);
    expect(find.text('Ativar Kay em segundo plano'), findsOneWidget);
    expect(find.text('Permissão de microfone pendente.'), findsNothing);
  });

  testWidgets('sem permissão de microfone a barra avisa e leva às permissões', (
    tester,
  ) async {
    perms.micGranted = false;
    await pumpApp(tester);
    expect(find.text('Permissão de microfone pendente.'), findsOneWidget);

    await tester.tap(find.text('Abrir'));
    await settle(tester);
    expect(find.text('Microfone'), findsOneWidget);
  });

  testWidgets('ativar em segundo plano inicia escuta, com ação explícita do usuário', (
    tester,
  ) async {
    perms.micGranted = false;
    perms.notifGranted = false;
    await pumpApp(tester);

    await tester.tap(find.text('Ativar Kay em segundo plano'));
    await settle(tester);

    expect(perms.micRequests, 1);
    expect(perms.notifRequests, 1);
    expect(controller.wakeEnabled, isTrue);
    expect(find.byKey(const ValueKey('bg_active')), findsOneWidget);
    expect(find.text('Kay ativo em segundo plano'), findsOneWidget);

    await tester.tap(find.text('Desligar'));
    await settle(tester);
    expect(controller.wakeEnabled, isFalse);
    expect(find.byKey(const ValueKey('bg_inactive')), findsOneWidget);
  });

  testWidgets('ativação ativa mas com notificação pendente avisa na barra', (
    tester,
  ) async {
    perms.notifGranted = false;
    perms.micGranted = true;
    await pumpApp(tester);

    await controller.setWakeEnabled(true);
    await settle(tester);

    expect(find.text('Kay ativo em segundo plano'), findsOneWidget);
    expect(find.text('Notificação pendente'), findsOneWidget);
    expect(find.text('Notificação ativa'), findsNothing);
  });

  testWidgets('configurações de tempo são aplicadas ao controle e ao nativo', (
    tester,
  ) async {
    prefs.waitSeconds = 20;
    prefs.silenceSeconds = 8;
    await pumpApp(tester);

    expect(controller.initialWait, const Duration(seconds: 20));
    expect(controller.silenceAfterWarning, const Duration(seconds: 8));
    expect(sys.lastWaitMs, 20 * 1000);
    expect(sys.lastSilenceMs, 8 * 1000);
  });

  testWidgets('nome do usuário é aplicado quando a personalização está ligada', (
    tester,
  ) async {
    prefs.useNameInReplies = true;
    prefs.userName = 'Pedro';
    await pumpApp(tester);
    expect(controller.userName, 'Pedro');

    // O controle espelha a escolha: sem autorização, nome não é enviado.
    controller.setUserName(null);
    expect(controller.userName, isNull);
  });

  testWidgets('tela pequena e texto ampliado não causam overflow nas abas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);

    await goTo(tester, 'Permissões');
    expect(find.text('Microfone'), findsOneWidget);

    await goTo(tester, 'Configurações');
    expect(find.byType(Slider), findsWidgets);

    await goTo(tester, 'Conversa');
    expect(find.text('Iniciar conversa'), findsOneWidget);
  });

  testWidgets('modo de movimento reduzido não quebra a interface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKayTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MainScreen(
            prefs: prefs,
            controller: controller,
            permissions: perms,
            systemStatus: sys,
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Iniciar conversa'), findsOneWidget);
  });
}