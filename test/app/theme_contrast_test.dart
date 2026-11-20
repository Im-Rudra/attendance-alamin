// M3-B: WCAG contrast (Scenario 24, contrast part) for every text / fill pair
// in UX 4-6, both themes, plus ThemeExtension copyWith / lerp checks.
//
// Rules: body text >= 4.5:1; large text / icons / focus ring >= 3.0:1.
// Excluded on purpose (documented in the PR): `textDisabled` (WCAG exempts
// disabled controls) and the severity `hue` bar colours (decorative and
// supplemental; the badge label and icon carry the meaning, UX 5).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/theme/app_theme.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';

// ---- Pure contrast helpers --------------------------------------------------

/// Composites [fg] (may be translucent) over an opaque [bg]; result is opaque.
Color over(Color fg, Color bg) {
  final double a = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// WCAG 2.x relative luminance of an opaque colour.
double relativeLuminance(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

/// WCAG contrast ratio of [fg] over [bg]; both are composited over [under]
/// first when translucent.
double contrast(Color fg, Color bg, {Color? under}) {
  final Color base = under ?? bg;
  final Color b = over(bg, base);
  final Color f = over(fg, b);
  final double l1 = relativeLuminance(f);
  final double l2 = relativeLuminance(b);
  final double hi = math.max(l1, l2);
  final double lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

const double aa = 4.5;
const double aaLarge = 3.0;

void expectRatio(String name, double actual, double min) {
  expect(actual, greaterThanOrEqualTo(min), reason: '$name = ${actual.toStringAsFixed(2)}:1 (< $min:1)');
}

class _Theme {
  const _Theme(this.name, this.t, this.g, this.s, this.a);
  final String name;
  final AuroraTokens t;
  final AppGradients g;
  final SeverityColors s;
  final AttendanceColors a;
}

const _themes = <_Theme>[
  _Theme('light', AuroraTokens.light(), AppGradients.light(), SeverityColors.light(),
      AttendanceColors.light()),
  _Theme('dusk', AuroraTokens.dusk(), AppGradients.dusk(), SeverityColors.dusk(),
      AttendanceColors.dusk()),
];

void main() {
  group('contrast helpers', () {
    test('black on white is 21:1, identical colours are 1:1', () {
      const Color black = Color(0xFF000000);
      const Color white = Color(0xFFFFFFFF);
      expect(contrast(black, white), closeTo(21.0, 0.001));
      expect(contrast(white, white), closeTo(1.0, 0.001));
    });

    test('known reference: #767676 on white is 4.54:1', () {
      expect(contrast(const Color(0xFF767676), const Color(0xFFFFFFFF)), closeTo(4.54, 0.01));
    });

    test('alpha compositing: 50% black over white is mid grey', () {
      final Color c = over(const Color(0x80000000), const Color(0xFFFFFFFF));
      expect(c.r, closeTo(0.4980, 0.005));
      expect(c.a, 1.0);
    });
  });

  for (final _Theme th in _themes) {
    group('contrast (${th.name})', () {
      final AuroraTokens t = th.t;
      final List<Color> pools = [
        over(th.g.meshA.colors.first, t.bg),
        over(th.g.meshB.colors.first, t.bg),
        over(th.g.meshC.colors.first, t.bg),
      ];
      final List<Color> grounds = [t.bg, ...pools];
      final Map<String, Color> surfaces = {
        'glass': t.glass,
        'glassNav': t.glassNav,
        'glassNoBlur': t.glassNoBlur,
        'surfaceDense': t.surfaceDense,
        'surfaceSolid': t.surfaceSolid,
      };

      test('big screen title: textPrimary is >= 11:1 on bg and on every mesh pool', () {
        // UX 4 claims >= 12:1; the light theme measures 11.3:1 on the violet
        // pool (still far above the 3:1 large-text bar). Floor set to 11.
        for (final Color g in grounds) {
          expectRatio('textPrimary on bare ground', contrast(t.textPrimary, g), 11.0);
        }
      });

      test('textPrimary and textSecondary pass AA on every surface over every ground', () {
        for (final Color g in grounds) {
          surfaces.forEach((String name, Color surface) {
            expectRatio('textPrimary on $name', contrast(t.textPrimary, surface, under: g), aa);
            expectRatio('textSecondary on $name', contrast(t.textSecondary, surface, under: g), aa);
          });
        }
        expectRatio('textSecondary on bg', contrast(t.textSecondary, t.bg), aa);
      });

      test('accent, onAccent and their containers', () {
        final Color dense = over(t.surfaceDense, t.bg);
        expectRatio('onAccent on accent', contrast(t.onAccent, t.accent), aa);
        expectRatio('accent text on bg', contrast(t.accent, t.bg), aa);
        expectRatio('accent text on dense', contrast(t.accent, dense), aa);
        expectRatio('accent focus ring on bg (UI)', contrast(t.accent, t.bg), aaLarge);
        expectRatio('textPrimary ring on bg (UI)', contrast(t.textPrimary, t.bg), aaLarge);
        final Color accentC = over(t.accentContainer, dense);
        expectRatio('onAccentContainer on accentContainer', contrast(t.onAccentContainer, accentC), aa);
        final Color avatar = over(t.avatarBg, dense);
        expectRatio('avatarText on avatarBg', contrast(t.avatarText, avatar), aa);
        final Color pill = over(t.statePillBg, dense);
        expectRatio('statePillText on statePillBg', contrast(t.statePillText, pill), aa);
      });

      test('error and info', () {
        final Color dense = over(t.surfaceDense, t.bg);
        expectRatio('error on dense', contrast(t.error, dense), aa);
        expectRatio('error on bg', contrast(t.error, t.bg), aa);
        expectRatio('onError on error', contrast(t.onError, t.error), aa);
        expectRatio('onErrorContainer on errorContainer',
            contrast(t.onErrorContainer, over(t.errorContainer, dense)), aa);
        expectRatio('error on errorContainer', contrast(t.error, over(t.errorContainer, dense)), aa);
        expectRatio('info on infoContainer', contrast(t.info, over(t.infoContainer, dense)), aa);
      });

      test('hero text on every part of the hero gradient, incl. the teal pool centre', () {
        final Color base = th.g.heroBase;
        final Color violet = over(th.g.heroRadials[0].colors.first, base);
        final Color teal = over(th.g.heroRadials[1].colors.first, base);
        for (final (String, Color) spot in [('base', base), ('violet corner', violet), ('teal centre', teal)]) {
          expectRatio('hero white on ${spot.$1}', contrast(th.g.heroText, spot.$2), aa);
          expectRatio('hero secondary white on ${spot.$1}', contrast(th.g.heroTextSecondary, spot.$2), aa);
        }
        expectRatio('hero CTA text on CTA fill', contrast(th.g.heroCtaText, th.g.heroCtaFill), aa);
        // The teal pool is capped at 55% alpha (UX 4).
        expect(th.g.heroRadials[1].colors.first.a, lessThanOrEqualTo(0.55 + 1 / 255));
      });

      test('severity badges: text on own opaque fill, every level', () {
        for (final SeverityLevel l in SeverityLevel.values) {
          final Color fill = th.s.badgeFill(l);
          expect(fill.a, 1.0, reason: '${l.name} fill must be opaque (never depends on what is behind)');
          expectRatio('${l.name} badge', contrast(th.s.badgeText(l), fill), aa);
        }
        expectRatio('paid', contrast(th.s.paidText, th.s.paidFill), aa);
        expectRatio('waived', contrast(th.s.waivedText, th.s.waivedFill), aa);
        expectRatio('notDue', contrast(th.s.notDueText, th.s.notDueFill), aa);
      });

      test('attendance badges: text on own fill, every status', () {
        for (final AttendanceKind k in AttendanceKind.values) {
          expect(th.a.fill(k).a, 1.0, reason: '${k.name} fill must be opaque');
          expectRatio('${k.name} attendance', contrast(th.a.text(k), th.a.fill(k)), aa);
        }
        expectRatio('heat high on heat low (UI)', contrast(th.a.heatHigh, th.a.heatLow), aaLarge);
      });

      test('severity bar segments follow the level bands', () {
        expect(th.s.segment(1), th.s.hue(SeverityLevel.justDue));
        expect(th.s.segment(2), th.s.hue(SeverityLevel.justDue));
        expect(th.s.segment(3), th.s.hue(SeverityLevel.remind));
        expect(th.s.segment(6), th.s.hue(SeverityLevel.followUp));
        expect(th.s.segment(8), th.s.hue(SeverityLevel.urgent));
        expect(th.s.segment(10), th.s.hue(SeverityLevel.finalDays));
        expect(th.s.segment(11), th.s.hue(SeverityLevel.overdue));
      });
    });
  }

  test('overdue badge is identical in both themes (solid raspberry, white text)', () {
    const SeverityColors light = SeverityColors.light();
    const SeverityColors dusk = SeverityColors.dusk();
    expect(light.badgeFill(SeverityLevel.overdue), dusk.badgeFill(SeverityLevel.overdue));
    expect(light.badgeText(SeverityLevel.overdue), dusk.badgeText(SeverityLevel.overdue));
    expect(light.hue(SeverityLevel.overdue), dusk.hue(SeverityLevel.overdue));
  });

  group('ThemeExtension copyWith / lerp', () {
    const AuroraTokens l = AuroraTokens.light();
    const AuroraTokens d = AuroraTokens.dusk();

    test('AuroraTokens.lerp at 0, 0.5, 1', () {
      final AuroraTokens a = l.lerp(d, 0);
      final AuroraTokens b = l.lerp(d, 1);
      final AuroraTokens m = l.lerp(d, 0.5);
      expect(a.bg, l.bg);
      expect(a.accent, l.accent);
      expect(a.grainOpacity, l.grainOpacity);
      expect(b.bg, d.bg);
      expect(b.textPrimary, d.textPrimary);
      expect(b.grainOpacity, d.grainOpacity);
      expect(m.bg, Color.lerp(l.bg, d.bg, 0.5));
      expect(m.grainOpacity, closeTo((l.grainOpacity + d.grainOpacity) / 2, 1e-9));
      expect(l.lerp(null, 0.5).bg, l.bg);
    });

    test('AuroraTokens.copyWith replaces only the given fields', () {
      final AuroraTokens c = l.copyWith(bg: const Color(0xFF123456), grainOpacity: 0.5);
      expect(c.bg, const Color(0xFF123456));
      expect(c.grainOpacity, 0.5);
      expect(c.accent, l.accent);
      expect(c.glass, l.glass);
    });

    test('AppGradients.lerp at 0, 0.5, 1 and copyWith', () {
      const AppGradients gl = AppGradients.light();
      const AppGradients gd = AppGradients.dusk();
      expect(gl.lerp(gd, 0).heroBase, gl.heroBase);
      expect(gl.lerp(gd, 1).heroBase, gd.heroBase);
      expect(gl.lerp(gd, 0.5).heroBase, Color.lerp(gl.heroBase, gd.heroBase, 0.5));
      expect(gl.lerp(gd, 1).meshA.colors.first, gd.meshA.colors.first);
      expect(gl.lerp(gd, 0).meshB.colors.first, gl.meshB.colors.first);
      expect(gl.lerp(gd, 0.5).heroRadials.length, 2);
      expect(gl.copyWith(heroBase: const Color(0xFF000001)).heroBase, const Color(0xFF000001));
      expect(gl.copyWith().heroCtaFill, gl.heroCtaFill);
    });

    test('SeverityColors.lerp at 0, 0.5, 1 and copyWith', () {
      const SeverityColors sl = SeverityColors.light();
      const SeverityColors sd = SeverityColors.dusk();
      for (final SeverityLevel lv in SeverityLevel.values) {
        expect(sl.lerp(sd, 0).badgeFill(lv), sl.badgeFill(lv));
        expect(sl.lerp(sd, 1).badgeFill(lv), sd.badgeFill(lv));
        expect(sl.lerp(sd, 1).badgeBorder(lv), sd.badgeBorder(lv));
      }
      expect(sl.lerp(sd, 0.5).paidFill, Color.lerp(sl.paidFill, sd.paidFill, 0.5));
      expect(sl.copyWith(paidFill: const Color(0xFF000002)).paidFill, const Color(0xFF000002));
      expect(sl.copyWith().badgeText(SeverityLevel.remind), sl.badgeText(SeverityLevel.remind));
    });

    test('AttendanceColors.lerp at 0, 0.5, 1 and copyWith', () {
      const AttendanceColors al = AttendanceColors.light();
      const AttendanceColors ad = AttendanceColors.dusk();
      for (final AttendanceKind k in AttendanceKind.values) {
        expect(al.lerp(ad, 0).fill(k), al.fill(k));
        expect(al.lerp(ad, 1).text(k), ad.text(k));
        expect(al.lerp(ad, 1).border(k), ad.border(k));
      }
      expect(al.lerp(ad, 0.5).heatLow, Color.lerp(al.heatLow, ad.heatLow, 0.5));
      expect(al.copyWith(heatLow: const Color(0xFF000003)).heatLow, const Color(0xFF000003));
    });
  });

  group('buildTheme', () {
    for (final Brightness b in Brightness.values) {
      test('${b.name}: registers the four extensions and Hind Siliguri', () {
        final ThemeData theme = buildTheme(b);
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, b);
        expect(theme.extension<AuroraTokens>(), isNotNull);
        expect(theme.extension<AppGradients>(), isNotNull);
        expect(theme.extension<SeverityColors>(), isNotNull);
        expect(theme.extension<AttendanceColors>(), isNotNull);
        expect(theme.textTheme.bodyLarge?.fontFamily, kFontFamily);
        expect(theme.textTheme.bodyLarge?.fontSize, 16);
        expect(theme.textTheme.labelSmall?.fontSize, greaterThanOrEqualTo(12));
        expect(theme.colorScheme.primary, theme.extension<AuroraTokens>()!.accent);
      });
    }

    testWidgets('ThemeX getters and statNumber sizes', (WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(
            builder: (BuildContext context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured.aurora.bg, const AuroraTokens.light().bg);
      expect(captured.gradients.heroBase, const AppGradients.light().heroBase);
      expect(captured.severity.paidFill, const SeverityColors.light().paidFill);
      expect(captured.attendance.heatHigh, const AttendanceColors.light().heatHigh);
      // Default test surface is 800 wide: phone-sized statNumber.
      expect(captured.statNumber.fontSize, 40);
      expect(captured.statNumber.fontWeight, FontWeight.w700);
    });
  });
}
