import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/kay_controller.dart';
import '../services/device_voice_service.dart';
import '../services/ollama_ai_service.dart';
import '../services/permission_service.dart';
import '../services/preferences_service.dart';
import '../services/system_status_service.dart';
import '../theme/kay_theme.dart';
import '../widgets/kay_background_bar.dart';
import 'conversa_screen.dart';
import 'configuracoes_screen.dart';
import 'permissoes_screen.dart';
import 'status_screen.dart';
import 'sobre_screen.dart';

enum KayPage { conversa, configuracoes, permissoes, status, sobre }

/// Application shell: top bar + sidebar navigation + the five tabs, with the
/// fixed background-activation control at the bottom.
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    this.prefs,
    this.controller,
    this.permissions,
    this.systemStatus,
  });

  final PreferencesService? prefs;
  final KayController? controller;
  final AppPermissions? permissions;
  final SystemStatusService? systemStatus;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late final PreferencesService _prefs;
  late final KayController _controller;
  late final AppPermissions _permissions;
  late final SystemStatusService _system;
  late bool _ownController;

  KayPage _currentPage = KayPage.conversa;
  bool _sidebarOpen = false;

  bool _micGranted = false;
  bool _notificationsGranted = false;
  bool _permissionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _ownController = widget.controller == null;
    _controller =
        widget.controller ??
        KayController(DeviceVoiceService(), ai: OllamaAiService());
    _prefs = widget.prefs ?? PreferencesService();
    _permissions = widget.permissions ?? DeviceAppPermissions();
    _system = widget.systemStatus ?? SystemStatusService();
    WidgetsBinding.instance.addObserver(this);

    if (widget.prefs == null) {
      _prefs.init().then((_) {
        if (mounted) {
          _applyPreferences();
          setState(() {});
        }
      });
    } else {
      _applyPreferences();
    }
    _refreshPermissions();
  }

  void _applyPreferences() {
    if (!_prefs.initialized) return;
    _controller.setTiming(
      initialWait: Duration(seconds: _prefs.waitSeconds),
      silenceAfterWarning: Duration(seconds: _prefs.silenceSeconds),
    );
    _system.setWaits(
      waitMs: _prefs.waitSeconds * 1000,
      silenceMs: _prefs.silenceSeconds * 1000,
    );
    _controller.setUserName(
      _prefs.useNameInReplies ? _prefs.userName : null,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
    if ((state == AppLifecycleState.inactive && !_controller.wakeEnabled) ||
        (state == AppLifecycleState.paused && !_controller.wakeEnabled) ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.cancel());
    }
  }

  Future<void> _refreshPermissions() async {
    final mic = await _permissions.microphoneStatus();
    final notif = await _permissions.notificationStatus();
    if (mounted) {
      setState(() {
        _micGranted = mic == PermissionGrant.granted;
        _notificationsGranted = notif == PermissionGrant.granted;
        _permissionsLoaded = true;
      });
    }
  }

  Future<void> _toggleBackground() async {
    if (_controller.wakeEnabled) {
      await _controller.setWakeEnabled(false);
    } else {
      if (!_micGranted) await _permissions.requestMicrophone();
      if (!_notificationsGranted) await _permissions.requestNotifications();
      await _refreshPermissions();
      if (!_micGranted) return;
      await _controller.setWakeEnabled(true);
    }
    await _refreshPermissions();
  }

  void _openPermissionsTab() {
    _navigateTo(KayPage.permissoes);
  }

  void _navigateTo(KayPage page) {
    setState(() {
      _currentPage = page;
      _sidebarOpen = false;
    });
  }

  String _titleFor(KayPage page) => switch (page) {
        KayPage.conversa => 'Conversa',
        KayPage.configuracoes => 'Configurações',
        KayPage.permissoes => 'Permissões',
        KayPage.status => 'Status',
        KayPage.sobre => 'Sobre o Kay',
      };

  Widget _pageFor(KayPage page) => switch (page) {
        KayPage.conversa => ConversaScreen(controller: _controller),
        KayPage.configuracoes => ConfiguracoesScreen(
            prefs: _prefs,
            controller: _controller,
            systemStatus: _system,
          ),
        KayPage.permissoes => PermissoesScreen(
            permissions: _permissions,
            systemStatus: _system,
          ),
        KayPage.status => StatusScreen(
            permissions: _permissions,
            systemStatus: _system,
            prefs: _prefs,
            controller: _controller,
          ),
        KayPage.sobre => const SobreScreen(),
      };

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final systemScale = mq.textScaler.scale(1.0);
    final scale = _prefs.initialized ? _prefs.textScaleFactor : 1.0;
    final effectiveScale = systemScale * scale;
    final safeBottom = mq.padding.bottom;

    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(effectiveScale),
        padding: mq.padding.copyWith(bottom: safeBottom),
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([_prefs, _controller]),
        builder: (context, _) => Scaffold(
          backgroundColor: KayPalette.background,
          body: Stack(
            children: [
              Column(
                children: [
                  _KayAppBar(
                    title: _titleFor(_currentPage),
                    onMenuTap: () =>
                        setState(() => _sidebarOpen = !_sidebarOpen),
                  ),
                  Expanded(child: _pageFor(_currentPage)),
                ],
              ),
              // ── Sidebar overlay ──────────────────────────────
              if (_sidebarOpen)
                GestureDetector(
                  onTap: () => setState(() => _sidebarOpen = false),
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.black54),
                ),
              // ── Sidebar ──────────────────────────────────────
              AnimatedPositioned(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: _sidebarOpen ? 0 : -280,
                top: 0,
                bottom: 0,
                width: 272,
                child: _KaySidebar(
                  current: _currentPage,
                  onNavigate: _navigateTo,
                  onClose: () => setState(() => _sidebarOpen = false),
                ),
              ),
              // ── Bottom background bar ────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BackgroundActivationBar(
                  active: _controller.wakeEnabled,
                  busy: _controller.busy,
                  micMissing: _permissionsLoaded && !_micGranted,
                  notificationsMissing:
                      _permissionsLoaded && !_notificationsGranted,
                  onToggle: _toggleBackground,
                  onOpenPermissions: _openPermissionsTab,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────
class _KayAppBar extends StatelessWidget {
  const _KayAppBar({required this.title, required this.onMenuTap});
  final String title;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: onMenuTap,
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Abrir menu lateral',
                iconSize: 24,
                color: KayPalette.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: KayPalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Sidebar ────────────────────────────────────────────────────
class _KaySidebar extends StatelessWidget {
  const _KaySidebar({
    required this.current,
    required this.onNavigate,
    required this.onClose,
  });

  final KayPage current;
  final ValueChanged<KayPage> onNavigate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
        color: KayPalette.sidebarBg,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    const Text(
                      'Kay',
                      style: TextStyle(
                        color: KayPalette.accentGlow,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                      iconSize: 20,
                      color: KayPalette.textMuted,
                      tooltip: 'Fechar menu lateral',
                    ),
                  ],
                ),
              ),
              const Divider(color: KayPalette.divider),
              const SizedBox(height: 8),
              _SidebarItem(
                icon: Icons.chat_bubble_outline,
                label: 'Conversa',
                selected: current == KayPage.conversa,
                onTap: () => onNavigate(KayPage.conversa),
              ),
              _SidebarItem(
                icon: Icons.tune_rounded,
                label: 'Configurações',
                selected: current == KayPage.configuracoes,
                onTap: () => onNavigate(KayPage.configuracoes),
              ),
              _SidebarItem(
                icon: Icons.shield_outlined,
                label: 'Permissões',
                selected: current == KayPage.permissoes,
                onTap: () => onNavigate(KayPage.permissoes),
              ),
              _SidebarItem(
                icon: Icons.monitor_heart_outlined,
                label: 'Status',
                selected: current == KayPage.status,
                onTap: () => onNavigate(KayPage.status),
              ),
              _SidebarItem(
                icon: Icons.info_outline,
                label: 'Sobre o Kay',
                selected: current == KayPage.sobre,
                onTap: () => onNavigate(KayPage.sobre),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Kay v1.0.0',
                  style: TextStyle(color: KayPalette.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: label,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Material(
            color: selected
                ? KayPalette.accent.withAlpha(20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: selected
                          ? KayPalette.accentGlow
                          : KayPalette.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected
                              ? KayPalette.textPrimary
                              : KayPalette.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (selected)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: KayPalette.accentGlow,
                          shape: BoxShape.circle,
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