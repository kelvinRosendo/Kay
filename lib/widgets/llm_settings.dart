import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../services/proxy_ai_service.dart';

class LlmSettings extends StatefulWidget {
  const LlmSettings({super.key, required this.prefs});
  final PreferencesService prefs;
  @override
  State<LlmSettings> createState() => _LlmSettingsState();
}

class _LlmSettingsState extends State<LlmSettings> {
  late final _url = TextEditingController(text: widget.prefs.proxyUrl);
  late final _token = TextEditingController(text: widget.prefs.proxyToken);
  String? _error;
  @override
  void dispose() { _url.dispose(); _token.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.prefs,
    builder: (context, _) => Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Usar IA na nuvem'),
          subtitle: const Text('Envia perguntas e histórico recente ao proxy e aos provedores. Desativado: Ollama local.'),
          value: widget.prefs.cloudEnabled,
          onChanged: (v) => widget.prefs.cloudEnabled = v,
        ),
        TextField(controller: _url, autocorrect: false,
          decoration: const InputDecoration(labelText: 'Endereço HTTPS do proxy Kay')),
        TextField(controller: _token, obscureText: true, autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Token de acesso do proxy (nesta sessão)')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: widget.prefs.llmProvider,
          decoration: const InputDecoration(labelText: 'Provedor'),
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('Automático')),
            DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
            DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
            DropdownMenuItem(value: 'groq', child: Text('Groq')),
          ],
          onChanged: (v) { if (v != null) widget.prefs.llmProvider = v; },
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () {
          final valid = ProxyAiService.validUrl(_url.text.trim()) && _token.text.trim().length >= 32;
          setState(() => _error = valid ? null : 'Informe uma URL HTTPS e um token de pelo menos 32 caracteres. Em debug, localhost HTTP é permitido.');
          if (!valid) return;
          widget.prefs.proxyUrl = _url.text.trim();
          widget.prefs.proxyToken = _token.text.trim();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proxy configurado para esta sessão.')));
        }, child: const Text('Salvar proxy')),
        if (_error != null) Text(_error!),
        const Text('Nunca cole chaves da OpenAI, Gemini ou Groq aqui. A escolha manual prioriza o provedor; em falha pode usar outro compatível autorizado pelo servidor.'),
      ]),
    )),
  );
}
