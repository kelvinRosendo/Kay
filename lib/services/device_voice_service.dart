import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'voice_service.dart';

class DeviceVoiceService implements VoiceService {
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  void Function(String)? _onError;
  void Function()? _onDone;
  String? _locale;
  int _utterance = 0;

  @override
  Future<bool> initialize() async {
    final available = await _speech.initialize(
      onError: (error) => _onError?.call(error.errorMsg),
      onStatus: (status) {
        if (status == 'done') _onDone?.call();
      },
      options: [SpeechToText.androidNoBluetooth],
    );
    if (!available) return false;
    final locales = await _speech.locales();
    final portuguese = locales.where(
      (l) => l.localeId.replaceAll('_', '-').toLowerCase() == 'pt-br',
    );
    final anyPortuguese = locales.where(
      (l) => l.localeId.toLowerCase().startsWith('pt'),
    );
    _locale = portuguese.isNotEmpty
        ? portuguese.first.localeId
        : anyPortuguese.isNotEmpty
        ? anyPortuguese.first.localeId
        : 'pt_BR';
    return true;
  }

  @override
  Future<void> listen({
    required void Function(String, bool) onResult,
    required void Function(String) onError,
    required void Function() onDone,
    Duration initialSilenceTimeout = const Duration(seconds: 10),
    Duration silenceAfterWarning = const Duration(seconds: 5),
  }) async {
    _onError = onError;
    _onDone = onDone;
    // The initial silence window uses the configured wait; the total window
    // never shrinks below the previously validated 30 seconds.
    final pause = initialSilenceTimeout < const Duration(seconds: 10)
        ? const Duration(seconds: 10)
        : initialSilenceTimeout;
    final total = pause + silenceAfterWarning;
    final listenFor =
        total < const Duration(seconds: 30) ? const Duration(seconds: 30) : total;
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: _locale,
        listenFor: listenFor,
        pauseFor: pause,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  @override
  Future<void> stopListening() => _speech.stop();
  @override
  Future<void> cancelListening() async {
    _onError = null;
    _onDone = null;
    await _speech.cancel();
  }

  @override
  Future<void> speak(String text) async {
    final utterance = ++_utterance;
    if (await _tts.isLanguageAvailable('pt-BR') != true) {
      throw StateError(
        'Instale uma voz em português nas configurações de texto para fala do Android.',
      );
    }
    if (utterance != _utterance) return;
    await _tts.setLanguage('pt-BR');
    final voices = await _tts.getVoices;
    if (voices is List) {
      final maleVoices = voices.whereType<Map>().where((voice) {
        final locale = '${voice['locale']}'.replaceAll('_', '-').toLowerCase();
        final name = '${voice['name']}'.toLowerCase();
        return locale == 'pt-br' &&
            (voice['gender'] == 'male' ||
                RegExp(r'(^|[^a-z])(male|masculino|masculina)([^a-z]|$)')
                    .hasMatch(name));
      });
      if (maleVoices.isNotEmpty) {
        final voice = maleVoices.first;
        await _tts.setVoice({
          'name': '${voice['name']}',
          'locale': '${voice['locale']}',
        });
      }
    }
    await _tts.setPitch(.82);
    try {
      final selected = await const MethodChannel('kay/voice')
          .invokeMethod<String>('get');
      if (selected != null) {
        await _tts.setVoice({'name': selected, 'locale': 'pt-BR'});
      }
    } on MissingPluginException {
      // Other platforms retain their installed default voice.
    }
    await _tts.setSpeechRate(.48);
    await _tts.awaitSpeakCompletion(true);
    if (utterance != _utterance) return;
    final result = await _tts.speak(text);
    if (result != 1) {
      throw StateError(
        'A voz do aparelho não conseguiu reproduzir a resposta.',
      );
    }
  }

  @override
  Future<void> stopSpeaking() async {
    ++_utterance;
    await _tts.stop();
  }
}
