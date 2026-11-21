// Bhor tokens: colours (light/dark), type scale, spacing, radii, sizes and
// motion (docs/council/10-design-system-bhor.md). Read them with
// `context.bhor` (see bhor_theme.dart); never hard-code values in screens.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/theme/bhor_palette.dart';
import 'package:attendance_alamin/app/theme/tokens.dart'
    show DuskTokens, LightTokens, SeverityLevel, kFontFamily;

/// Semantic colours of one theme. Translucent values (dark tints) are meant
/// to be painted over [surface] or [bg].
class BhorColors {
  const BhorColors({
    required this.brightness,
    required this.bg,
    required this.washStart,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accent2,
    required this.onAccent,
    required this.accentTint,
    required this.accentLine,
    required this.focusRing,
    required this.ok,
    required this.okBg,
    required this.danger,
    required this.dangerBg,
    required this.onDanger,
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
    required this.absent,
    required this.onAbsent,
    required this.lateBg,
    required this.lateText,
    required this.scrim,
    required this.pressShade,
    required this.sevHue,
    required this.sevFill,
    required this.sevText,
  });

  final Brightness brightness;
  final Color bg;

  /// Inner colour of the faint top-left page wash (fades to transparent).
  final Color washStart;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color text;
  final Color text2;
  final Color text3;
  final Color accent;
  final Color accent2;
  final Color onAccent;
  final Color accentTint;
  final Color accentLine;
  final Color focusRing;
  final Color ok;
  final Color okBg;
  final Color danger;
  final Color dangerBg;
  final Color onDanger;
  final Color heroStart;
  final Color heroEnd;
  final Color onHero;
  final Color absent;
  final Color onAbsent;
  final Color lateBg;
  final Color lateText;
  final Color scrim;
  final Color pressShade;

  /// Dues severity hues / tag fills / tag texts, index = [SeverityLevel.index].
  final List<Color> sevHue;
  final List<Color> sevFill;
  final List<Color> sevText;

  bool get isDark => brightness == Brightness.dark;

  /// Hero card gradient (140 degrees).
  LinearGradient get heroGradient => LinearGradient(
        begin: const Alignment(-0.77, -0.64),
        end: const Alignment(0.77, 0.64),
        colors: <Color>[heroStart, heroEnd],
      );

  /// Primary button gradient (accent2 on top, accent below).
  LinearGradient get buttonGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[accent2, accent],
      );

  /// Escalation-bar colour of day [day] (1..10; beyond 10 is overdue).
  Color segment(int day) {
    if (day < 1) return sevHue[SeverityLevel.upcoming.index];
    if (day > 10) return sevHue[SeverityLevel.overdue.index];
    return sevHue[(day - 1) ~/ 2 + 1];
  }

  static final BhorColors light = BhorColors(
    brightness: Brightness.light,
    bg: BhorPaletteLight.bg,
    washStart: BhorPaletteLight.accent.withValues(alpha: 0.07),
    surface: BhorPaletteLight.surface,
    surface2: BhorPaletteLight.surface2,
    line: BhorPaletteLight.line,
    text: BhorPaletteLight.text,
    text2: BhorPaletteLight.text2,
    text3: BhorPaletteLight.text3,
    accent: BhorPaletteLight.accent,
    accent2: BhorPaletteLight.accent2,
    onAccent: BhorPaletteLight.onAccent,
    accentTint: BhorPaletteLight.accentTint,
    accentLine: BhorPaletteLight.accentLine,
    focusRing: BhorPaletteLight.accent.withValues(alpha: 0.14),
    ok: BhorPaletteLight.ok,
    okBg: BhorPaletteLight.okBg,
    danger: BhorPaletteLight.danger,
    dangerBg: BhorPaletteLight.dangerBg,
    onDanger: BhorPaletteLight.onDanger,
    heroStart: BhorPaletteLight.heroStart,
    heroEnd: BhorPaletteLight.heroEnd,
    onHero: BhorPaletteLight.onHero,
    absent: BhorPaletteLight.absent,
    onAbsent: BhorPaletteLight.onAbsent,
    lateBg: BhorPaletteLight.lateBg,
    lateText: BhorPaletteLight.lateText,
    scrim: BhorPaletteLight.scrim,
    pressShade: BhorPaletteLight.pressShade,
    sevHue: LightTokens.sevHue,
    sevFill: LightTokens.sevFill,
    sevText: LightTokens.sevText,
  );

  static final BhorColors dark = BhorColors(
    brightness: Brightness.dark,
    bg: BhorPaletteDark.bg,
    washStart: BhorPaletteDark.accent.withValues(alpha: 0.10),
    surface: BhorPaletteDark.surface,
    surface2: BhorPaletteDark.surface2,
    line: BhorPaletteDark.line,
    text: BhorPaletteDark.text,
    text2: BhorPaletteDark.text2,
    text3: BhorPaletteDark.text3,
    accent: BhorPaletteDark.accent,
    accent2: BhorPaletteDark.accent2,
    onAccent: BhorPaletteDark.onAccent,
    accentTint: BhorPaletteDark.accent.withValues(alpha: 0.14),
    accentLine: BhorPaletteDark.accent.withValues(alpha: 0.35),
    focusRing: BhorPaletteDark.accent.withValues(alpha: 0.18),
    ok: BhorPaletteDark.ok,
    okBg: BhorPaletteDark.ok.withValues(alpha: 0.13),
    danger: BhorPaletteDark.danger,
    dangerBg: BhorPaletteDark.danger.withValues(alpha: 0.12),
    onDanger: BhorPaletteDark.onDanger,
    heroStart: BhorPaletteDark.heroStart,
    heroEnd: BhorPaletteDark.heroEnd,
    onHero: BhorPaletteDark.onHero,
    absent: BhorPaletteDark.absent,
    onAbsent: BhorPaletteDark.onAbsent,
    lateBg: BhorPaletteDark.lateHue.withValues(alpha: 0.15),
    lateText: BhorPaletteDark.lateText,
    scrim: BhorPaletteDark.scrim,
    pressShade: BhorPaletteDark.pressShade,
    sevHue: DuskTokens.sevHue,
    sevFill: DuskTokens.sevFill,
    sevText: DuskTokens.sevText,
  );
}

/// Type scale (Hind Siliguri, line height 1.45 for Bangla). Colours default
/// to the theme's [BhorColors.text]; recolour with `copyWith`.
class BhorType {
  BhorType(Color text, Color text2)
      : display = _s(24, FontWeight.w700, text, tracking: -0.3),
        title = _s(18, FontWeight.w700, text),
        heading = _s(15, FontWeight.w600, text),
        body = _s(14, FontWeight.w400, text),
        bodyStrong = _s(14, FontWeight.w600, text),
        label = _s(12.5, FontWeight.w600, text),
        meta = _s(12, FontWeight.w400, text2),
        caption = _s(11, FontWeight.w400, text2),
        stat = _s(22, FontWeight.w700, text).copyWith(fontFeatures: _tabular);

  static const List<FontFeature> _tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// Line height of every style.
  static const double lineHeight = 1.45;

  final TextStyle display;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle label;
  final TextStyle meta;
  final TextStyle caption;
  final TextStyle stat;

  /// [style] with tabular figures (money, counts, times).
  static TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: _tabular);

  static TextStyle _s(double size, FontWeight w, Color c, {double tracking = 0}) => TextStyle(
        fontFamily: kFontFamily,
        fontSize: size,
        fontWeight: w,
        height: lineHeight,
        letterSpacing: tracking,
        color: c,
        decoration: TextDecoration.none,
      );
}

/// 4-pt spacing grid.
abstract final class BhorSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
}

/// Corner radii.
abstract final class BhorRadius {
  static const double control = 12;
  static const double card = 16;
  static const double hero = 18;
  static const double sheet = 20;
  static const double tag = 6;
  static const double chip = 10;
  static const double avatar = 9;
}

/// Control heights and tap targets.
abstract final class BhorSize {
  static const double control = 44;
  static const double compact = 36;
  static const double minTap = 44;
  static const double phoneRow = 48;
  static const double focusRingWidth = 4;
}

/// Motion: 120-200 ms, ease-out.
abstract final class BhorMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 160);
  static const Duration slow = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOutCubic;
  static const double pressScale = 0.98;
}
