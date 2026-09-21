import 'package:flutter/material.dart';

import '../controllers/kay_controller.dart';
import '../models/kay_state.dart';
import '../services/conversation_memory.dart';
import '../theme/kay_theme.dart';
import '../widgets/kay_core.dart';

/// Main "Conversa" tab — the face of Kay.
///
/// Layout: the K sits on top as the calm centerpiece; below it the state
/// indicator, the live transcript/response exchange and the primary action.
/// Everything scrolls so enlarged text and small screens never overflow.
class ConversaScreen extends StatefulWidget {
  const ConversaScreen({super.key, required this.controller});
  final KayController controller;

  @override
  State<ConversaScreen> createState() => _ConversaScreenState();
}

class _ConversaScreenState extends State<ConversaScreen> {
  KayController get controller => widget.controller;

  bool get _busy =>
      controller.state != KayState.idle || controller.busy || controller.error != null;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        return LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (bounds.maxHeight - 32).clamp(0, double.infinity),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── K central ────────────────────────────────
                      SizedBox(
                        height: (bounds.maxHeight * 0.34).clamp(140, 260),
                        child: Center(
                          child: KayCore(
                            state: c.state,
                            onTap: _busy
                                ? () => c.cancel(disableWake: false)
                                : c.onTap,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // ── State pill ───────────────────────────────
                      _StatePill(
                        state: c.state,
                        busy: c.busy,
                        waitingForWake: c.waitingForWake,
                      ),
                      const SizedBox(height: 10),

                      // ── Hint / context line ──────────────────────
                      AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: Text(
                          _hintFor(c),
                          key: ValueKey(_hintFor(c)),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: KayPalette.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),

                      // ── Conversation visual history ────────────
                      if (c.hasConversation ||
                          c.transcript.isNotEmpty ||
                          c.response.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _ConversationLog(controller: c),
                      ],

                      if (c.state == KayState.thinking) ...[
                        const SizedBox(height: 14),
                        const _ThinkingIndicator(),
                      ],

                      // ── Errors (live region) ────────────────────
                      if (c.error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: KayPalette.error.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: KayPalette.error.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: KayPalette.error,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    c.error!,
                                    style: const TextStyle(
                                      color: KayPalette.error,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // ── Primary action / cancel ──────────────────
                      const SizedBox(height: 24),
                      _PrimaryActions(controller: c, busy: _busy),

                      // ── Clear conversation ──────────────────────
                      if (c.hasConversation)
                        Align(
                          alignment: Alignment.center,
                          child: TextButton.icon(
                            onPressed: c.busy ? null : c.clearConversation,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Limpar conversa'),
                            style: TextButton.styleFrom(
                              foregroundColor: KayPalette.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _hintFor(KayController c) {
    if (c.busy) return 'Preparando microfone…';
    return switch (c.state) {
      KayState.idle => c.waitingForWake
          ? 'Diga "Kay" e aguarde minha resposta para dar seu comando'
          : 'Toque no K ou no botão abaixo para falar',
      KayState.listening => 'Estou ouvindo. Toque para terminar.',
      KayState.thinking => 'Preparando resposta…',
      KayState.speaking => 'Toque para interromper',
    };
  }
}

// ── State pill ────────────────────────────────────────────────────
class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.state,
    required this.busy,
    required this.waitingForWake,
  });

  final KayState state;
  final bool busy;
  final bool waitingForWake;

@override
  Widget build(BuildContext context) {
    final (label, color, icon) = _describe();
    return Semantics(
      liveRegion: busy || state == KayState.listening,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color, IconData) _describe() {
    if (busy) {
      return ('Preparando', KayPalette.accent, Icons.sync);
    }
    return switch (state) {
      KayState.idle => waitingForWake
          ? ('Aguardando "Kay"', KayPalette.warning, Icons.hearing_outlined)
          : ('Em repouso', KayPalette.kIdle, Icons.circle_outlined),
      KayState.listening => ('Ouvindo', KayPalette.kListening, Icons.mic),
      KayState.thinking => ('Processando', KayPalette.kThinking, Icons.auto_awesome),
      KayState.speaking => ('Falando', KayPalette.kSpeaking, Icons.record_voice_over),
    };
  }
}

// ── Conversation log ───────────────────────────────────────────────
class _ConversationLog extends StatelessWidget {
  const _ConversationLog({required this.controller});
  final KayController controller;

  @override
  Widget build(BuildContext context) {
    final messages = controller.memorySnap;
    final activeUser = controller.transcript;
    final activeKay = controller.response;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final msg in messages) _MessageBubble(message: msg),
        if (activeUser.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Bubble(
            role: 'user',
            text: activeUser,
            label: 'Você',
          ),
        ],
        if (activeKay.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Bubble(role: 'assistant', text: activeKay, label: 'Kay'),
        ],
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        _Bubble(
          role: message.role == 'user' ? 'user' : 'assistant',
          text: message.content,
          label: isUser ? 'Você' : 'Kay',
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.role, required this.text, required this.label});
  final String role;
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    final accent = isUser ? KayPalette.kListening : KayPalette.kSpeaking;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: isUser
              ? KayPalette.surfaceAlt
              : KayPalette.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: accent.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                color: KayPalette.textPrimary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Thinking indicator ─────────────────────────────────────────────
class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Kay está processando',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: KayPalette.kThinking.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Preparando resposta…', style: TextStyle(color: KayPalette.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Primary actions ────────────────────────────────────────────────
class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.controller, required this.busy});
  final KayController controller;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final active = controller.state != KayState.idle || busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: active
              ? null
              : controller.waitingForWake
                  ? null
                  : controller.onTap,
          style: FilledButton.styleFrom(
            backgroundColor: KayPalette.accent.withValues(alpha: 0.16),
            foregroundColor: KayPalette.accentGlow,
            side: const BorderSide(color: KayPalette.accent),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.mic_none, size: 22),
          label: Text(
            controller.waitingForWake
                ? 'Aguardando você me chamar'
                : 'Iniciar conversa',
          ),
        ),
        if (active) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => controller.cancel(disableWake: false),
            style: OutlinedButton.styleFrom(
              foregroundColor: KayPalette.textSecondary,
              side: const BorderSide(color: KayPalette.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.stop_circle_outlined, size: 20),
            label: const Text('Cancelar'),
          ),
        ],
      ],
    );
  }
}