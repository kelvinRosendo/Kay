import 'package:flutter/material.dart';

/// Deep navy color palette for Kay — dark, calm, futuristic.
abstract final class KayPalette {
  // ── Background layers ──────────────────────────────────────
  static const background = Color(0xFF0B0E14);
  static const surface = Color(0xFF111621);
  static const surfaceAlt = Color(0xFF161C2A);
  static const sidebarBg = Color(0xFF0D1119);
  static const bottomBar = Color(0xFF0E1320);

  // ── Accent ─────────────────────────────────────────────────
  static const accent = Color(0xFF5B9DB5);
  static const accentSoft = Color(0xFF3A7A94);
  static const accentGlow = Color(0xFF7EC8E3);

  // ── Text ───────────────────────────────────────────────────
  static const textPrimary = Color(0xFFD6DEE6);
  static const textSecondary = Color(0xFF8A96A6);
  static const textMuted = Color(0xFF5A6577);

  // ── Semantic ───────────────────────────────────────────────
  static const success = Color(0xFF7ECBA1);
  static const warning = Color(0xFFE0C078);
  static const error = Color(0xFFD4887A);

  // ── K states ───────────────────────────────────────────────
  static const kIdle = Color(0xFFD6DEE6);
  static const kListening = Color(0xFF7EC8E3);
  static const kThinking = Color(0xFF9B8EC4);
  static const kSpeaking = Color(0xFF7ECBA1);

  // ── Dividers / borders ─────────────────────────────────────
  static const divider = Color(0xFF1E2636);
  static const border = Color(0xFF253040);
}

/// Tile-safe colors kept as opaque constants for widgets that render them
/// outside of a BuildContext (semantics, chips, indicators).
typedef K = KayPalette;

/// Returns the full [ThemeData] for Kay.
ThemeData buildKayTheme() {
  final base = ThemeData(brightness: Brightness.dark);

  return base.copyWith(
    scaffoldBackgroundColor: KayPalette.background,
    colorScheme: const ColorScheme.dark(
      surface: KayPalette.surface,
      onSurface: KayPalette.textPrimary,
      primary: KayPalette.accent,
      onPrimary: Colors.white,
      secondary: KayPalette.accentSoft,
      error: KayPalette.error,
    ),
    cardTheme: const CardThemeData(
      color: KayPalette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: KayPalette.border),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: KayPalette.sidebarBg,
      foregroundColor: KayPalette.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: KayPalette.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KayPalette.surface,
      indicatorColor: KayPalette.accent.withAlpha(30),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: KayPalette.textSecondary, fontSize: 12),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: KayPalette.surface,
      modalBackgroundColor: KayPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: KayPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: KayPalette.divider,
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.copyWith(
      bodyLarge: const TextStyle(color: KayPalette.textPrimary, fontSize: 16),
      bodyMedium: const TextStyle(color: KayPalette.textPrimary, fontSize: 14),
      bodySmall: const TextStyle(
        color: KayPalette.textSecondary,
        fontSize: 12,
      ),
      titleLarge: const TextStyle(
        color: KayPalette.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        color: KayPalette.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: const TextStyle(
        color: KayPalette.textMuted,
        fontSize: 11,
        letterSpacing: 1.5,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KayPalette.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KayPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KayPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KayPalette.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: KayPalette.textMuted),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: KayPalette.accent,
      inactiveTrackColor: KayPalette.border,
      thumbColor: KayPalette.accent,
      overlayColor: Color(0x205B9DB5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? KayPalette.accent
              : KayPalette.textMuted),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? KayPalette.accent.withAlpha(80)
              : KayPalette.border),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KayPalette.accent,
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}