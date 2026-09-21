import 'package:flutter/material.dart';

import '../theme/kay_theme.dart';

/// Sobre o Kay — a short, calm description of the assistant.
class SobreScreen extends StatelessWidget {
  const SobreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
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
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: KayPalette.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: KayPalette.accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'K',
                        style: TextStyle(
                          color: KayPalette.accentGlow,
                          fontSize: 52,
                          fontWeight: FontWeight.w300,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Kay',
                      style: TextStyle(
                        color: KayPalette.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Assistente pessoal local, calmo e discreto.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: KayPalette.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _AboutLine(
                            icon: Icons.mic_none,
                            text: 'Entende sua voz, transcreve e responde '
                                'falando em português.',
                          ),
                          SizedBox(height: 12),
                          _AboutLine(
                            icon: Icons.assistant_outlined,
                            text: 'Pode se tornar o assistente padrão, '
                                'acionado segurando o botão Home.',
                          ),
                          SizedBox(height: 12),
                          _AboutLine(
                            icon: Icons.memory,
                            text: 'A inteligência roda no seu servidor local '
                                '(Ollama). Nenhuma chave secreta é usada.',
                          ),
                          SizedBox(height: 12),
                          _AboutLine(
                            icon: Icons.privacy_tip_outlined,
                            text: 'O detector da palavra "Kay" é local e não '
                                'envia áudio à internet.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'Kay 1.0.0 • Sprint 9',
                      style: TextStyle(
                        color: KayPalette.textMuted,
                        fontSize: 12,
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
  }
}

class _AboutLine extends StatelessWidget {
  const _AboutLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: KayPalette.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: KayPalette.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      );
}