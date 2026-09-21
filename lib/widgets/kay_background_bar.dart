import 'package:flutter/material.dart';

import '../theme/kay_theme.dart';

/// Fixed bottom control for activating/deactivating Kay in background.
///
/// Handles three visual states:
/// * inactive — a calm "Ativar Kay em segundo plano" action;
/// * inactive with missing permissions — shows what is missing plus a shortcut
///   to the Permissões screen;
/// * active — mic glyph, "Kay ativo em segundo plano", notification state and
///   a quick Desligar action.
class BackgroundActivationBar extends StatelessWidget {
  const BackgroundActivationBar({
    super.key,
    required this.active,
    this.busy = false,
    required this.notificationsMissing,
    required this.micMissing,
    required this.onToggle,
    this.onOpenPermissions,
  });

  final bool active;
  final bool busy;
  final bool notificationsMissing;
  final bool micMissing;
  final VoidCallback onToggle;
  final VoidCallback? onOpenPermissions;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(left: 12, right: 12, bottom: 8, top: 4),
      child: Container(
        decoration: BoxDecoration(
          color: KayPalette.bottomBar,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KayPalette.border),
        ),
        child: AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: active
              ? _ActiveView(
                  key: const ValueKey('bg_active'),
                  busy: busy,
                  notificationsGranted: !notificationsMissing,
                  onToggle: onToggle,
                )
              : _InactiveView(
                  key: const ValueKey('bg_inactive'),
                  notificationsMissing: notificationsMissing,
                  micMissing: micMissing,
                  onToggle: onToggle,
                  onOpenPermissions: onOpenPermissions,
                ),
        ),
      ),
    );
  }
}

class _InactiveView extends StatelessWidget {
  const _InactiveView({
    super.key,
    required this.notificationsMissing,
    required this.micMissing,
    required this.onToggle,
    required this.onOpenPermissions,
  });

  final bool notificationsMissing;
  final bool micMissing;
  final VoidCallback onToggle;
  final VoidCallback? onOpenPermissions;

  @override
  Widget build(BuildContext context) {
    final missingPerm = micMissing || notificationsMissing;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const ValueKey('background_toggle'),
            onPressed: onToggle,
            style: FilledButton.styleFrom(
              backgroundColor: KayPalette.accent.withValues(alpha: 0.14),
              foregroundColor: KayPalette.accentGlow,
              side: const BorderSide(color: KayPalette.accent),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.brightness_6_outlined, size: 20),
            label: const Text('Ativar Kay em segundo plano'),
          ),
          if (missingPerm) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: KayPalette.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (micMissing)
                        const _MissingText(
                          text: 'Permissão de microfone pendente.',
                        ),
                      if (notificationsMissing)
                        const _MissingText(
                          text: 'Permissão de notificação pendente.',
                        ),
                    ],
                  ),
                ),
                if (onOpenPermissions != null)
                  TextButton(
                    onPressed: onOpenPermissions,
                    child: const Text('Abrir'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MissingText extends StatelessWidget {
  const _MissingText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          text,
          style: const TextStyle(
            color: KayPalette.warning,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      );
}

class _ActiveView extends StatelessWidget {
  const _ActiveView({
    super.key,
    required this.busy,
    required this.notificationsGranted,
    required this.onToggle,
  });

  final bool busy;
  final bool notificationsGranted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: KayPalette.accent,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 14 + (busy ? 3 : 0),
              child: const Icon(Icons.mic_none, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kay ativo em segundo plano',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: KayPalette.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      notificationsGranted
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      size: 13,
                      color: notificationsGranted
                          ? KayPalette.success
                          : KayPalette.warning,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      notificationsGranted
                          ? 'Notificação ativa'
                          : 'Notificação pendente',
                      style: TextStyle(
                        color: notificationsGranted
                            ? KayPalette.success
                            : KayPalette.warning,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              foregroundColor: KayPalette.textSecondary,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.power_settings_new, size: 16),
            label: const Text('Desligar'),
          ),
        ],
      ),
    );
  }
}