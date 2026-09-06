import 'package:flutter/material.dart';

/// A neutral grey ground with a brass accent. The ground used to be blue-slate
/// — every surface carried its blue channel 20-40 points above its red one —
/// and that tint fought the brass instead of receding behind it. The greys
/// below keep the exact same dark-to-light order; only the hue is gone.
///
/// Material's seeded schemes cannot reproduce this — seeding from any hue
/// drags every role toward that hue — so every role is pinned explicitly here.
abstract final class AppColors {
  static const void_ = Color(0xFF0F0F0F);
  static const bg = Color(0xFF181818);
  static const panel = Color(0xFF1F1F1F);
  static const raise = Color(0xFF262626);
  static const rule = Color(0xFF303030);
  static const ink = Color(0xFFECECEC);
  static const inkSoft = Color(0xFF9A9A9A);

  /// Only ever used as `outline` — a non-text component, so the bar is WCAG
  /// 1.4.11 (3:1), not 4.5:1. A darker grey looked closer to the mockup but
  /// fell to 2.97:1 over `raise`; this one clears 3:1 over every surface.
  static const inkFaint = Color(0xFF787878);
  static const brass = Color(0xFFD9A93C);
  static const brassDeep = Color(0xFF6B5420);
  static const onBrass = Color(0xFF17120A);
  static const added = Color(0xFF4E9E6A);
  static const removed = Color(0xFFB85C5C);

  /// Your own messages: a lighter step off the chat ground that reads as
  /// "you" without competing with the brass the workflow chrome uses.
  static const userBubble = Color(0xFF2E2E2E);
  static const userBubbleBorder = Color(0xFF3A3A3A);
}

/// The mockup commits to a single dark world, so the app does too — there is
/// no light variant to keep honest.
ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.brass,
    onPrimary: AppColors.onBrass,
    primaryContainer: AppColors.brassDeep,
    onPrimaryContainer: AppColors.brass,
    secondary: AppColors.brass,
    onSecondary: AppColors.onBrass,
    secondaryContainer: AppColors.brassDeep,
    onSecondaryContainer: AppColors.brass,
    tertiary: AppColors.added,
    onTertiary: AppColors.onBrass,
    error: AppColors.removed,
    onError: AppColors.ink,
    errorContainer: Color(0xFF3A1F1F),
    onErrorContainer: Color(0xFFE9B4B4),
    surface: AppColors.bg,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkSoft,
    surfaceContainerLowest: AppColors.void_,
    surfaceContainerLow: AppColors.panel,
    surfaceContainer: AppColors.panel,
    surfaceContainerHigh: AppColors.raise,
    surfaceContainerHighest: AppColors.raise,
    outline: AppColors.inkFaint,
    outlineVariant: AppColors.rule,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.ink,
    onInverseSurface: AppColors.bg,
    inversePrimary: AppColors.brassDeep,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    dividerColor: AppColors.rule,
    dividerTheme: const DividerThemeData(
      color: AppColors.rule,
      space: 1,
      thickness: 1,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.void_,
      indicatorColor: AppColors.brassDeep,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    // No global iconTheme: it leaks into filled buttons and overrides their
    // `onPrimary` foreground, which is what turned the send arrow grey-blue
    // on its brass circle. Material 3 already derives icon colours per
    // component from the scheme.
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.panel,
      selectedColor: AppColors.brassDeep,
      side: BorderSide(color: AppColors.rule),
      showCheckmark: true,
      checkmarkColor: AppColors.brass,
    ),
    // Los diálogos que quedan —los selectores de un workflow, los
    // formularios que viven en diálogo— con el mismo radio y el mismo fondo
    // que la tarjeta de confirmación. Sin esto son lo único de la app con
    // esquinas de 28 y fondo de fábrica.
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.raise,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.rule),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.raise,
        border: Border.all(color: AppColors.rule),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: AppColors.ink, fontSize: 12),
    ),
  );
}
