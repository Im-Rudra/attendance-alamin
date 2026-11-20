// Attendance status colours (UX 6). Cool palette; never confusable with dues.
//
// Keyed by the theme-local [AttendanceKind] (same declaration order as M1-B's
// `AttendanceStatus`): map with `AttendanceKind.values[status.index]`.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/tokens.dart';

class AttendanceColors extends ThemeExtension<AttendanceColors> {
  const AttendanceColors({
    required List<Color> fills,
    required List<Color> texts,
    required List<Color?> borders,
    required this.heatLow,
    required this.heatHigh,
  })  : _fills = fills,
        _texts = texts,
        _borders = borders;

  const AttendanceColors.light()
      : _fills = LightTokens.attFill,
        _texts = LightTokens.attText,
        _borders = LightTokens.attBorder,
        heatLow = LightTokens.heatLow,
        heatHigh = LightTokens.heatHigh;

  const AttendanceColors.dusk()
      : _fills = DuskTokens.attFill,
        _texts = DuskTokens.attText,
        _borders = DuskTokens.attBorder,
        heatLow = DuskTokens.heatLow,
        heatHigh = DuskTokens.heatHigh;

  final List<Color> _fills;
  final List<Color> _texts;
  final List<Color?> _borders;

  /// Calendar heatmap ramp ends (green; no warm colours).
  final Color heatLow;
  final Color heatHigh;

  Color fill(AttendanceKind s) => _fills[s.index];

  Color text(AttendanceKind s) => _texts[s.index];

  /// Border colour or null. Excused is dashed (widget decides the dash).
  Color? border(AttendanceKind s) => _borders[s.index];

  /// Heatmap colour for an attendance fraction in 0..1.
  Color heat(double fraction) => Color.lerp(heatLow, heatHigh, fraction.clamp(0.0, 1.0))!;

  @override
  AttendanceColors copyWith({
    List<Color>? fills,
    List<Color>? texts,
    List<Color?>? borders,
    Color? heatLow,
    Color? heatHigh,
  }) {
    return AttendanceColors(
      fills: fills ?? _fills,
      texts: texts ?? _texts,
      borders: borders ?? _borders,
      heatLow: heatLow ?? this.heatLow,
      heatHigh: heatHigh ?? this.heatHigh,
    );
  }

  @override
  AttendanceColors lerp(ThemeExtension<AttendanceColors>? other, double t) {
    if (other is! AttendanceColors) return this;
    return AttendanceColors(
      fills: [for (int i = 0; i < _fills.length; i++) Color.lerp(_fills[i], other._fills[i], t)!],
      texts: [for (int i = 0; i < _texts.length; i++) Color.lerp(_texts[i], other._texts[i], t)!],
      borders: [for (int i = 0; i < _borders.length; i++) Color.lerp(_borders[i], other._borders[i], t)],
      heatLow: Color.lerp(heatLow, other.heatLow, t)!,
      heatHigh: Color.lerp(heatHigh, other.heatHigh, t)!,
    );
  }
}
