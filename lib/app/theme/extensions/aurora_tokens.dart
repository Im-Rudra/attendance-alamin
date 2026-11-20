// ThemeExtension holding every Aurora Ink surface / text / accent token (UX 4).

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/tokens.dart';

class AuroraTokens extends ThemeExtension<AuroraTokens> {
  const AuroraTokens({
    required this.bg,
    required this.glass,
    required this.glassNav,
    required this.glassNoBlur,
    required this.surfaceDense,
    required this.surfaceSolid,
    required this.hairline,
    required this.topHighlight,
    required this.track,
    required this.scrim,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.avatarBg,
    required this.avatarText,
    required this.statePillBg,
    required this.statePillText,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.errorContainerBorder,
    required this.info,
    required this.infoContainer,
    required this.grainOpacity,
  });

  /// Light theme tokens.
  const AuroraTokens.light()
      : bg = LightTokens.bg,
        glass = LightTokens.glass,
        glassNav = LightTokens.glassNav,
        glassNoBlur = LightTokens.glassNoBlur,
        surfaceDense = LightTokens.surfaceDense,
        surfaceSolid = LightTokens.surfaceSolid,
        hairline = LightTokens.hairline,
        topHighlight = LightTokens.topHighlight,
        track = LightTokens.track,
        scrim = LightTokens.scrim,
        textPrimary = LightTokens.textPrimary,
        textSecondary = LightTokens.textSecondary,
        textDisabled = LightTokens.textDisabled,
        accent = LightTokens.accent,
        onAccent = LightTokens.onAccent,
        accentContainer = LightTokens.accentContainer,
        onAccentContainer = LightTokens.onAccentContainer,
        avatarBg = LightTokens.avatarBg,
        avatarText = LightTokens.avatarText,
        statePillBg = LightTokens.statePillBg,
        statePillText = LightTokens.statePillText,
        error = LightTokens.error,
        onError = LightTokens.onError,
        errorContainer = LightTokens.errorContainer,
        onErrorContainer = LightTokens.onErrorContainer,
        errorContainerBorder = LightTokens.errorContainerBorder,
        info = LightTokens.info,
        infoContainer = LightTokens.infoContainer,
        grainOpacity = LightTokens.grainOpacity;

  /// Dark ("Dusk") theme tokens.
  const AuroraTokens.dusk()
      : bg = DuskTokens.bg,
        glass = DuskTokens.glass,
        glassNav = DuskTokens.glassNav,
        glassNoBlur = DuskTokens.glassNoBlur,
        surfaceDense = DuskTokens.surfaceDense,
        surfaceSolid = DuskTokens.surfaceSolid,
        hairline = DuskTokens.hairline,
        topHighlight = DuskTokens.topHighlight,
        track = DuskTokens.track,
        scrim = DuskTokens.scrim,
        textPrimary = DuskTokens.textPrimary,
        textSecondary = DuskTokens.textSecondary,
        textDisabled = DuskTokens.textDisabled,
        accent = DuskTokens.accent,
        onAccent = DuskTokens.onAccent,
        accentContainer = DuskTokens.accentContainer,
        onAccentContainer = DuskTokens.onAccentContainer,
        avatarBg = DuskTokens.avatarBg,
        avatarText = DuskTokens.avatarText,
        statePillBg = DuskTokens.statePillBg,
        statePillText = DuskTokens.statePillText,
        error = DuskTokens.error,
        onError = DuskTokens.onError,
        errorContainer = DuskTokens.errorContainer,
        onErrorContainer = DuskTokens.onErrorContainer,
        errorContainerBorder = DuskTokens.errorContainerBorder,
        info = DuskTokens.info,
        infoContainer = DuskTokens.infoContainer,
        grainOpacity = DuskTokens.grainOpacity;

  /// Page ground under the mesh.
  final Color bg;
  /// Frosted card fill (blur sigma 18).
  final Color glass;
  /// Nav pill / rail / top bar fill (blur sigma 24).
  final Color glassNav;
  /// Card fill inside scrolling lists (no blur).
  final Color glassNoBlur;
  /// Lists, forms, tables, dialogs, sheet bodies.
  final Color surfaceDense;
  /// Reduced-effects replacement for glass.
  final Color surfaceSolid;
  /// 1px border, dividers, pane splits.
  final Color hairline;
  /// Inset 1px highlight on the top edge of glass.
  final Color topHighlight;
  /// Progress tracks, empty bar segments, row dividers.
  final Color track;
  /// Modal scrim.
  final Color scrim;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;
  final Color avatarBg;
  final Color avatarText;
  final Color statePillBg;
  final Color statePillText;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  /// Border of errorContainer (transparent in light, error at 40% in dark).
  final Color errorContainerBorder;
  /// Info text / icon colour (on infoContainer).
  final Color info;
  /// Info fill.
  final Color infoContainer;

  /// Film-grain overlay opacity (0.05 light / 0.07 dark).
  final double grainOpacity;

  @override
  AuroraTokens copyWith({
    Color? bg,
    Color? glass,
    Color? glassNav,
    Color? glassNoBlur,
    Color? surfaceDense,
    Color? surfaceSolid,
    Color? hairline,
    Color? topHighlight,
    Color? track,
    Color? scrim,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? onAccentContainer,
    Color? avatarBg,
    Color? avatarText,
    Color? statePillBg,
    Color? statePillText,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? errorContainerBorder,
    Color? info,
    Color? infoContainer,
    double? grainOpacity,
  }) {
    return AuroraTokens(
      bg: bg ?? this.bg,
      glass: glass ?? this.glass,
      glassNav: glassNav ?? this.glassNav,
      glassNoBlur: glassNoBlur ?? this.glassNoBlur,
      surfaceDense: surfaceDense ?? this.surfaceDense,
      surfaceSolid: surfaceSolid ?? this.surfaceSolid,
      hairline: hairline ?? this.hairline,
      topHighlight: topHighlight ?? this.topHighlight,
      track: track ?? this.track,
      scrim: scrim ?? this.scrim,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentContainer: accentContainer ?? this.accentContainer,
      onAccentContainer: onAccentContainer ?? this.onAccentContainer,
      avatarBg: avatarBg ?? this.avatarBg,
      avatarText: avatarText ?? this.avatarText,
      statePillBg: statePillBg ?? this.statePillBg,
      statePillText: statePillText ?? this.statePillText,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      errorContainerBorder: errorContainerBorder ?? this.errorContainerBorder,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      grainOpacity: grainOpacity ?? this.grainOpacity,
    );
  }

  @override
  AuroraTokens lerp(ThemeExtension<AuroraTokens>? other, double t) {
    if (other is! AuroraTokens) return this;
    return AuroraTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassNav: Color.lerp(glassNav, other.glassNav, t)!,
      glassNoBlur: Color.lerp(glassNoBlur, other.glassNoBlur, t)!,
      surfaceDense: Color.lerp(surfaceDense, other.surfaceDense, t)!,
      surfaceSolid: Color.lerp(surfaceSolid, other.surfaceSolid, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      topHighlight: Color.lerp(topHighlight, other.topHighlight, t)!,
      track: Color.lerp(track, other.track, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      onAccentContainer: Color.lerp(onAccentContainer, other.onAccentContainer, t)!,
      avatarBg: Color.lerp(avatarBg, other.avatarBg, t)!,
      avatarText: Color.lerp(avatarText, other.avatarText, t)!,
      statePillBg: Color.lerp(statePillBg, other.statePillBg, t)!,
      statePillText: Color.lerp(statePillText, other.statePillText, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      onErrorContainer: Color.lerp(onErrorContainer, other.onErrorContainer, t)!,
      errorContainerBorder: Color.lerp(errorContainerBorder, other.errorContainerBorder, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      grainOpacity: lerpDouble(grainOpacity, other.grainOpacity, t)!,
    );
  }
}
