// Mesh pools and hero-card gradients (UX 4: Backdrop + Hero card).

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/tokens.dart';

class AppGradients extends ThemeExtension<AppGradients> {
  const AppGradients({
    required this.meshA,
    required this.meshB,
    required this.meshC,
    required this.heroBase,
    required this.heroRadials,
    required this.heroCtaFill,
    required this.heroCtaText,
    required this.heroText,
    required this.heroTextSecondary,
    required this.heroTopHighlight,
    required this.heroShadow,
  });

  const AppGradients.light()
      : meshA = LightTokens.meshA,
        meshB = LightTokens.meshB,
        meshC = LightTokens.meshC,
        heroBase = LightTokens.heroBase,
        heroRadials = const [LightTokens.heroRadial1, LightTokens.heroRadial2],
        heroCtaFill = LightTokens.heroCtaFill,
        heroCtaText = LightTokens.heroCtaText,
        heroText = LightTokens.heroText,
        heroTextSecondary = LightTokens.heroTextSecondary,
        heroTopHighlight = LightTokens.heroTopHighlight,
        heroShadow = LightTokens.heroShadow;

  const AppGradients.dusk()
      : meshA = DuskTokens.meshA,
        meshB = DuskTokens.meshB,
        meshC = DuskTokens.meshC,
        heroBase = DuskTokens.heroBase,
        heroRadials = const [DuskTokens.heroRadial1, DuskTokens.heroRadial2],
        heroCtaFill = DuskTokens.heroCtaFill,
        heroCtaText = DuskTokens.heroCtaText,
        heroText = DuskTokens.heroText,
        heroTextSecondary = DuskTokens.heroTextSecondary,
        heroTopHighlight = DuskTokens.heroTopHighlight,
        heroShadow = DuskTokens.heroShadow;

  /// Mesh pool A (top-left corner), B (right edge, y = 22%), C (bottom-left).
  /// Each fades to transparent at 70% of its radius. The mesh widget scales
  /// them to the window (UX 4 rule 7).
  final RadialGradient meshA;
  final RadialGradient meshB;
  final RadialGradient meshC;

  /// Hero card base colour; paint [heroRadials] (violet top-left, teal
  /// bottom-right, in that order) over it.
  final Color heroBase;
  final List<RadialGradient> heroRadials;
  final Color heroCtaFill;
  final Color heroCtaText;
  final Color heroText;
  final Color heroTextSecondary;
  final Color heroTopHighlight;
  final Color heroShadow;

  @override
  AppGradients copyWith({
    RadialGradient? meshA,
    RadialGradient? meshB,
    RadialGradient? meshC,
    Color? heroBase,
    List<RadialGradient>? heroRadials,
    Color? heroCtaFill,
    Color? heroCtaText,
    Color? heroText,
    Color? heroTextSecondary,
    Color? heroTopHighlight,
    Color? heroShadow,
  }) {
    return AppGradients(
      meshA: meshA ?? this.meshA,
      meshB: meshB ?? this.meshB,
      meshC: meshC ?? this.meshC,
      heroBase: heroBase ?? this.heroBase,
      heroRadials: heroRadials ?? this.heroRadials,
      heroCtaFill: heroCtaFill ?? this.heroCtaFill,
      heroCtaText: heroCtaText ?? this.heroCtaText,
      heroText: heroText ?? this.heroText,
      heroTextSecondary: heroTextSecondary ?? this.heroTextSecondary,
      heroTopHighlight: heroTopHighlight ?? this.heroTopHighlight,
      heroShadow: heroShadow ?? this.heroShadow,
    );
  }

  @override
  AppGradients lerp(ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) return this;
    final int n = heroRadials.length < other.heroRadials.length
        ? heroRadials.length
        : other.heroRadials.length;
    return AppGradients(
      meshA: _lerpRadial(meshA, other.meshA, t),
      meshB: _lerpRadial(meshB, other.meshB, t),
      meshC: _lerpRadial(meshC, other.meshC, t),
      heroBase: Color.lerp(heroBase, other.heroBase, t)!,
      heroRadials: [
        for (int i = 0; i < n; i++) _lerpRadial(heroRadials[i], other.heroRadials[i], t),
      ],
      heroCtaFill: Color.lerp(heroCtaFill, other.heroCtaFill, t)!,
      heroCtaText: Color.lerp(heroCtaText, other.heroCtaText, t)!,
      heroText: Color.lerp(heroText, other.heroText, t)!,
      heroTextSecondary: Color.lerp(heroTextSecondary, other.heroTextSecondary, t)!,
      heroTopHighlight: Color.lerp(heroTopHighlight, other.heroTopHighlight, t)!,
      heroShadow: Color.lerp(heroShadow, other.heroShadow, t)!,
    );
  }
}

/// Component-wise lerp of two radial gradients that share the same structure
/// (same colour count, same stops), which is true for every token gradient.
RadialGradient _lerpRadial(RadialGradient a, RadialGradient b, double t) {
  final int n = a.colors.length < b.colors.length ? a.colors.length : b.colors.length;
  final Alignment ca = a.center as Alignment;
  final Alignment cb = b.center as Alignment;
  return RadialGradient(
    center: Alignment.lerp(ca, cb, t)!,
    radius: lerpDouble(a.radius, b.radius, t)!,
    colors: [for (int i = 0; i < n; i++) Color.lerp(a.colors[i], b.colors[i], t)!],
    stops: t < 0.5 ? a.stops : b.stops,
  );
}
