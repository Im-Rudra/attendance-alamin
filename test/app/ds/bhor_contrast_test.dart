// WCAG AA for every Bhor text / fill pair, both themes. Translucent tokens
// are composited over the surface they sit on. Body text >= 4.5:1; the
// focus-ring edge and the decorative severity hues are not text.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

Color _over(Color fg, Color bg) {
  final double a = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

double _lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _lum(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

/// Contrast of [fg] on [bg], with [bg] first composited over [under].
double contrast(Color fg, Color bg, Color under) {
  final Color b = _over(bg, _over(under, under.withValues(alpha: 1)));
  final Color f = _over(fg, b);
  final double l1 = _lum(f);
  final double l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  for (final BhorThemeData t in <BhorThemeData>[BhorThemeData.light(), BhorThemeData.dark()]) {
    final BhorColors c = t.colors;
    final String theme = t.isDark ? 'dark' : 'light';

    // (name, foreground, background, what the background sits on)
    final List<(String, Color, Color, Color)> text = <(String, Color, Color, Color)>[
      for (final (String n, Color fg) in <(String, Color)>[
        ('text', c.text),
        ('text2', c.text2),
        ('text3', c.text3),
        ('accent', c.accent),
        ('danger', c.danger),
        ('ok', c.ok),
      ]) ...<(String, Color, Color, Color)>[
        ('$n/bg', fg, c.bg, c.bg),
        ('$n/surface', fg, c.surface, c.surface),
        ('$n/surface2', fg, c.surface2, c.surface2),
      ],
      ('accent/accentTint', c.accent, c.accentTint, c.surface),
      ('text/accentTint', c.text, c.accentTint, c.surface),
      ('onAccent/accent', c.onAccent, c.accent, c.accent),
      ('onAccent/accent2', c.onAccent, c.accent2, c.accent2),
      ('ok/okBg', c.ok, c.okBg, c.surface),
      ('danger/dangerBg', c.danger, c.dangerBg, c.surface),
      ('onDanger/danger', c.onDanger, c.danger, c.danger),
      ('onHero/heroStart', c.onHero, c.heroStart, c.heroStart),
      ('onHero/heroEnd', c.onHero, c.heroEnd, c.heroEnd),
      ('onAbsent/absent', c.onAbsent, c.absent, c.absent),
      ('lateText/lateBg', c.lateText, c.lateBg, c.surface),
      ('text2/line (dark segmented thumb)', c.text2, c.line, c.line),
      for (final SeverityLevel l in SeverityLevel.values)
        ('sevText/sevFill ${l.name}', c.sevText[l.index], c.sevFill[l.index], c.surface),
    ];

    for (final (String name, Color fg, Color bg, Color under) in text) {
      test('$theme $name >= 4.5:1', () {
        final double r = contrast(fg, bg, under);
        expect(r, greaterThanOrEqualTo(4.5), reason: '$theme $name = ${r.toStringAsFixed(2)}:1');
      });
    }

    test('$theme focus ring edge and accent line are visible (>= 3:1)', () {
      expect(contrast(c.accent, c.bg, c.bg), greaterThanOrEqualTo(3.0));
      expect(contrast(c.accent, c.surface, c.surface), greaterThanOrEqualTo(3.0));
    });
  }
}
