import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/kay_controller.dart';
import '../services/assistant_role_service.dart';
import '../services/device_voice_service.dart';
import '../widgets/kay_core.dart';
import '../widgets/voice_picker.dart';
import '../models/kay_state.dart';
import '../services/ollama_ai_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.controller});
  final KayController? controller;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final _controller =
      widget.controller ??
      KayController(DeviceVoiceService(), ai: OllamaAiService());

  final _roleService = AssistantRoleService();
  AssistantRoleStatus _roleStatus = AssistantRoleStatus.unknown;
  bool _roleLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshRoleStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRoleStatus();
    }
    if ((state == AppLifecycleState.inactive && !_controller.wakeEnabled) ||
        (state == AppLifecycleState.paused && !_controller.wakeEnabled) ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshRoleStatus() async {
    final status = await _roleService.getStatus();
    if (mounted) setState(() => _roleStatus = status);
  }

  Future<void> _requestRole() async {
    if (_roleLoading) return;
    setState(() => _roleLoading = true);
    try {
      await _roleService.requestRole();
    } finally {
      if (mounted) {
        setState(() => _roleLoading = false);
        await _refreshRoleStatus();
      }
    }
  }

  Future<void> _chooseVoice() async {
    final restoreWake = _controller.wakeEnabled;
    if (restoreWake) await _controller.setWakeEnabled(false);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const VoicePicker(),
    );
    if (mounted && restoreWake) await _controller.setWakeEnabled(true);
  }

  String get _roleLabel => switch (_roleStatus) {
        AssistantRoleStatus.unknown => 'Verificando…',
        AssistantRoleStatus.unavailable =>
          'Assistente padrão não disponível nesta versão do Android',
        AssistantRoleStatus.held => 'Kay é o assistente padrão',
        AssistantRoleStatus.notHeld => 'Kay não é o assistente padrão',
      };

  IconData get _roleIcon => switch (_roleStatus) {
        AssistantRoleStatus.held => Icons.check_circle,
        AssistantRoleStatus.notHeld => Icons.info_outline,
        _ => Icons.help_outline,
      };

  Color get _roleColor => switch (_roleStatus) {
        AssistantRoleStatus.held => const Color(0xFFA1F0D2),
        AssistantRoleStatus.notHeld => const Color(0xFFFFC4AE),
        _ => const Color(0xFFB4C4CD),
      };

  bool get _showCancel =>
      _controller.state == KayState.listening ||
      _controller.state == KayState.thinking ||
      _controller.state == KayState.speaking;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, child) => LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (bounds.maxHeight - 48).clamp(0, double.infinity),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: (bounds.maxHeight * .43).clamp(160, 340),
                        width: double.infinity,
                        child: Center(
                          child: KayCore(
                            state: _controller.state,
                            onTap: _showCancel
                                ? () => _controller.cancel(disableWake: false)
                                : _controller.onTap,
                          ),
                        ),
                      ),
                      Text(
                        _controller.hint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB4C4CD)),
                      ),
                      const SizedBox(height: 16),

                      // ── Cancel button ──────────────────────────
                      if (_showCancel) ...[
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _controller.cancel(disableWake: false),
                          icon: const Icon(Icons.stop_circle, size: 20),
                          label: const Text('Cancelar'),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Assistant role card ──────────────────────
                      if (_roleStatus != AssistantRoleStatus.unknown) ...[
                        Card(
                          color: const Color(0xFF111520),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: _roleColor.withAlpha(50)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _roleIcon,
                                      color: _roleColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _roleLabel,
                                        style: TextStyle(
                                          color: _roleColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_roleStatus ==
                                    AssistantRoleStatus.notHeld) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _roleLoading
                                          ? null
                                          : _requestRole,
                                      icon: _roleLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.settings_voice),
                                      label: const Text(
                                        'Definir Kay como assistente padrão',
                                      ),
                                    ),
                                  ),
                                ],
                                if (_roleStatus ==
                                    AssistantRoleStatus.held) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Segure o botão HOME para ativar o Kay fora do app.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _roleColor.withAlpha(160),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Voice & wake controls ──────────────────
                      OutlinedButton.icon(
                        onPressed: _controller.busy ? null : _chooseVoice,
                        icon: const Icon(Icons.record_voice_over),
                        label: const Text('Escolher voz do Kay'),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ativar por "Kay"'),
                        subtitle: const Text(
                          'Modo ativo: mantenha a notificação do Kay visível. '
                          'Diga Kay, aguarde "Estou ouvindo" e fale o comando.',
                        ),
                        value: _controller.wakeEnabled,
                        onChanged:
                            _controller.wakeEnabled ||
                                (!_controller.busy &&
                                    _controller.state == KayState.idle)
                            ? _controller.setWakeEnabled
                            : null,
                      ),

                      // ── Clear conversation ──────────────────────
                      if (_controller.hasConversation) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _controller.busy
                                ? null
                                : _controller.clearConversation,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Limpar conversa'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFFC4AE),
                            ),
                          ),
                        ),
                      ],

                      if (_controller.transcript.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'VOCÊ',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            color: Color(0xFF87E6F7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _controller.transcript,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                      if (_controller.response.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'KAY',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            color: Color(0xFFA1F0D2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _controller.response,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (_controller.error != null) ...[
                        const SizedBox(height: 24),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _controller.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFC4AE),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
