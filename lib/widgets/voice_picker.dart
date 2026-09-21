import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoicePicker extends StatefulWidget {
  const VoicePicker({super.key});
  @override
  State<VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends State<VoicePicker> {
  static const channel = MethodChannel('kay/voice');
  final tts = FlutterTts();
  List<Map<String, String>>? voices;
  String? selected;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final raw = await tts.getVoices;
      selected = await channel.invokeMethod<String>('get');
      final available = (raw as List).whereType<Map>().where(
        (v) => '${v['locale']}'.replaceAll('_', '-').toLowerCase() == 'pt-br',
      );
      final local = available
          .where((v) => '${v['name']}'.endsWith('-local'))
          .toList();
      final choices = local.isNotEmpty ? local : available.toList();
      choices.sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
      if (mounted) {
        setState(
          () => voices = choices
              .map((v) => {'name': '${v['name']}', 'locale': '${v['locale']}'})
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Não consegui carregar as vozes do aparelho.');
      }
    }
  }

  Future<void> preview(Map<String, String> voice) async {
    try {
      await tts.stop();
      await tts.setVoice(voice);
      await tts.setPitch(.82);
      await tts.setSpeechRate(.48);
      await tts.speak('Olá. Sou o Kay. Estou pronto para ajudar.');
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Não foi possível reproduzir esta voz.');
      }
    }
  }

  Future<void> choose(Map<String, String> voice) async {
    try {
      await tts.stop();
      await channel.invokeMethod<void>('set', {'name': voice['name']});
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = 'Não foi possível salvar a voz.');
    }
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Escolher voz do Kay',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ouça as opções em português e escolha a que preferir. Todas usam um tom mais grave.',
          ),
          if (error != null) Text(error!),
          if (voices == null && error == null)
            const CircularProgressIndicator(),
          if (voices?.isEmpty == true)
            const Text(
              'Instale uma voz em português nas configurações de texto para fala do celular.',
            ),
          for (var i = 0; i < (voices?.length ?? 0); i++) ...[
            const SizedBox(height: 16),
            Text(
              'Voz ${i + 1}${selected == voices![i]['name'] ? ' — atual' : ''}',
            ),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => preview(voices![i]),
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Ouvir'),
                ),
                FilledButton(
                  onPressed: () => choose(voices![i]),
                  child: const Text('Usar esta voz'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
