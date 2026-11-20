// Payment-warning severity colours (UX 5). Warm hues mean money.
//
// Keyed by the theme-local [SeverityLevel] (same declaration order as M1-B's
// `DueLevel`): map with `SeverityLevel.values[dueLevel.index]`.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/tokens.dart';

class SeverityColors extends ThemeExtension<SeverityColors> {
  const SeverityColors({
    required List<Color> hues,
    required List<Color> fills,
    required List<Color> texts,
    required List<Color?> borders,
    required this.paidFill,
    required this.paidText,
    required this.waivedFill,
    required this.waivedText,
    required this.waivedBorder,
    required this.notDueFill,
    required this.notDueText,
  })  : _hues = hues,
        _fills = fills,
        _texts = texts,
        _borders = borders;

  const SeverityColors.light()
      : _hues = LightTokens.sevHue,
        _fills = LightTokens.sevFill,
        _texts = LightTokens.sevText,
        _borders = LightTokens.sevBorder,
        paidFill = LightTokens.paidFill,
        paidText = LightTokens.paidText,
        waivedFill = LightTokens.waivedFill,
        waivedText = LightTokens.waivedText,
        waivedBorder = LightTokens.waivedBorder,
        notDueFill = LightTokens.notDueFill,
        notDueText = LightTokens.notDueText;

  const SeverityColors.dusk()
      : _hues = DuskTokens.sevHue,
        _fills = DuskTokens.sevFill,
        _texts = DuskTokens.sevText,
        _borders = DuskTokens.sevBorder,
        paidFill = DuskTokens.paidFill,
        paidText = DuskTokens.paidText,
        waivedFill = DuskTokens.waivedFill,
        waivedText = DuskTokens.waivedText,
        waivedBorder = DuskTokens.waivedBorder,
        notDueFill = DuskTokens.notDueFill,
        notDueText = DuskTokens.notDueText;

  final List<Color> _hues;
  final List<Color> _fills;
  final List<Color> _texts;
  final List<Color?> _borders;

  /// "Paid" and "Advance" share these colours (UX 5).
  final Color paidFill;
  final Color paidText;
  final Color waivedFill;
  final Color waivedText;

  /// Dashed outline colour of the waived badge.
  final Color waivedBorder;
  final Color notDueFill;
  final Color notDueText;

  /// Bar / edge-bar hue (decorative; the label carries the meaning).
  Color hue(SeverityLevel l) => _hues[l.index];

  /// Opaque badge fill. Overdue is the only solid badge (identical in both themes).
  Color badgeFill(SeverityLevel l) => _fills[l.index];

  Color badgeText(SeverityLevel l) => _texts[l.index];

  /// Border colour, or null for none. Width: [badgeBorderWidth].
  Color? badgeBorder(SeverityLevel l) => _borders[l.index];

  /// 1.5 for [SeverityLevel.finalDays] (strong rose border), else 1.
  double badgeBorderWidth(SeverityLevel l) => l == SeverityLevel.finalDays ? 1.5 : 1.0;

  /// Colour of segment [day] (1..10) in the escalation bar. Days 1-2 are L1,
  /// 3-4 L2, 5-6 L3, 7-8 L4, 9-10 L5; beyond 10 is overdue.
  Color segment(int day) {
    if (day < 1) return hue(SeverityLevel.upcoming);
    if (day > 10) return hue(SeverityLevel.overdue);
    return hue(SeverityLevel.values[(day - 1) ~/ 2 + 1]);
  }

  @override
  SeverityColors copyWith({
    List<Color>? hues,
    List<Color>? fills,
    List<Color>? texts,
    List<Color?>? borders,
    Color? paidFill,
    Color? paidText,
    Color? waivedFill,
    Color? waivedText,
    Color? waivedBorder,
    Color? notDueFill,
    Color? notDueText,
  }) {
    return SeverityColors(
      hues: hues ?? _hues,
      fills: fills ?? _fills,
      texts: texts ?? _texts,
      borders: borders ?? _borders,
      paidFill: paidFill ?? this.paidFill,
      paidText: paidText ?? this.paidText,
      waivedFill: waivedFill ?? this.waivedFill,
      waivedText: waivedText ?? this.waivedText,
      waivedBorder: waivedBorder ?? this.waivedBorder,
      notDueFill: notDueFill ?? this.notDueFill,
      notDueText: notDueText ?? this.notDueText,
    );
  }

  @override
  SeverityColors lerp(ThemeExtension<SeverityColors>? other, double t) {
    if (other is! SeverityColors) return this;
    return SeverityColors(
      hues: _lerpList(_hues, other._hues, t),
      fills: _lerpList(_fills, other._fills, t),
      texts: _lerpList(_texts, other._texts, t),
      borders: _lerpNullableList(_borders, other._borders, t),
      paidFill: Color.lerp(paidFill, other.paidFill, t)!,
      paidText: Color.lerp(paidText, other.paidText, t)!,
      waivedFill: Color.lerp(waivedFill, other.waivedFill, t)!,
      waivedText: Color.lerp(waivedText, other.waivedText, t)!,
      waivedBorder: Color.lerp(waivedBorder, other.waivedBorder, t)!,
      notDueFill: Color.lerp(notDueFill, other.notDueFill, t)!,
      notDueText: Color.lerp(notDueText, other.notDueText, t)!,
    );
  }
}

List<Color> _lerpList(List<Color> a, List<Color> b, double t) {
  return [for (int i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!];
}

List<Color?> _lerpNullableList(List<Color?> a, List<Color?> b, double t) {
  // Color.lerp handles a null end by fading alpha, so null borders fade in/out.
  return [for (int i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)];
}
