import 'package:flutter/material.dart';

import '../services/assistant_role_service.dart';
import '../services/permission_service.dart';
import '../services/system_status_service.dart';
import '../theme/kay_theme.dart';

/// Permissões tab — a calm list of what Kay needs and how to grant it.
class PermissoesScreen extends StatefulWidget {
  const PermissoesScreen({
    super.key,
    this.permissions,
    this.roleService,
    this.systemStatus,
  });

  final AppPermissions? permissions;
  final AssistantRoleService? roleService;
  final SystemStatusService? systemStatus;

  @override
  State<PermissoesScreen> createState() => _PermissoesScreenState();
}

class _PermissoesScreenState extends State<PermissoesScreen> {
  late final AppPermissions _permissions =
      widget.permissions ?? DeviceAppPermissions();
  late final AssistantRoleService _role =
      widget.roleService ?? AssistantRoleService();
  late final SystemStatusService _system =
      widget.systemStatus ?? SystemStatusService();

  Future<void> _reload() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (mounted) setState(() {});
  }

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
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Permissões são pedidas apenas quando você age. '
                      'Você revoga ou concede pelas telas do Android.',
                      style: TextStyle(
                        color: KayPalette.textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  _MicrophoneTile(permissions: _permissions),
                  const SizedBox(height: 10),
                  _NotificationTile(permissions: _permissions),
                  const SizedBox(height: 10),
                  _AssistantTile(role: _role),
                  const SizedBox(height: 10),
                  _BackgroundTile(system: _system, onReload: _reload),
                  const SizedBox(height: 10),
                  const _NetworkTile(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual state used by the list items.
enum AccessState { granted, pending, blocked, unknown }

(AccessState, String) _mapGrant(PermissionGrant grant) => switch (grant) {
      PermissionGrant.granted => (AccessState.granted, 'Concedida'),
      PermissionGrant.denied => (AccessState.blocked, 'Bloqueada'),
      PermissionGrant.unavailable => (AccessState.unknown, 'Indisponível'),
    };

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.stateLabel,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AccessState state;
  final String stateLabel;
  final String actionLabel;
  final VoidCallback onAction;

  (Color, IconData) get _look => switch (state) {
        AccessState.granted => (KayPalette.success, Icons.check_circle_outline),
        AccessState.pending => (KayPalette.warning, Icons.schedule),
        AccessState.blocked => (KayPalette.error, Icons.cancel_outlined),
        AccessState.unknown => (KayPalette.textMuted, Icons.help_outline),
      };

  @override
  Widget build(BuildContext context) {
    final (color, stateIcon) = _look;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: KayPalette.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: KayPalette.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: KayPalette.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(stateIcon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    stateLabel,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (state != AccessState.granted) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text(actionLabel),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: KayPalette.accentGlow,
                    side: const BorderSide(color: KayPalette.border),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MicrophoneTile extends StatelessWidget {
  const _MicrophoneTile({required this.permissions});
  final AppPermissions permissions;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PermissionGrant>(
      future: permissions.microphoneStatus(),
      builder: (context, snap) {
        final grant = snap.data ?? PermissionGrant.unavailable;
        final (state, label) = _mapGrant(grant);
        return _Row(
          icon: Icons.mic_none,
          title: 'Microfone',
          subtitle: 'Usado para ouvir você e detectar a palavra "Kay".',
          state: state,
          stateLabel: label,
          actionLabel: 'Abrir permissões do app',
          onAction: permissions.openAppSettings,
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.permissions});
  final AppPermissions permissions;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PermissionGrant>(
      future: permissions.notificationStatus(),
      builder: (context, snap) {
        final grant = snap.data ?? PermissionGrant.unavailable;
        final (state, label) = _mapGrant(grant);
        return _Row(
          icon: Icons.notifications_none,
          title: 'Notificações',
          subtitle: 'Mantém você informado quando o Kay está ativo.',
          state: state,
          stateLabel: label,
          actionLabel: 'Abrir config. de notificações',
          onAction: permissions.openNotificationSettings,
        );
      },
    );
  }
}

class _AssistantTile extends StatefulWidget {
  const _AssistantTile({required this.role});
  final AssistantRoleService role;

  @override
  State<_AssistantTile> createState() => _AssistantTileState();
}

class _AssistantTileState extends State<_AssistantTile> {
  late Future<AssistantRoleStatus> _status = widget.role.getStatus();
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    await widget.role.requestRole();
    if (mounted) {
      setState(() {
        _requesting = false;
        _status = widget.role.getStatus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssistantRoleStatus>(
      future: _status,
      builder: (context, snap) {
        final s = snap.data ?? AssistantRoleStatus.unknown;
        final (state, label) = switch (s) {
          AssistantRoleStatus.held => (AccessState.granted, 'Concedida'),
          AssistantRoleStatus.notHeld => (AccessState.pending, 'Pendente'),
          AssistantRoleStatus.unavailable => (AccessState.unknown, 'Indisponível'),
          AssistantRoleStatus.unknown => (AccessState.unknown, 'Verificando…'),
        };
        final showRequest = s == AssistantRoleStatus.notHeld;
        return _Row(
          icon: Icons.assistant_outlined,
          title: 'Assistente padrão',
          subtitle: 'Permite abrir o Kay segurando o botão Home.',
          state: state,
          stateLabel: label,
          actionLabel: showRequest
              ? (_requesting ? 'Abrindo…' : 'Definir como assistente padrão')
              : 'Abrir configuração do assistente',
          onAction: showRequest
              ? (_requesting ? () {} : _request)
              : widget.role.openAssistantSettings,
        );
      },
    );
  }
}

class _BackgroundTile extends StatelessWidget {
  const _BackgroundTile({required this.system, required this.onReload});
  final SystemStatusService system;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: system.isBackgroundRunning(),
      builder: (context, snap) {
        final running = snap.data ?? false;
        return _Row(
          icon: Icons.brightness_6_outlined,
          title: 'Serviço em segundo plano',
          subtitle: 'O Kay fica ativo mesmo com o app aberto em outra aba '
              'ou minimizado.',
          state: running ? AccessState.granted : AccessState.pending,
          stateLabel: running ? 'Ativo' : 'Inativo',
          actionLabel: 'Abrir configurações do app',
          onAction: onReload,
        );
      },
    );
  }
}

class _NetworkTile extends StatelessWidget {
  const _NetworkTile();

  @override
  Widget build(BuildContext context) {
    // INTERNET is a normal Android permission, granted at install time.
    return const _Row(
      icon: Icons.wifi,
      title: 'Acesso à rede',
      subtitle: 'Usado para falar com o servidor de IA local.',
      state: AccessState.granted,
      stateLabel: 'Concedida',
      actionLabel: '',
      onAction: _noop,
    );
  }

  static void _noop() {}
}