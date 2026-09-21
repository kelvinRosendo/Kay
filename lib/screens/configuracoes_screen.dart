import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../controllers/kay_controller.dart';
import '../services/ollama_ai_service.dart';
import '../services/preferences_service.dart';
import '../services/system_status_service.dart';
import '../services/voice_selection_service.dart';
import '../theme/kay_theme.dart';
import '../widgets/voice_picker.dart';
class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({
    super.key,
    required this.prefs,
    required this.controller,
    this.systemStatus,
  });

  final PreferencesService prefs;
  final KayController controller;
  final SystemStatusService? systemStatus;

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  late final SystemStatusService _system =
      widget.systemStatus ?? SystemStatusService();

  PreferencesService get prefs => widget.prefs;
  KayController get controller => widget.controller;

  void _applyTiming() {
    controller.setTiming(
      initialWait: Duration(seconds: prefs.waitSeconds),
      silenceAfterWarning: Duration(seconds: prefs.silenceSeconds),
    );
    _system.setWaits(
      waitMs: prefs.waitSeconds * 1000,
      silenceMs: prefs.silenceSeconds * 1000,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => LayoutBuilder(
        builder: (context, bounds) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (bounds.maxHeight - 44).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('Voz'),
                    _VoiceCard(prefs: prefs),
                    const SizedBox(height: 22),
                    const _SectionTitle('Tempo de resposta'),
                    _TimingCard(prefs: prefs, onChanged: _applyTiming),
                    const SizedBox(height: 22),
                    const _SectionTitle('Texto'),
                    _TextCard(prefs: prefs),
                    const SizedBox(height: 22),
                    const _SectionTitle('Personalização'),
                    _PersonalizationCard(prefs: prefs, controller: controller),
                    const SizedBox(height: 22),
                    const _SectionTitle('IA'),
                    _AiCard(prefs: prefs),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: KayPalette.textMuted,
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      );
}

// ── Voz ────────────────────────────────────────────────────────────
class _VoiceCard extends StatefulWidget {
  const _VoiceCard({required this.prefs});
  final PreferencesService prefs;

  @override
  State<_VoiceCard> createState() => _VoiceCardState();
}

class _VoiceCardState extends State<_VoiceCard> {
  final _selection = VoiceSelectionService();
  final _tts = FlutterTts();
  String? _current;
  String? _previewError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? selected;
    try {
      selected = await _selection.current();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _current = selected;
      _loading = false;
    });
  }

  Future<void> _openPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: const VoicePicker(),
      ),
    );
    await _load();
  }

  Future<void> _preview() async {
    setState(() => _previewError = null);
    try {
      await _tts.stop();
      await _tts.setLanguage('pt-BR');
      final selected = await _selection.current();
      if (selected != null) {
        await _tts.setVoice({'name': selected, 'locale': 'pt-BR'});
      }
      await _tts.setPitch(.82);
      await _tts.setSpeechRate(.48);
      await _tts.speak('Olá. Eu sou o Kay. Esta é a minha voz.');
    } catch (_) {
      if (mounted) {
        setState(() => _previewError = 'Não foi possível reproduzir a voz.');
      }
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _loading
        ? 'Carregando…'
        : (_current == null ? 'Padrão do aparelho' : _current!);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over, color: KayPalette.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Voz atual',
                      style: TextStyle(color: KayPalette.textSecondary),
                    ),
                    Text(
                      label,
                      key: const ValueKey('current_voice'),
                      style: const TextStyle(
                        color: KayPalette.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Todas as vozes usam um tom grave e calmo.',
            style: TextStyle(color: KayPalette.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _openPicker,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Escolher voz'),
              ),
              OutlinedButton.icon(
                onPressed: _preview,
                icon: const Icon(Icons.volume_up_outlined, size: 18),
                label: const Text('Ouvir prévia'),
              ),
            ],
          ),
          if (_previewError != null) ...[
            const SizedBox(height: 8),
            Text(
              _previewError!,
              style: const TextStyle(color: KayPalette.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tempo de resposta ─────────────────────────────────────────────
class _TimingCard extends StatelessWidget {
  const _TimingCard({required this.prefs, required this.onChanged});
  final PreferencesService prefs;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Espera inicial para começar a falar',
            style: TextStyle(color: KayPalette.textSecondary),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: prefs.waitSeconds.toDouble(),
                  min: 10,
                  max: 30,
                  divisions: 20,
                  label: '${prefs.waitSeconds}s',
                  onChanged: (v) {
                    prefs.waitSeconds = v.round();
                    onChanged();
                  },
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${prefs.waitSeconds}s',
                  key: const ValueKey('wait_seconds_label'),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: KayPalette.accentGlow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Espera depois do aviso de silêncio',
            style: TextStyle(color: KayPalette.textSecondary),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: prefs.silenceSeconds.toDouble(),
                  min: 3,
                  max: 15,
                  divisions: 12,
                  label: '${prefs.silenceSeconds}s',
                  onChanged: (v) {
                    prefs.silenceSeconds = v.round();
                    onChanged();
                  },
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${prefs.silenceSeconds}s',
                  key: const ValueKey('silence_seconds_label'),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: KayPalette.accentGlow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'A espera inicial nunca fica abaixo de 10 segundos. As mudanças '
            'valem para a conversa e para o Kay em segundo plano.',
            style: TextStyle(color: KayPalette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Texto ──────────────────────────────────────────────────────────
class _TextCard extends StatelessWidget {
  const _TextCard({required this.prefs});
  final PreferencesService prefs;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tamanho da letra',
            style: TextStyle(color: KayPalette.textSecondary),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Pequeno')),
              ButtonSegment(value: 1, label: Text('Médio')),
              ButtonSegment(value: 2, label: Text('Grande')),
            ],
            selected: {prefs.textScale},
            onSelectionChanged: (sel) => prefs.textScale = sel.first,
            showSelectedIcon: false,
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? KayPalette.accentGlow
                    : KayPalette.textSecondary,
              ),
              side: WidgetStateProperty.all(
                const BorderSide(color: KayPalette.border),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'O tamanho se soma ao ajuste de texto do sistema.',
            style: TextStyle(color: KayPalette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Personalização ────────────────────────────────────────────────
class _PersonalizationCard extends StatefulWidget {
  const _PersonalizationCard({required this.prefs, required this.controller});
  final PreferencesService prefs;
  final KayController controller;

  @override
  State<_PersonalizationCard> createState() => _PersonalizationCardState();
}

class _PersonalizationCardState extends State<_PersonalizationCard> {
  late final TextEditingController _name =
      TextEditingController(text: widget.prefs.userName);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _syncController() {
    widget.controller.setUserName(
      widget.prefs.useNameInReplies ? widget.prefs.userName : null,
    );
  }

  void _save() {
    final value = _name.text.trim();
    if (value.length > 64) {
      _name.text = value.substring(0, 64);
      _name.selection = TextSelection.collapsed(offset: _name.text.length);
    }
    setState(() => _error = null);
    widget.prefs.userName = value;
    if (widget.prefs.useNameInReplies) _syncController();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = widget.prefs;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nome do usuário',
              style: TextStyle(color: KayPalette.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('user_name_field'),
              controller: _name,
              maxLength: 64,
              onSubmitted: (_) => _save(),
              onChanged: (_) {
                if (mounted && _error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: 'Como você quer ser chamado',
                suffixIcon: _name.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.check, size: 20),
                        tooltip: 'Salvar nome',
                        onPressed: _save,
                      ),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar meu nome nas respostas'),
              subtitle: const Text(
                'O Kay pode chamar você pelo nome nas conversas. O nome nunca '
                'faz parte dos comandos locais.',
              ),
              value: prefs.useNameInReplies,
              onChanged: (v) {
                prefs.useNameInReplies = v;
                _syncController();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── IA ─────────────────────────────────────────────────────────────
class _AiCard extends StatefulWidget {
  const _AiCard({required this.prefs});
  final PreferencesService prefs;

  @override
  State<_AiCard> createState() => _AiCardState();
}

class _AiCardState extends State<_AiCard> {
  late final TextEditingController _url =
      TextEditingController(text: widget.prefs.aiUrl);
  late final TextEditingController _model =
      TextEditingController(text: widget.prefs.aiModel);
  String? _urlError;
  String? _status;
  bool _testing = false;

  PreferencesService get prefs => widget.prefs;

  @override
  void dispose() {
    _url.dispose();
    _model.dispose();
    super.dispose();
  }

  String? _validatedUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Informe o endereço do servidor.';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return 'Use um endereço http:// ou https:// válido.';
    }
    return null;
  }

  void _save() {
    final url = _url.text.trim();
    final check = _validatedUrl(url);
    setState(() => _urlError = check);
    if (check != null) return;
    prefs.aiUrl = url;
    prefs.aiModel = _model.text.trim().isEmpty ? 'llama3.2:3b' : _model.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuração da IA salva.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _restore() {
    _url.text = PreferencesService.defaultAiUrl;
    _model.text = PreferencesService.defaultAiModel;
    setState(() {
      _urlError = null;
      _status = null;
    });
    prefs.aiUrl = PreferencesService.defaultAiUrl;
    prefs.aiModel = PreferencesService.defaultAiModel;
  }

  Future<void> _testConnection() async {
    final url = _url.text.trim();
    final check = _validatedUrl(url);
    setState(() {
      _urlError = check;
      _status = null;
    });
    if (check != null) return;
    setState(() => _testing = true);
    final service = OllamaAiService(baseUrl: url, model: _model.text.trim());
    final ok = await service.ping();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _status = ok
          ? 'Conexão com o servidor OK.'
          : 'Não consegui conectar. Verifique se o Ollama está ativo e na '
              'mesma rede.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Servidor Ollama',
            style: TextStyle(color: KayPalette.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('ai_url_field'),
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'http://192.168.0.10:11434',
              errorText: _urlError,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Modelo',
            style: TextStyle(color: KayPalette.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('ai_model_field'),
            controller: _model,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'llama3.2:3b'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check, size: 18),
                label: const Text('Testar conexão'),
              ),
              OutlinedButton.icon(
                onPressed: _testing ? null : _save,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Salvar'),
              ),
              TextButton.icon(
                onPressed: _testing ? null : _restore,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Restaurar padrão'),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _status!.startsWith('Conexão')
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 18,
                  color: _status!.startsWith('Conexão')
                      ? KayPalette.success
                      : KayPalette.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status!,
                    key: const ValueKey('ai_connection_status'),
                    style: const TextStyle(
                      color: KayPalette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Nenhuma chave secreta é usada. Apenas o texto das perguntas é '
            'enviado ao servidor local.',
            style: TextStyle(color: KayPalette.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}