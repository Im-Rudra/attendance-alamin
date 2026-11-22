// Bhor tokens: colours (light/dark), type scale, spacing, radii, sizes and
// motion (docs/council/13-fluid-ui-spec.md; first set in
// 10-design-system-bhor.md). Read them with `context.bhor` (see
// bhor_theme.dart); never hard-code values in screens.
//
// Fluid additions (all older names still work):
// - soft / soft2: the filled-control fill and its hover/pressed shade
//   (surface2 is the same as soft).
// - accentFill / onAccentFill / accentFillHover: solid primary fills with
//   white text (buttons, switch track, brand mark, active thumbs). `accent`
//   stays the accent for TEXT and icons; its legacy `onAccent` contrasts with
//   it (near-black in dark).
// - warn / overdue / absentText / late with their tints, error, shadow
//   (floating toasts, menus and panels only), highlight (button top edge).

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/theme/bhor_palette.dart';
import 'package:attendance_alamin/app/theme/tokens.dart'
    show DuskTokens, LightTokens, SeverityLevel, kFontFamily;
import 'package:attendance_alamin/app/widgets/effects_mode.dart';

/// Semantic colours of one theme. Translucent values (dark tints) are meant
/// to be painted over [surface] or [bg].
class BhorColors {
  const BhorColors({
    required this.brightness,
    required this.bg,
    required this.washStart,
    required this.surface,
    required this.surface2,
    required this.soft,
    required this.soft2,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accent2,
    required this.accentHover,
    required this.onAccent,
    required this.accentFill,
    required this.accentFillHover,
    required this.onAccentFill,
    required this.accentTint,
    required this.accentLine,
    required this.focusRing,
    required this.ok,
    required this.okBg,
    required this.warn,
    required this.warnBg,
    required this.overdue,
    required this.overdueBg,
    required this.danger,
    required this.dangerBg,
    required this.onDanger,
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
    required this.heroButton,
    required this.absent,
    required this.onAbsent,
    required this.absentText,
    required this.absentBg,
    required this.late,
    required this.lateBg,
    required this.lateText,
    required this.scrim,
    required this.panelScrim,
    required this.segmentEdge,
    required this.thumb,
    required this.pressShade,
    required this.shadow,
    required this.highlight,
    required this.sevHue,
    required this.sevFill,
    required this.sevText,
  });

  final Brightness brightness;
  final Color bg;

  /// Inner colour of the faint top-left page wash (fades to transparent).
  final Color washStart;
  final Color surface;

  /// Same as [soft] (older name).
  final Color surface2;

  /// Fill of soft controls (fields, segmented track, chips, icon buttons).
  final Color soft;

  /// Hover / pressed shade of [soft].
  final Color soft2;
  final Color line;
  final Color text;
  final Color text2;
  final Color text3;

  /// Accent for text and icons.
  final Color accent;

  /// Older name of [accentHover].
  final Color accent2;
  final Color accentHover;

  /// Text on a solid [accent] fill (legacy fills).
  final Color onAccent;

  /// Solid accent fill under [onAccentFill] (white) text.
  final Color accentFill;
  final Color accentFillHover;
  final Color onAccentFill;
  final Color accentTint;
  final Color accentLine;
  final Color focusRing;
  final Color ok;
  final Color okBg;
  final Color warn;
  final Color warnBg;
  final Color overdue;
  final Color overdueBg;

  /// The error colour (text, rings, danger buttons).
  final Color danger;
  final Color dangerBg;
  final Color onDanger;
  final Color heroStart;
  final Color heroEnd;
  final Color onHero;

  /// Near-white solid button on the hero card (hero-colour text).
  final Color heroButton;

  /// Legacy solid absent fill (with [onAbsent] text).
  final Color absent;
  final Color onAbsent;

  /// Absent status text / icon and its tint (attendance thumb, tags).
  final Color absentText;
  final Color absentBg;
  final Color late;
  final Color lateBg;
  final Color lateText;
  final Color scrim;

  /// The lighter dim behind a desktop side panel (the list stays visible).
  final Color panelScrim;

  /// Edge of the selected segmented thumb (dark: >= 3:1 against the track).
  /// No longer painted (selected states are filled, never ringed); kept for
  /// callers and the contrast table.
  final Color segmentEdge;

  /// Fill of a selected thumb on a soft track (segmented control, BhorTabs):
  /// white in light, a lifted grey in dark. Filled, never outlined.
  final Color thumb;
  final Color pressShade;

  /// Soft neutral shadow: only floating toasts, menus and panels use it.
  final Color shadow;

  /// 1px inner top highlight of the primary button.
  final Color highlight;

  /// Dues severity hues / tag fills / tag texts, index = [SeverityLevel.index].
  final List<Color> sevHue;
  final List<Color> sevFill;
  final List<Color> sevText;

  bool get isDark => brightness == Brightness.dark;

  /// The error colour (same as [danger]).
  Color get error => danger;

  /// Hero card gradient (140 degrees). The only gradient in the app.
  LinearGradient get heroGradient => LinearGradient(
        begin: const Alignment(-0.77, -0.64),
        end: const Alignment(0.77, 0.64),
        colors: <Color>[heroStart, heroEnd],
      );

  /// Older primary-button fill, now a flat accent fill (no gradients
  /// outside the hero card).
  LinearGradient get buttonGradient => LinearGradient(colors: <Color>[accentFill, accentFill]);

  /// Floating elevation (toasts, menus, side panels): a soft neutral shadow.
  List<BoxShadow> get floatShadow => <BoxShadow>[
        BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8)),
      ];

  /// The tiny shadow under a segmented / switch thumb.
  List<BoxShadow> get thumbShadow => <BoxShadow>[
        BoxShadow(color: shadow.withValues(alpha: shadow.a * 0.6), blurRadius: 3, offset: const Offset(0, 1)),
      ];

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
    surface2: BhorPaletteLight.soft,
    soft: BhorPaletteLight.soft,
    soft2: BhorPaletteLight.soft2,
    line: BhorPaletteLight.line,
    text: BhorPaletteLight.text,
    text2: BhorPaletteLight.text2,
    text3: BhorPaletteLight.text3,
    accent: BhorPaletteLight.accent,
    accent2: BhorPaletteLight.accentHover,
    accentHover: BhorPaletteLight.accentHover,
    onAccent: BhorPaletteLight.onAccent,
    accentFill: BhorPaletteLight.accent,
    accentFillHover: BhorPaletteLight.accentHover,
    onAccentFill: BhorPaletteLight.onAccent,
    accentTint: BhorPaletteLight.accentTint,
    accentLine: BhorPaletteLight.accentLine,
    focusRing: BhorPaletteLight.accent.withValues(alpha: 0.14),
    ok: BhorPaletteLight.ok,
    okBg: BhorPaletteLight.okBg,
    warn: BhorPaletteLight.warn,
    warnBg: BhorPaletteLight.warnBg,
    overdue: BhorPaletteLight.overdue,
    overdueBg: BhorPaletteLight.overdueBg,
    danger: BhorPaletteLight.error,
    dangerBg: BhorPaletteLight.overdueBg,
    onDanger: BhorPaletteLight.onDanger,
    heroStart: BhorPaletteLight.heroStart,
    heroEnd: BhorPaletteLight.heroEnd,
    onHero: BhorPaletteLight.onHero,
    heroButton: BhorPaletteLight.heroButton,
    absent: BhorPaletteLight.absent,
    onAbsent: BhorPaletteLight.onAbsent,
    absentText: BhorPaletteLight.absentText,
    absentBg: BhorPaletteLight.absentBg,
    late: BhorPaletteLight.late,
    lateBg: BhorPaletteLight.lateBg,
    lateText: BhorPaletteLight.lateText,
    scrim: BhorPaletteLight.scrim,
    panelScrim: BhorPaletteLight.panelScrim,
    segmentEdge: BhorPaletteLight.segmentEdge,
    thumb: BhorPaletteLight.surface,
    pressShade: BhorPaletteLight.pressShade,
    shadow: BhorPaletteLight.shadow,
    highlight: BhorPaletteLight.highlight,
    sevHue: LightTokens.sevHue,
    sevFill: LightTokens.sevFill,
    sevText: LightTokens.sevText,
  );

  static final BhorColors dark = BhorColors(
    brightness: Brightness.dark,
    bg: BhorPaletteDark.bg,
    washStart: BhorPaletteDark.accent.withValues(alpha: 0.10),
    surface: BhorPaletteDark.surface,
    surface2: BhorPaletteDark.soft,
    soft: BhorPaletteDark.soft,
    soft2: BhorPaletteDark.soft2,
    line: BhorPaletteDark.line,
    text: BhorPaletteDark.text,
    text2: BhorPaletteDark.text2,
    text3: BhorPaletteDark.text3,
    accent: BhorPaletteDark.accent,
    accent2: BhorPaletteDark.accentHover,
    accentHover: BhorPaletteDark.accentHover,
    onAccent: BhorPaletteDark.onAccent,
    accentFill: BhorPaletteDark.accentFill,
    accentFillHover: BhorPaletteDark.accentFillHover,
    onAccentFill: BhorPaletteDark.onAccentFill,
    accentTint: BhorPaletteDark.accent.withValues(alpha: 0.16),
    accentLine: BhorPaletteDark.accent.withValues(alpha: 0.35),
    focusRing: BhorPaletteDark.accent.withValues(alpha: 0.22),
    ok: BhorPaletteDark.ok,
    okBg: BhorPaletteDark.ok.withValues(alpha: 0.15),
    warn: BhorPaletteDark.warn,
    warnBg: BhorPaletteDark.warn.withValues(alpha: 0.15),
    overdue: BhorPaletteDark.overdue,
    overdueBg: BhorPaletteDark.overdueHue.withValues(alpha: 0.18),
    danger: BhorPaletteDark.error,
    dangerBg: BhorPaletteDark.overdueHue.withValues(alpha: 0.18),
    onDanger: BhorPaletteDark.onDanger,
    heroStart: BhorPaletteDark.heroStart,
    heroEnd: BhorPaletteDark.heroEnd,
    onHero: BhorPaletteDark.onHero,
    heroButton: BhorPaletteDark.heroButton,
    absent: BhorPaletteDark.absent,
    onAbsent: BhorPaletteDark.onAbsent,
    absentText: BhorPaletteDark.absentText,
    absentBg: BhorPaletteDark.absentText.withValues(alpha: 0.20),
    late: BhorPaletteDark.late,
    lateBg: BhorPaletteDark.late.withValues(alpha: 0.16),
    lateText: BhorPaletteDark.lateText,
    scrim: BhorPaletteDark.scrim,
    panelScrim: BhorPaletteDark.panelScrim,
    segmentEdge: BhorPaletteDark.segmentEdge,
    // soft2 lifted 40% toward text3 (#545864): text stays AA on it and the
    // thumb separates from the soft track without an edge.
    thumb: Color.lerp(BhorPaletteDark.soft2, BhorPaletteDark.text3, 0.4)!,
    pressShade: BhorPaletteDark.pressShade,
    shadow: BhorPaletteDark.shadow,
    highlight: BhorPaletteDark.highlight,
    sevHue: DuskTokens.sevHue,
    sevFill: DuskTokens.sevFill,
    sevText: DuskTokens.sevText,
  );
}

/// Type scale (Hind Siliguri, line height 1.45 for Bangla). Bangla never
/// below 12.5; body 14.5; titles 17-26 bold. Colours default to the theme's
/// [BhorColors.text]; recolour with `copyWith`.
///
/// Desktop step (docs/council/16-windows-rebuild-plan.md W1-B 1): windows at
/// least [desktopMinWidth] wide get display 28, title 22, heading 18, body
/// 15, stat 30 (label 13.5, meta / caption 13). Phones are unchanged.
/// `BhorThemeData.of(brightness, desktop: true)` carries it; the app root
/// picks it from the window width.
class BhorType {
  BhorType(Color text, Color text2, {this.desktop = false})
      : display = _s(desktop ? 28 : 26, FontWeight.w700, text, tracking: -0.3),
        title = _s(desktop ? 22 : 19, FontWeight.w700, text, tracking: -0.1),
        heading = _s(desktop ? 18 : 16, FontWeight.w600, text),
        body = _s(desktop ? 15 : 14.5, FontWeight.w400, text),
        bodyStrong = _s(desktop ? 15 : 14.5, FontWeight.w600, text),
        label = _s(desktop ? 13.5 : 13, FontWeight.w600, text),
        meta = _s(desktop ? 13 : 12.5, FontWeight.w400, text2),
        caption = _s(desktop ? 13 : 12.5, FontWeight.w400, text2),
        stat = _s(desktop ? 30 : 24, FontWeight.w700, text, tracking: -0.2).copyWith(fontFeatures: _tabular);

  /// Window width (logical px) from which the desktop step applies.
  static const double desktopMinWidth = 1200;

  /// True for the desktop step.
  final bool desktop;

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

  /// Screen padding on phones / desktop.
  static const double screenPhone = 16;
  static const double screenDesktop = 24;
}

/// Corner radii.
abstract final class BhorRadius {
  /// Buttons, fields, segmented track, menus.
  static const double control = 14;

  /// Cards.
  static const double card = 18;

  /// Lists (surface card holding rows).
  static const double list = 20;
  static const double hero = 22;

  /// Bottom sheet top corners.
  static const double sheet = 28;

  /// Floating desktop side panel and dialogs.
  static const double panel = 20;

  /// Phone floating nav pill.
  static const double nav = 20;

  /// Chips, tags, toasts, the attendance pill.
  static const double pill = 999;

  /// Status tags (pills).
  static const double tag = pill;

  /// Small cells (calendar days, week blocks). Not a chip shape any more:
  /// BhorChip uses [pill].
  static const double chip = 10;

  /// Square avatar radius at 36 (older look; BhorAvatar is a circle now).
  static const double avatar = 9;

  /// The soft back button.
  static const double back = 13;

  /// Desktop sidebar items.
  static const double sidebarItem = 12;
}

/// Control heights and tap targets.
abstract final class BhorSize {
  /// Buttons (md) and icon buttons.
  static const double control = 46;

  /// Small buttons, chips.
  static const double compact = 38;

  /// Large sticky CTA.
  static const double large = 52;

  /// Filled text field with a floating label.
  static const double field = 56;
  static const double minTap = 44;
  static const double phoneRow = 48;
  static const double focusRingWidth = 4;
}

/// Motion tokens (docs/council/13-fluid-ui-spec.md "Motion tokens",
/// 12-ux-review.md section 4). Springs are expressed both as
/// [SpringDescription]s (drag release, physics) and as overshooting
/// [Cubic] curves for implicit animations, so tests can settle them.
///
/// Reduced motion ([reduced]: the app's reduced-effects flag, the OS
/// "remove animations" or high-contrast setting): every transform becomes a
/// 120 ms cross-fade, count-ups show the final value, stagger is 0.
abstract final class BhorMotion {
  /// Press-in.
  static const Duration instant = Duration(milliseconds: 80);

  /// Toggles, chips, colour changes, icon swaps.
  static const Duration fast = Duration(milliseconds: 180);

  /// Cross-fades, popovers, list inserts.
  static const Duration base = Duration(milliseconds: 260);

  /// Sheets, panels, gliding indicators, page pushes.
  static const Duration slow = Duration(milliseconds: 450);

  /// Thumbs and segmented indicators (spring).
  static const Duration glide = Duration(milliseconds: 400);

  /// Number count-ups (scaled by distance between 260 and 480).
  static const Duration countUp = Duration(milliseconds: 420);
  static const Duration countUpMin = Duration(milliseconds: 260);
  static const Duration countUpMax = Duration(milliseconds: 480);

  /// Exits are shorter than entries.
  static const Duration exit = Duration(milliseconds: 220);

  /// The reduced-motion cross-fade.
  static const Duration reducedFade = Duration(milliseconds: 120);

  /// First-load stagger step and the number of items that stagger.
  static const Duration staggerStep = Duration(milliseconds: 30);
  static const int staggerCap = 8;

  /// cubic-bezier(.2,0,0,1): fades and colour.
  static const Curve ease = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Older name of [ease] (every existing caller keeps working).
  static const Curve curve = ease;

  /// cubic-bezier(.3,0,1,1): exits (accelerate).
  static const Curve exitCurve = Cubic(0.3, 0.0, 1.0, 1.0);

  /// cubic-bezier(.34,1.4,.64,1): the spring (thumbs, indicators, sheets,
  /// chips, toasts, press-release). Overshoots: never use it for opacity or
  /// colour.
  static const Curve spring = Cubic(0.34, 1.4, 0.64, 1.0);

  /// A gentler overshoot for large surfaces (sheets, side panels).
  static const Curve springSoft = Cubic(0.3, 1.18, 0.6, 1.0);

  /// cubic-bezier(.16,1,.3,1): count-ups and progress fills.
  static const Curve countCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Thumbs, toggles, press-release (≈ [spring]).
  static const SpringDescription springSnappy = SpringDescription(mass: 1, stiffness: 420, damping: 26);

  /// Sheets and drag release.
  static const SpringDescription springGentle = SpringDescription(mass: 1, stiffness: 380, damping: 32);

  /// The success check pop (small overshoot).
  static const SpringDescription springPop = SpringDescription(mass: 1, stiffness: 500, damping: 18);

  /// Press scale of buttons; .9 for stepper buttons.
  static const double pressScale = 0.96;
  static const double pressScaleSmall = 0.9;

  /// Rise / slide offsets.
  static const double distanceSm = 6;
  static const double distanceMd = 16;
  static const double distanceLg = 32;

  /// True when motion must be reduced for [context].
  static bool reduced(BuildContext context) => EffectsMode.reducedOf(context);

  /// [d], or the 120 ms fade when motion is reduced.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? reducedFade : d;

  /// [c], or a plain ease when motion is reduced (no overshoot).
  static Curve curveOf(BuildContext context, Curve c) => reduced(context) ? ease : c;
}
