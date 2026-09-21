import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/kay_state.dart';
import '../services/voice_service.dart';
import '../services/app_launcher.dart';
import '../services/command_router.dart';
import '../services/wake_word_service.dart';
import '../services/device_wake_word_service.dart';
import '../services/ai_service.dart';
import '../services/conversation_memory.dart';

class KayController extends ChangeNotifier {
  KayController(
    this._voice, {
    AppLauncher? launcher,
    DateTime Function()? now,
    WakeWordService? wakeWord,
    AiService? ai,
    ConversationMemory? memory,
  })  : _launcher = launcher ?? DeviceAppLauncher(),
        _wakeWord = wakeWord ?? DeviceWakeWordService(),
        _ai = ai ?? const UnavailableAiService(),
        _now = now ?? DateTime.now,
        _memory = memory ?? ConversationMemory(now: now ?? DateTime.now);
  final WakeWordService _wakeWord;
  final AiService _ai;
  final ConversationMemory _memory;
  bool wakeEnabled = false;
  bool _waitingForWake = false;
  bool _wakeUsed = false;
  Timer? _wakeTimer;
  bool get waitingForWake => _waitingForWake;
  final VoiceService _voice;
  final AppLauncher _launcher;
  final DateTime Function() _now;
  KayState _state = KayState.idle;
  KayState get state => _state;
  String transcript = '';
  String response = '';
  String? error;

  // ── Configurable voice timing ────────────────────────────────
  Duration _initialWait = const Duration(seconds: 10);
  Duration _silenceAfterWarning = const Duration(seconds: 5);
  String? _userName;

  Duration get initialWait => _initialWait;
  Duration get silenceAfterWarning => _silenceAfterWarning;
  String? get userName => _userName;
  Duration get _listenWindow => _initialWait + _silenceAfterWarning + const Duration(seconds: 5);
  bool get hasConversation => !_memory.isEmpty;
  DateTime? get lastActivity => _memory.lastActivity;
  List<ChatMessage> get memorySnap => _memory.messages;
  bool _disposed = false;
  bool _ready = false;
  bool _starting = false;
  bool _stopping = false;
  int _session = 0;
  Timer? _deadline;
  Timer? _finalWait;
  Completer<void>? _pendingAiRequest;
  bool get busy => _starting || _stopping;
  String get hint => _starting
      ? 'Preparando microfone…'
      : switch (_state) {
          KayState.idle =>
            _waitingForWake
                ? 'Diga "Kay" e aguarde minha resposta'
                : 'Toque no K para falar',
          KayState.listening => 'Estou ouvindo. Toque para terminar.',
          KayState.thinking => 'Preparando resposta…',
          KayState.speaking => 'Toque no K para interromper',
        };
  bool _active(int session) => !_disposed && session == _session;
  void _update() {
    if (!_disposed) notifyListeners();
  }

  Future<void> onTap() async {
    if (busy || _disposed) return;
    _wakeTimer?.cancel();
    if (_waitingForWake) {
      _waitingForWake = false;
      _starting = true;
      final session = ++_session;
      try {
        await _wakeWord.stop();
      } catch (_) {
        _fail(
          session,
          'Não consegui liberar o microfone. Desative a ativação por voz e tente novamente.',
        );
        _starting = false;
        return;
      }
      if (!_active(session)) return;
      _starting = false;
    }
    if (_state == KayState.speaking) {
      await cancel(disableWake: false);
      return;
    }
    if (_state == KayState.thinking) return;
    if (_state == KayState.listening) {
      _stopping = true;
      try {
        await _voice.stopListening();
        _scheduleFinish(_session);
      } catch (_) {
        _fail(
          _session,
          'Não foi possível encerrar o microfone. Tente novamente.',
        );
      } finally {
        _stopping = false;
        _update();
      }
      return;
    }
    final session = ++_session;
    _starting = true;
    transcript = '';
    response = '';
    error = null;
    _update();
    try {
      _ready = _ready || await _voice.initialize();
      if (!_active(session)) return;
      if (!_ready) {
        _fail(
          session,
          'Microfone ou reconhecimento indisponível. Permita o microfone em '
          'Configurações > Apps > Kay > Permissões e verifique o serviço de '
          'reconhecimento de voz do aparelho.',
        );
        return;
      }
      _state = KayState.listening;
      _update();
      _deadline = Timer(
        _listenWindow,
        () => unawaited(_finish(session)),
      );
      await _voice.listen(
        onResult: (text, isFinal) {
          if (!_active(session) || _state != KayState.listening) return;
          transcript = text;
          _update();
          if (isFinal) unawaited(_finish(session));
        },
        onError: (code) {
          if (!_active(session) || _state != KayState.listening) return;
          if (code == 'error_no_match' || code == 'error_speech_timeout') {
            unawaited(_finish(session));
          } else {
            _fail(
              session,
              code.contains('permission')
                  ? 'Permita o uso do microfone nas configurações do Kay e '
                      'tente novamente.'
                  : code.contains('network')
                      ? 'Não consegui reconhecer a fala. Verifique a conexão '
                          'e tente novamente.'
                      : 'O reconhecimento de voz foi interrompido. Toque no K '
                          'para tentar novamente.',
            );
          }
        },
        onDone: () => _scheduleFinish(session),
        initialSilenceTimeout: _initialWait,
        silenceAfterWarning: _silenceAfterWarning,
      );
    } catch (_) {
      _fail(
        session,
        'Não consegui iniciar o reconhecimento de voz. Verifique as '
        'permissões e o serviço de voz do aparelho.',
      );
    } finally {
      if (_active(session)) {
        _starting = false;
        _update();
      }
    }
  }

  void _scheduleFinish(int session) {
    if (!_active(session) || _state != KayState.listening) return;
    _finalWait?.cancel();
    // Android can send its final result just after the done notification.
    _finalWait = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_finish(session)),
    );
  }

  Future<void> _finish(int session) async {
    if (!_active(session) || _state != KayState.listening) return;
    _deadline?.cancel();
    _finalWait?.cancel();
    _state = KayState.thinking;
    _update();
    try {
      await _voice.cancelListening();
      if (!_active(session)) return;
      if (transcript.trim().isEmpty) {
        _fail(
          session,
          'Não ouvi nenhuma frase. Toque no K e tente falar novamente.',
        );
        return;
      }
      final command = CommandRouter.parse(transcript);
      if (command != null && _isAppCommand(command)) {
        await _openApp(command, session);
        return;
      }
      response = switch (command) {
        LocalCommand.time => CommandRouter.timeReply(_now()),
        LocalCommand.date => CommandRouter.dateReply(_now()),
        LocalCommand.weekday => CommandRouter.weekdayReply(_now()),
        LocalCommand.tomorrow => CommandRouter.tomorrowReply(_now()),
        _ => await _answerWithAi(transcript, session),
      };
      _state = KayState.speaking;
      _update();
      await _voice.speak(response).timeout(const Duration(seconds: 45));
      if (_active(session)) {
        // Record successful exchange in conversation memory (skip local cmds)
        if (command == null) {
          _memory.addExchange(user: transcript, assistant: response);
        }
        _state = KayState.idle;
        _update();
      }
    } on AiError catch (e) {
      if (!_active(session)) return;
      response = e.message;
      _state = KayState.speaking;
      _update();
      try {
        await _voice.speak(response).timeout(const Duration(seconds: 30));
      } catch (_) {
        await _quiet(_voice.stopSpeaking);
      }
      if (_active(session)) {
        _state = KayState.idle;
        _update();
      }
    } catch (_) {
      if (!_active(session)) return;
      _fail(
        session,
        'A resposta está na tela, mas não consegui falar. Verifique o '
        'volume e instale uma voz em português nas configurações de texto '
        'para fala do Android.',
      );
      await _quiet(_voice.stopSpeaking);
    } finally {
      _scheduleWake();
    }
  }

  /// Whether a command triggers an app launch.
  static bool _isAppCommand(LocalCommand cmd) =>
      cmd == LocalCommand.youtube ||
      cmd == LocalCommand.spotify ||
      cmd == LocalCommand.chrome ||
      cmd == LocalCommand.settings;

  Future<String> _answerWithAi(String prompt, int session) async {
    // Prune expired memory before querying
    _memory.pruneIfExpired();
    final completer = Completer<void>();
    _pendingAiRequest = completer;
    try {
      final result = await _ai.answer(
        prompt,
        history: _memory.messages,
        userName: _userName,
      );
      if (!_active(session) || completer.isCompleted) return '';
      return result;
    } on AiError {
      if (!_active(session) || completer.isCompleted) return '';
      rethrow;
    } catch (_) {
      if (!_active(session) || completer.isCompleted) return '';
      throw const AiError.unavailable();
    } finally {
      if (!completer.isCompleted) completer.complete();
      if (_pendingAiRequest == completer) _pendingAiRequest = null;
    }
  }

  /// Updates voice timing. The initial wait never drops below 10 seconds and
  /// the post-warning window never drops below 3 seconds. Old timers for an
  /// active listening session are cancelled and restarted with the new value.
  void setTiming({
    required Duration initialWait,
    required Duration silenceAfterWarning,
  }) {
    final wait = initialWait < const Duration(seconds: 10)
        ? const Duration(seconds: 10)
        : initialWait;
    final silence = silenceAfterWarning < const Duration(seconds: 3)
        ? const Duration(seconds: 3)
        : silenceAfterWarning;
    if (wait == _initialWait && silence == _silenceAfterWarning) return;
    _initialWait = wait;
    _silenceAfterWarning = silence;
    if (_state == KayState.listening) {
      _deadline?.cancel();
      _deadline = Timer(_listenWindow, () => unawaited(_finish(_session)));
    }
    _update();
  }

  /// Configures the name Kay may use in AI replies. It is never included in
  /// local command handling. An empty value disables personalization.
  void setUserName(String? name) {
    final trimmed = name?.trim();
    final next = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (next == _userName) return;
    _userName = next;
    _update();
  }

  /// Clears conversation history.
  void clearConversation() {
    _memory.clear();
    _update();
  }

  Future<void> setWakeEnabled(bool enabled) async {
    if (_disposed) return;
    if (!enabled) {
      await cancel();
      return;
    }
    if (busy || _state != KayState.idle || wakeEnabled) return;
    wakeEnabled = true;
    error = null;
    await _armWake();
  }

  void _scheduleWake() {
    if (_disposed ||
        !wakeEnabled ||
        _state != KayState.idle ||
        _waitingForWake) {
      return;
    }
    _wakeTimer?.cancel();
    _wakeTimer = Timer(const Duration(milliseconds: 600), () {
      if (!busy) unawaited(_armWake());
    });
  }

  Future<void> _armWake() async {
    if (_disposed ||
        !wakeEnabled ||
        busy ||
        _state != KayState.idle ||
        _waitingForWake) {
      return;
    }
    final session = ++_session;
    _starting = true;
    _update();
    try {
      _ready = _ready || await _voice.initialize();
      if (!_active(session) || !wakeEnabled) return;
      if (!_ready) throw StateError('permission');
      await _voice.cancelListening();
      if (!_active(session) || !wakeEnabled) return;
      _wakeUsed = true;
      _waitingForWake = true;
      await _wakeWord.start(
        onDetected: () {
          if (_active(session) && _waitingForWake && wakeEnabled) {
            unawaited(_wakeDetected(session));
          }
        },
        onError: () {
          if (_active(session)) {
            _fail(
              session,
              'A ativação por voz foi pausada. Verifique o microfone e ligue '
                  'o controle novamente.',
            );
          }
        },
      );
    } catch (_) {
      _fail(
        session,
        'Não consegui ativar a escuta por "Kay". Permita o microfone e tente '
            'novamente. Este recurso funciona no Android.',
      );
    } finally {
      if (_active(session)) {
        _starting = false;
        _update();
      }
    }
  }

  Future<void> _wakeDetected(int session) async {
    _waitingForWake = false;
    _starting = true;
    try {
      await _wakeWord.stop();
      if (!_active(session) || !wakeEnabled) return;
      response = 'Estou ouvindo';
      transcript = '';
      _state = KayState.speaking;
      _starting = false;
      _update();
      await _voice.speak(response).timeout(const Duration(seconds: 10));
      if (!_active(session) || !wakeEnabled) return;
      _state = KayState.idle;
      await onTap();
    } catch (_) {
      if (!_active(session)) return;
      _fail(
        session,
        'Não consegui iniciar a conversa. Toque no K para tentar novamente.',
      );
      await _quiet(_voice.stopSpeaking);
    } finally {
      if (_active(session)) {
        _starting = false;
        _update();
      }
    }
  }

  Future<void> _openApp(LocalCommand command, int session) async {
    response = 'Vou abrir ${command.label}.';
    _state = KayState.speaking;
    _update();
    try {
      await _voice.speak(response).timeout(const Duration(seconds: 15));
    } catch (_) {
      if (!_active(session)) return;
      await _quiet(_voice.stopSpeaking);
    }
    // A cancelled utterance must never trigger a delayed app launch.
    if (!_active(session)) return;
    _state = KayState.thinking;
    _update();
    LaunchResult result;
    try {
      result = await _launcher.open(command);
    } catch (_) {
      result = LaunchResult.failed;
    }
    if (!_active(session)) return;
    if (result == LaunchResult.opened) {
      response = '${command.label} aberto.';
      _state = KayState.idle;
      _update();
      return;
    }
    response = switch (result) {
      LaunchResult.unavailable =>
        'Não encontrei ${command.label} disponível neste aparelho. '
        'Verifique se está instalado e ativado.',
      LaunchResult.unsupported =>
        'Abrir aplicativos está disponível no Android nesta versão.',
      _ => 'Não consegui abrir ${command.label}. Tente novamente.',
    };
    _state = KayState.speaking;
    _update();
    await _voice.speak(response).timeout(const Duration(seconds: 30));
    if (_active(session)) {
      _state = KayState.idle;
      _update();
    }
  }

  static String replyTo(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-záéíóúãõâêôç ]'), ' ')
        .trim();
    if (RegExp(r'(^| )(oi|olá|ola|bom dia|boa tarde|boa noite)( |$)')
        .hasMatch(normalized)) {
      return 'Olá! Eu sou o Kay. Agora consigo ouvir você e responder em voz.';
    }
    if (normalized.contains('seu nome') || normalized.contains('quem é você')) {
      return 'Eu sou o Kay, seu assistente pessoal.';
    }
    return 'Você disse: $text. A IA local está desligada. Inicie o Ollama '
        'no computador e tente novamente.';
  }

  void _fail(int session, String message) {
    if (!_active(session)) return;
    _deadline?.cancel();
    _finalWait?.cancel();
    _state = KayState.idle;
    wakeEnabled = false;
    _waitingForWake = false;
    _wakeTimer?.cancel();
    if (_wakeUsed) unawaited(_quiet(_wakeWord.stop));
    error = message;
    _update();
  }

  Future<void> _quiet(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      /* Best effort on lifecycle cleanup. */
    }
  }

  Future<void> cancel({bool disableWake = true}) async {
    ++_session;
    if (disableWake) wakeEnabled = false;
    _wakeTimer?.cancel();
    _waitingForWake = false;
    _deadline?.cancel();
    _finalWait?.cancel();
    // Cancel any in-flight AI request
    final pendingAi = _pendingAiRequest;
    if (pendingAi != null && !pendingAi.isCompleted) {
      // Complete the future so _answerWithAi can exit cleanly.
      // The result will be ignored because _active(session) is now false.
      pendingAi.complete();
    }
    _pendingAiRequest = null;
    _starting = false;
    _stopping = true;
    transcript = '';
    response = '';
    error = null;
    _state = KayState.idle;
    _update();
    if (_wakeUsed) {
      if (disableWake) {
        await _quiet(_wakeWord.dispose);
      } else {
        await _quiet(_wakeWord.stop);
      }
    }
    await _quiet(_voice.cancelListening);
    await _quiet(_voice.stopSpeaking);
    _stopping = false;
    _update();
    _scheduleWake();
  }

  @override
  void dispose() {
    _disposed = true;
    _wakeTimer?.cancel();
    if (_wakeUsed) unawaited(_quiet(_wakeWord.dispose));
    ++_session;
    _deadline?.cancel();
    _finalWait?.cancel();
    final pendingAi = _pendingAiRequest;
    if (pendingAi != null && !pendingAi.isCompleted) {
      pendingAi.complete();
    }
    _pendingAiRequest = null;
    unawaited(_quiet(_voice.cancelListening));
    unawaited(_quiet(_voice.stopSpeaking));
    super.dispose();
  }
}
