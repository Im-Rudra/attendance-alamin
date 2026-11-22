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
      // Fluid tokens (docs/council/13-fluid-ui-spec.md).
      ('onAccentFill/accentFill', c.onAccentFill, c.accentFill, c.accentFill),
      ('onAccentFill/accentFillHover', c.onAccentFill, c.accentFillHover, c.accentFillHover),
      ('accent/soft', c.accent, c.soft, c.soft),
      ('text/soft2', c.text, c.soft2, c.soft2),
      ('warn/warnBg', c.warn, c.warnBg, c.surface),
      ('overdue/overdueBg', c.overdue, c.overdueBg, c.surface),
      ('absentText/absentBg', c.absentText, c.absentBg, c.surface),
      ('late/lateBg', c.late, c.lateBg, c.surface),
      ('heroStart/heroButton', c.heroStart, c.heroButton, c.heroButton),
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

    // Visual QA (docs/council/14-visual-qa.md C2, C3; 15-windows-ux-review.md
    // R3 / L1): selected states are filled, never ringed.
    test('$theme attendance toggle: the filled thumb stands out from the track (>= 3:1), its label is AA', () {
      for (final (String n, Color tone) in <(String, Color)>[
        ('present', c.ok),
        ('absent', c.absentText),
        ('late', c.late),
      ]) {
        final double fill = contrast(tone, c.soft, c.soft);
        expect(fill, greaterThanOrEqualTo(3.0), reason: '$theme $n thumb = ${fill.toStringAsFixed(2)}:1');
        final Color on = BhorAttendanceToggle.onStatusOf(c);
        final double label = contrast(on, tone, tone);
        expect(label, greaterThanOrEqualTo(4.5), reason: '$theme $n label = ${label.toStringAsFixed(2)}:1');
      }
    });

    test('$theme segmented / tabs: selected text is AA on the filled thumb; the thumb separates from the track', () {
      expect(contrast(c.text, c.thumb, c.thumb), greaterThanOrEqualTo(4.5));
      if (t.isDark) expect(contrast(c.thumb, c.soft, c.soft), greaterThanOrEqualTo(2.0));
    });

    test('$theme selection style: text stays AA on the selected card fill', () {
      final Color fill = BhorSelection.fillOn(c, c.surface);
      expect(contrast(c.text, fill, fill), greaterThanOrEqualTo(4.5));
      expect(contrast(c.text2, fill, fill), greaterThanOrEqualTo(4.5));
      expect(contrast(c.accent, fill, fill), greaterThanOrEqualTo(3.0));
    });

    test('$theme overdue tag is the tinted pill and AA', () {
      final (Color bg, Color fg) = BhorTag.severityColorsOf(c, SeverityLevel.overdue);
      expect(bg, c.overdueBg);
      expect(fg, c.overdue);
      expect(contrast(fg, bg, c.surface), greaterThanOrEqualTo(4.5));
    });
  }
}
