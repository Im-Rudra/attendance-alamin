// Light + dark ThemeData for Aurora Ink (UX 4). Material 3, Hind Siliguri,
// explicit ColorScheme, pill buttons, plan 1 #28 radii, and the four
// ThemeExtensions.

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/extensions/app_gradients.dart';
import 'package:attendance_alamin/app/theme/extensions/attendance_colors.dart';
import 'package:attendance_alamin/app/theme/extensions/aurora_tokens.dart';
import 'package:attendance_alamin/app/theme/extensions/severity_colors.dart';
import 'package:attendance_alamin/app/theme/tokens.dart';

/// Builds the app theme for [brightness]. The Scaffold background is
/// transparent: the app root paints the mesh behind every route.
ThemeData buildTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final AuroraTokens t = dark ? const AuroraTokens.dusk() : const AuroraTokens.light();
  final AppGradients g = dark ? const AppGradients.dusk() : const AppGradients.light();
  final SeverityColors s = dark ? const SeverityColors.dusk() : const SeverityColors.light();
  final AttendanceColors a = dark ? const AttendanceColors.dusk() : const AttendanceColors.light();

  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: t.accent,
    onPrimary: t.onAccent,
    primaryContainer: t.accentContainer,
    onPrimaryContainer: t.onAccentContainer,
    secondary: t.accent,
    onSecondary: t.onAccent,
    secondaryContainer: t.accentContainer,
    onSecondaryContainer: t.onAccentContainer,
    tertiary: t.info,
    onTertiary: t.surfaceSolid,
    tertiaryContainer: t.infoContainer,
    onTertiaryContainer: t.info,
    error: t.error,
    onError: t.onError,
    errorContainer: t.errorContainer,
    onErrorContainer: t.onErrorContainer,
    surface: t.bg,
    onSurface: t.textPrimary,
    onSurfaceVariant: t.textSecondary,
    surfaceDim: t.bg,
    surfaceBright: t.surfaceSolid,
    surfaceContainerLowest: t.surfaceSolid,
    surfaceContainerLow: t.glassNoBlur,
    surfaceContainer: t.surfaceDense,
    surfaceContainerHigh: t.surfaceDense,
    surfaceContainerHighest: t.surfaceDense,
    outline: t.hairline,
    outlineVariant: t.hairline,
    shadow: t.scrim,
    scrim: t.scrim,
    inverseSurface: t.textPrimary,
    onInverseSurface: t.bg,
    inversePrimary: t.accent,
    surfaceTint: Colors.transparent,
  );

  final TextTheme textTheme = _textTheme(t.textPrimary);
  const StadiumBorder pill = StadiumBorder();
  final BorderSide hair = BorderSide(color: t.hairline);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: t.surfaceSolid,
    dividerColor: t.track,
    disabledColor: t.textDisabled,
    visualDensity: VisualDensity.standard,
    extensions: <ThemeExtension<dynamic>>[t, g, s, a],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: t.textPrimary,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: t.glassNoBlur,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusGlassCard),
        side: hair,
      ),
    ),
    dividerTheme: DividerThemeData(color: t.track, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: t.textSecondary,
      textColor: t.textPrimary,
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll<OutlinedBorder>(pill),
        minimumSize: const WidgetStatePropertyAll<Size>(Size(64, AuroraMetrics.buttonHeight)),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 24),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelLarge),
        elevation: const WidgetStatePropertyAll<double>(0),
        backgroundColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.disabled) ? t.track : t.accent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.disabled) ? t.textDisabled : t.onAccent,
        ),
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) return t.onAccent.withValues(alpha: 0.12);
          if (states.contains(WidgetState.hovered)) return t.onAccent.withValues(alpha: 0.08);
          if (states.contains(WidgetState.focused)) return t.onAccent.withValues(alpha: 0.12);
          return null;
        }),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: pill,
        elevation: 0,
        minimumSize: const Size(64, AuroraMetrics.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: textTheme.labelLarge,
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        disabledBackgroundColor: t.track,
        disabledForegroundColor: t.textDisabled,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, AuroraMetrics.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: textTheme.labelLarge,
        foregroundColor: t.accent,
        disabledForegroundColor: t.textDisabled,
        side: BorderSide(color: t.accent.withValues(alpha: 0.40)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: pill,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: textTheme.labelLarge,
        foregroundColor: t.accent,
        disabledForegroundColor: t.textDisabled,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: t.textSecondary,
        disabledForegroundColor: t.textDisabled,
        minimumSize: const Size(48, 48),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll<OutlinedBorder>(pill),
        textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelLarge),
        side: WidgetStatePropertyAll<BorderSide>(hair),
        backgroundColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected) ? t.accentContainer : t.surfaceDense,
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected) ? t.onAccentContainer : t.textPrimary,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.accent,
      foregroundColor: t.onAccent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusFab),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.surfaceDense,
      selectedColor: t.accentContainer,
      disabledColor: t.track,
      side: hair,
      labelStyle: textTheme.labelMedium,
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: t.onAccentContainer),
      checkmarkColor: t.onAccentContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusChip),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surfaceDense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: textTheme.bodyLarge?.copyWith(color: t.textSecondary),
      labelStyle: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
      helperStyle: textTheme.labelSmall?.copyWith(color: t.textSecondary),
      errorStyle: textTheme.labelMedium?.copyWith(color: t.error),
      border: _fieldBorder(t.hairline, 1),
      enabledBorder: _fieldBorder(t.hairline, 1),
      focusedBorder: _fieldBorder(t.accent, 2),
      errorBorder: _fieldBorder(t.error, 1),
      focusedErrorBorder: _fieldBorder(t.error, 2),
      disabledBorder: _fieldBorder(t.track, 1),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surfaceDense,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: t.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusDialog),
        side: hair,
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surfaceDense,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: t.scrim,
      elevation: 8,
      showDragHandle: true,
      dragHandleColor: t.track,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuroraMetrics.radiusSheetTop)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: t.glassNav,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: t.accentContainer,
      indicatorShape: pill,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
        (states) => textTheme.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected) ? t.onAccentContainer : t.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? t.onAccentContainer : t.textSecondary,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t.glassNav,
      indicatorColor: t.accentContainer,
      selectedIconTheme: IconThemeData(color: t.onAccentContainer),
      unselectedIconTheme: IconThemeData(color: t.textSecondary),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: t.onAccentContainer),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: t.textSecondary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.textPrimary,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: t.bg),
      actionTextColor: t.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.accent,
      linearTrackColor: t.track,
      circularTrackColor: t.track,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (states) => states.contains(WidgetState.selected) ? t.onAccent : t.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (states) => states.contains(WidgetState.selected) ? t.accent : t.track,
      ),
      trackOutlineColor: WidgetStatePropertyAll<Color>(t.hairline),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: t.textPrimary,
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusChip),
      ),
      textStyle: textTheme.labelMedium?.copyWith(color: t.bg),
    ),
  );
}

OutlineInputBorder _fieldBorder(Color color, double width) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
    borderSide: BorderSide(color: color, width: width),
  );
}

TextStyle _style(double size, double lineHeight, FontWeight weight, Color color) {
  return TextStyle(
    fontFamily: kFontFamily,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// UX 4 type scale. Nothing is set below 12sp. Roles the UX table does not
/// list (display/headline large+medium, titleSmall, bodySmall) are filled with
/// values interpolated from it.
TextTheme _textTheme(Color c) {
  return TextTheme(
    displayLarge: _style(40, 58, FontWeight.w600, c),
    displayMedium: _style(36, 52, FontWeight.w600, c),
    displaySmall: _style(32, 46, FontWeight.w600, c),
    headlineLarge: _style(30, 44, FontWeight.w600, c),
    headlineMedium: _style(26, 38, FontWeight.w600, c),
    headlineSmall: _style(24, 36, FontWeight.w600, c),
    titleLarge: _style(20, 30, FontWeight.w600, c),
    titleMedium: _style(17, 26, FontWeight.w500, c),
    titleSmall: _style(15, 22, FontWeight.w500, c),
    bodyLarge: _style(16, 26, FontWeight.w400, c),
    bodyMedium: _style(14, 22, FontWeight.w400, c),
    bodySmall: _style(13, 20, FontWeight.w400, c),
    labelLarge: _style(15, 22, FontWeight.w600, c),
    labelMedium: _style(13, 20, FontWeight.w600, c),
    labelSmall: _style(12, 18, FontWeight.w500, c),
  );
}

/// `statNumber` (UX 4): 40/48 phone, 48/56 desktop, weight 700, -1% tracking,
/// tabular figures. Use ONLY for digit / currency runs, never for Bangla words
/// (negative tracking would collide conjuncts).
TextStyle buildStatNumber(Color color, {required bool desktop}) {
  final double size = desktop ? 48 : 40;
  final double line = desktop ? 56 : 48;
  return TextStyle(
    fontFamily: kFontFamily,
    fontSize: size,
    height: line / size,
    fontWeight: FontWeight.w700,
    letterSpacing: -size * 0.01,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
    leadingDistribution: TextLeadingDistribution.even,
  );
}
