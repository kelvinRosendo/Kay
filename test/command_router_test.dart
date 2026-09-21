import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:kay/services/command_router.dart';
import 'package:kay/services/app_launcher.dart';
import 'package:kay/controllers/kay_controller.dart';
import 'package:kay/models/kay_state.dart';

import 'fake_voice_service.dart';

class FakeLauncher implements AppLauncher {
  final opened = <LocalCommand>[];
  LaunchResult result = LaunchResult.opened;
  @override
  Future<LaunchResult> open(LocalCommand command) async {
    opened.add(command);
    return result;
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reconhece os comandos e variações em português', () {
    final cases = {
      'Kay, abrir o YouTube!': LocalCommand.youtube,
      'Kai abre o you tube por favor': LocalCommand.youtube,
      'Abra Spotify': LocalCommand.spotify,
      'por favor abrir o Google Chrome': LocalCommand.chrome,
      'abrir configurações': LocalCommand.settings,
      'abre os ajustes': LocalCommand.settings,
      'Que horas são?': LocalCommand.time,
      'Kay, qual é a hora?': LocalCommand.time,
    };
    cases.forEach(
      (text, command) =>
          expect(CommandRouter.parse(text), command, reason: text),
    );
  });
  test('negações, menções e comandos compostos não abrem aplicativos', () {
    for (final text in [
      'não abra YouTube',
      'como abrir Spotify',
      'YouTube',
      'abrir YouTube e Spotify',
      'não quero abrir o Chrome',
      'abrir banco',
      'quando digo abrir YouTube',
      'abrir youtube não',
      '',
    ]) {
      expect(CommandRouter.parse(text), isNull, reason: text);
    }
  });
  test('horário usa o relógio local com minutos completos', () {
    expect(
      CommandRouter.timeReply(DateTime(2026, 9, 20, 9, 5)),
      'Agora são 09:05.',
    );
    expect(CommandRouter.timeReply(DateTime(2026, 9, 20)), 'Agora são 00:00.');
  });
  group('data e hora locais', () {
    test('reconhece "Qual é a data de hoje?"', () {
      expect(
        CommandRouter.parse('Qual é a data de hoje?'),
        LocalCommand.date,
      );
    });
    test('reconhece "Que dia é hoje?"', () {
      expect(CommandRouter.parse('Que dia é hoje?'), LocalCommand.date);
    });
    test('reconhece "Me diga a data"', () {
      expect(CommandRouter.parse('Me diga a data'), LocalCommand.date);
    });
    test('reconhece "Que dia da semana é hoje?"', () {
      expect(
        CommandRouter.parse('Que dia da semana é hoje?'),
        LocalCommand.weekday,
      );
    });
    test('reconhece "Qual é o dia da semana?"', () {
      expect(
        CommandRouter.parse('Qual é o dia da semana?'),
        LocalCommand.weekday,
      );
    });
    test('reconhece "Qual é o dia de amanhã?"', () {
      expect(
        CommandRouter.parse('Qual é o dia de amanhã?'),
        LocalCommand.tomorrow,
      );
    });
    test('reconhece "Que dia é amanhã?"', () {
      expect(CommandRouter.parse('Que dia é amanhã?'), LocalCommand.tomorrow);
    });
    test('data é formatada corretamente em português', () {
      expect(
        CommandRouter.dateReply(DateTime(2026, 9, 20)),
        'Hoje é 20 de setembro de 2026.',
      );
      expect(
        CommandRouter.dateReply(DateTime(2026, 1, 1)),
        'Hoje é 1 de janeiro de 2026.',
      );
    });
    test('dia da semana é formatado corretamente', () {
      // 2026-09-20 is a Sunday
      expect(
        CommandRouter.weekdayReply(DateTime(2026, 9, 20)),
        'Hoje é domingo, 20 de setembro.',
      );
      // 2026-09-21 is a Monday
      expect(
        CommandRouter.weekdayReply(DateTime(2026, 9, 21)),
        'Hoje é segunda-feira, 21 de setembro.',
      );
    });
    test('amanhã é formatado corretamente', () {
      // 2026-09-20 → amanhã é segunda-feira 21
      expect(
        CommandRouter.tomorrowReply(DateTime(2026, 9, 20)),
        'Amanhã é segunda-feira, 21 de setembro.',
      );
    });
    test('perguntas com "o que aconteceu hoje" não são confundidas com data',
        () {
      expect(CommandRouter.parse('O que aconteceu hoje?'), isNull);
    });
    test('comando de data com "Kay" no início', () {
      expect(
        CommandRouter.parse('Kay, qual é a data de hoje?'),
        LocalCommand.date,
      );
    });
  });
  group('fluxo de comandos', () {
    late FakeVoiceService voice;
    late FakeLauncher launcher;
    late KayController controller;
    setUp(() {
      voice = FakeVoiceService();
      launcher = FakeLauncher();
      controller = KayController(
        voice,
        launcher: launcher,
        now: () => DateTime(2026, 9, 20, 14, 7),
      );
    });
    tearDown(() => controller.dispose());
    test(
      'anuncia antes de abrir e não duplica ação com resultado repetido',
      () async {
        await controller.onTap();
        voice.result!('abrir YouTube', true);
        voice.result!('abrir YouTube', true);
        await flush();
        expect(launcher.opened, isEmpty);
        expect(controller.response, contains('Vou abrir'));
        voice.speaking!.complete();
        await flush();
        expect(launcher.opened, [LocalCommand.youtube]);
        expect(controller.state, KayState.idle);
      },
    );
    test('cancelar durante anúncio impede abertura posterior', () async {
      await controller.onTap();
      voice.result!('abrir Spotify', true);
      await flush();
      await controller.cancel();
      await flush();
      expect(launcher.opened, isEmpty);
    });
    test('aplicativo ausente produz explicação escrita e falada', () async {
      launcher.result = LaunchResult.unavailable;
      await controller.onTap();
      voice.result!('abrir Spotify', true);
      await flush();
      voice.speaking!.complete();
      await flush();
      expect(controller.response, contains('Não encontrei Spotify'));
      expect(voice.speakCount, 2);
      voice.speaking!.complete();
      await flush();
      expect(controller.state, KayState.idle);
    });
    test('falha no TTS não impede comando solicitado', () async {
      voice.failSpeech = true;
      await controller.onTap();
      voice.result!('abrir configurações', true);
      await flush();
      expect(launcher.opened, [LocalCommand.settings]);
      expect(controller.state, KayState.idle);
    });
    test('horas são faladas sem abrir aplicativo', () async {
      await controller.onTap();
      voice.result!('que horas são', true);
      await flush();
      expect(controller.response, 'Agora são 14:07.');
      expect(launcher.opened, isEmpty);
      voice.speaking!.complete();
      await flush();
    });
    test('data é respondida sem abrir aplicativo', () async {
      await controller.onTap();
      voice.result!('qual é a data de hoje', true);
      await flush();
      expect(controller.response, contains('20 de setembro de 2026'));
      expect(launcher.opened, isEmpty);
      voice.speaking!.complete();
      await flush();
    });
    test('dia da semana é respondido sem abrir aplicativo', () async {
      await controller.onTap();
      voice.result!('que dia da semana é hoje', true);
      await flush();
      expect(controller.response, contains('domingo'));
      expect(launcher.opened, isEmpty);
      voice.speaking!.complete();
      await flush();
    });
  });
  test('canal nativo recebe apenas identificador do comando', () async {
    const channel = MethodChannel('kay/local_commands');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'open');
          expect(call.arguments, 'youtube');
          return 'opened';
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    expect(
      await DeviceAppLauncher().open(LocalCommand.youtube),
      LaunchResult.opened,
    );
  });
}
