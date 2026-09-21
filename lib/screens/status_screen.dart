import 'package:flutter/material.dart';

import '../controllers/kay_controller.dart';
import '../services/assistant_role_service.dart';
import '../services/ollama_ai_service.dart';
import '../services/permission_service.dart';
import '../services/preferences_service.dart';
import '../services/system_status_service.dart';
import '../theme/kay_theme.dart';

/// Status tab — a calm overview of the assistant, without technical logs.
class StatusScreen extends StatefulWidget {
  const StatusScreen({
    super.key,
    this.permissions,
    this.roleService,
    this.systemStatus,
    this.prefs,
    this.controller,
  });

  final AppPermissions? permissions;
  final AssistantRoleService? roleService;
  final SystemStatusService? systemStatus;
  final PreferencesService? prefs;
  final KayController? controller;

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  late final AppPermissions _permissions =
      widget.permissions ?? DeviceAppPermissions();
  late final AssistantRoleService _role =
      widget.roleService ?? AssistantRoleService();
  late final SystemStatusService _system =
      widget.systemStatus ?? SystemStatusService();
  late final PreferencesService _prefs =
      widget.prefs ?? PreferencesService();

  KayController? get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (widget.prefs == null) _prefs.init();
  }

  @override
  Widget build(BuildContext context) {
    final listener = controller;
    final list = _StatusList(
      permissions: _permissions,
      role: _role,
      system: _system,
      prefs: _prefs,
      controller: controller,
    );
    return listener == null
        ? list
        : ListenableBuilder(listenable: listener, builder: (_, _) => list);
  }
}

class _StatusList extends StatelessWidget {
  const _StatusList({
    required this.permissions,
    required this.role,
    required this.system,
    required this.prefs,
    this.controller,
  });

  final AppPermissions permissions;
  final AssistantRoleService role;
  final SystemStatusService system;
  final PreferencesService prefs;
  final KayController? controller;

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
                  _AssistantRow(role: role),
                  const SizedBox(height: 10),
                  _AsyncRow(
                    label: 'Serviço de voz ativo',
                    subtitle: 'O Android reconhece o Kay como serviço de voz.',
                    future: () => system.isVoiceServiceActive().then(
                          (v) => _Val(v, v ? 'Sim' : 'Não'),
                        ),
                  ),
                  const SizedBox(height: 10),
                  _AsyncRow(
                    label: 'Kay em segundo plano',
                    subtitle: 'Estado do serviço de escuta contínua.',
                    future: () => system.isBackgroundRunning().then(
                          (v) => _Val(v, v ? 'Ativo' : 'Inativo'),
                        ),
                  ),
                  const SizedBox(height: 10),
                  _AsyncRow(
                    label: 'Vosk',
                    subtitle: 'Detector local da palavra "Kay".',
                    future: () => system.isVoskReady().then(
                          (v) => _Val(v, v ? 'Pronto' : 'Parado'),
                        ),
                  ),
                  const SizedBox(height: 10),
                  _AsyncRow(
                    label: 'Microfone',
                    subtitle: 'Pronto para captar sua voz.',
                    future: () => permissions.microphoneStatus().then(
                          (g) => _Val(
                            g == PermissionGrant.granted,
                            g == PermissionGrant.granted
                                ? 'Disponível'
                                : 'Indisponível',
                          ),
                        ),
                  ),
                  const SizedBox(height: 10),
                  _OllamaRow(prefs: prefs),
                  const SizedBox(height: 10),
                  _Row(
                    label: 'Modelo atual',
                    subtitle: prefs.aiModel,
                    ok: null,
                    trailing: const Text(
                      '—',
                      style: TextStyle(color: KayPalette.textMuted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Row(
                    label: 'Última interação',
                    subtitle: _lastInteraction(),
                    ok: controller?.lastActivity == null ? null : true,
                    trailing: Text(
                      _lastInteraction(),
                      style: const TextStyle(
                        color: KayPalette.kIdle,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Row(
                    label: 'Último erro',
                    subtitle: controller?.error ?? 'Nenhum erro recente',
                    ok: controller?.error == null,
                    trailing: Text(
                      controller?.error ?? 'Nenhum',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: controller?.error == null
                            ? KayPalette.success
                            : KayPalette.error,
                        fontWeight: FontWeight.w500,
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

  String _lastInteraction() {
    final at = controller?.lastActivity;
    if (at == null) return 'Ainda não conversamos';
    final now = DateTime.now();
    final local = at.toLocal();
    if (now.difference(local).inMinutes < 1) return 'Agora há pouco';
    if (now.difference(local).inHours < 1) {
      return 'Há ${now.difference(local).inMinutes} min';
    }
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return 'Hoje às $h:$m';
  }
}

/// A value plus an "ok" flag (true=green, false=amber, null=neutral).
class _Val {
  const _Val(this.ok, this.text);
  final bool ok;
  final String text;
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.subtitle,
    required this.trailing,
    this.ok,
  });

  final String label;
  final String subtitle;
  final Widget trailing;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final statusColor = ok == true
        ? KayPalette.success
        : ok == false
            ? KayPalette.warning
            : KayPalette.textMuted;
    final statusIcon = ok == true
        ? Icons.check_circle_outline
        : ok == false
            ? Icons.info_outline
            : Icons.help_outline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
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
            const SizedBox(width: 12),
            if (ok == null) ...[
              trailing,
            ] else ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 15, color: statusColor),
                  const SizedBox(width: 5),
                  trailing,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AsyncRow extends StatelessWidget {
  const _AsyncRow({
    required this.label,
    required this.subtitle,
    required this.future,
  });

  final String label;
  final String subtitle;
  final Future<_Val> Function() future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Val>(
      future: future(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return _Row(
            label: label,
            subtitle: subtitle,
            ok: null,
            trailing: const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final val = snap.data!;
        return _Row(
          label: label,
          subtitle: subtitle,
          ok: val.ok,
          trailing: Text(
            val.text,
            style: const TextStyle(
              color: KayPalette.kIdle,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}

class _AssistantRow extends StatelessWidget {
  const _AssistantRow({required this.role});
  final AssistantRoleService role;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssistantRoleStatus>(
      future: role.getStatus(),
      builder: (context, snap) {
        final s = snap.data ?? AssistantRoleStatus.unknown;
        final ok = switch (s) {
          AssistantRoleStatus.held => true,
          AssistantRoleStatus.notHeld => false,
          _ => null,
        };
        final text = switch (s) {
          AssistantRoleStatus.held => 'Sim',
          AssistantRoleStatus.notHeld => 'Não',
          AssistantRoleStatus.unavailable => 'Indisponível',
          AssistantRoleStatus.unknown => 'Verificando…',
        };
        return _Row(
          label: 'Kay como assistente padrão',
          subtitle: 'Segure o botão Home para ativar o Kay fora do app.',
          ok: ok,
          trailing: Text(
            text,
            style: const TextStyle(
              color: KayPalette.kIdle,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}

class _OllamaRow extends StatelessWidget {
  const _OllamaRow({required this.prefs});
  final PreferencesService prefs;

  @override
  Widget build(BuildContext context) {
    final service = OllamaAiService(baseUrl: prefs.aiUrl, model: prefs.aiModel);
    return FutureBuilder<bool>(
      future: service.ping(),
      builder: (context, snap) {
        final ok = snap.hasData ? snap.data : null;
        final text = switch (ok) {
          true => 'Conectado',
          false => 'Desconectado',
          null => 'Verificando…',
        };
        return _Row(
          label: 'Ollama',
          subtitle: 'Servidor local de inteligência. ${prefs.aiUrl}',
          ok: ok,
          trailing: Text(
            text,
            style: const TextStyle(
              color: KayPalette.kIdle,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}