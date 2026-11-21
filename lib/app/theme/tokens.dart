// Aurora Ink design tokens (UX 4, 5, 6). This is the ONLY place in the app
// where colour literals may appear (plan 2.10; enforced by
// tool/check_domain_purity.sh). Everything else reads them through
// `context.aurora`, `context.gradients`, `context.severity`,
// `context.attendance` (see theme_x.dart).
//
// `LightTokens` and `DuskTokens` expose the SAME member names so the two
// themes can never drift apart structurally.

import 'package:flutter/material.dart';

/// Font family bundled in pubspec (Hind Siliguri fork).
const String kFontFamily = 'HindSiliguri';

/// Non-colour constants shared by both themes (UX 4 radii / blur / spacing).
abstract final class AuroraMetrics {
  static const double radiusGlassCard = 20;
  static const double radiusHero = 24;
  static const double radiusSheetTop = 24;
  static const double radiusDialog = 20;
  static const double radiusDenseList = 16;
  static const double radiusChip = 8;
  static const double radiusField = 12;
  static const double radiusFab = 16;
  static const double radiusPill = 999;

  /// Gaussian blur sigma for `glass` surfaces.
  static const double blurGlass = 18;

  /// Gaussian blur sigma for `glassNav` surfaces.
  static const double blurNav = 24;

  /// Saturation multiplier applied with the glass blur.
  static const double glassSaturation = 1.4;

  /// Minimum height of a primary (pill) button.
  static const double buttonHeight = 52;

  /// Width at or above which `statNumber` uses its desktop size.
  static const double desktopBreakpoint = 840;
}

/// Index order of every per-level list below. Mirrors M1-B's `DueLevel`
/// declaration order (upcoming, justDue, remind, followUp, urgent,
/// finalDays, overdue), so `SeverityLevel.values[dueLevel.index]` maps 1:1.
enum SeverityLevel { upcoming, justDue, remind, followUp, urgent, finalDays, overdue }

/// Index order of every per-status list below. Mirrors M1-B's
/// `AttendanceStatus` declaration order (present, absent, late, leave), so
/// `AttendanceKind.values[status.index]` maps 1:1 (`leave` = Excused).
enum AttendanceKind { present, absent, late, leave }

/// Light theme.
abstract final class LightTokens {
  // ---- Backdrop -----------------------------------------------------------
  static const Color bg = Color(0xFFF3F4F9);

  /// Mesh pools: radial gradients whose centre is anchored to a corner/edge.
  /// Radius is expressed relative to the shorter side; the mesh widget (M4-D)
  /// applies the per-pool ellipse (UX 4 rule 7). Fades to 0 at 70% radius.
  static const RadialGradient meshA = RadialGradient(
    center: Alignment.topLeft,
    radius: 1.0,
    colors: [Color.fromRGBO(185, 176, 255, 0.69), Color.fromRGBO(185, 176, 255, 0)],
    stops: [0.0, 0.7],
  );
  static const RadialGradient meshB = RadialGradient(
    center: Alignment(1.0, -0.56),
    radius: 1.0,
    colors: [Color.fromRGBO(159, 227, 220, 0.63), Color.fromRGBO(159, 227, 220, 0)],
    stops: [0.0, 0.7],
  );
  static const RadialGradient meshC = RadialGradient(
    center: Alignment.bottomLeft,
    radius: 1.0,
    colors: [Color.fromRGBO(255, 211, 228, 0.56), Color.fromRGBO(255, 211, 228, 0)],
    stops: [0.0, 0.7],
  );
  static const double grainOpacity = 0.05;

  // ---- Surfaces -----------------------------------------------------------
  static const Color glass = Color.fromRGBO(255, 255, 255, 0.66);
  static const Color glassNav = Color.fromRGBO(255, 255, 255, 0.72);
  static const Color glassNoBlur = Color.fromRGBO(255, 255, 255, 0.82);
  static const Color surfaceDense = Color.fromRGBO(255, 255, 255, 0.94);
  static const Color surfaceSolid = Color(0xFFFFFFFF);
  static const Color hairline = Color.fromRGBO(18, 22, 40, 0.07);
  static const Color topHighlight = Color.fromRGBO(255, 255, 255, 0.90);
  static const Color track = Color.fromRGBO(18, 22, 40, 0.08);
  static const Color scrim = Color.fromRGBO(10, 12, 18, 0.40);

  // ---- Text and accent ----------------------------------------------------
  static const Color textPrimary = Color(0xFF12141C);
  static const Color textSecondary = Color(0xFF626882);
  static const Color textDisabled = Color.fromRGBO(18, 20, 28, 0.38);
  static const Color accent = Color(0xFF4C5BD4);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color accentContainer = Color.fromRGBO(76, 91, 212, 0.10);
  static const Color onAccentContainer = Color(0xFF2A3596);
  static const Color avatarBg = Color.fromRGBO(76, 91, 212, 0.12);
  static const Color avatarText = Color(0xFF3A47B8);
  static const Color statePillBg = Color.fromRGBO(18, 22, 40, 0.06);
  static const Color statePillText = Color(0xFF3A3F55);
  static const Color error = Color(0xFFB3261E);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFCE4E2);
  static const Color onErrorContainer = Color(0xFF5C0F0A);
  static const Color errorContainerBorder = Color(0x00B3261E);
  static const Color info = Color(0xFF2B5F8A);
  static const Color infoContainer = Color(0xFFE1EEF8);

  // ---- Hero card (the single saturated surface) ---------------------------
  static const Color heroBase = Color(0xFF2C3170);

  /// Violet radial at the top-left corner. Peak alpha 0.80 (UX says opaque):
  /// adjusted so white secondary text (85%) stays >= 4.5:1 in the corner.
  static const RadialGradient heroRadial1 = RadialGradient(
    center: Alignment.topLeft,
    radius: 0.9,
    colors: [Color.fromRGBO(110, 90, 230, 0.80), Color.fromRGBO(110, 90, 230, 0)],
  );

  /// Teal radial at the bottom-right corner, capped at 55% alpha.
  static const RadialGradient heroRadial2 = RadialGradient(
    center: Alignment.bottomRight,
    radius: 0.8,
    colors: [Color.fromRGBO(26, 163, 155, 0.55), Color.fromRGBO(26, 163, 155, 0)],
  );
  static const Color heroText = Color(0xFFFFFFFF);
  static const Color heroTextSecondary = Color.fromRGBO(255, 255, 255, 0.85);
  static const Color heroCtaFill = Color(0xFFF6F7FF);
  static const Color heroCtaText = Color(0xFF12141C);
  static const Color heroTopHighlight = Color.fromRGBO(255, 255, 255, 0.18);
  static const Color heroShadow = Color.fromRGBO(110, 90, 230, 0.28);

  // ---- Severity (UX 5). Index = SeverityLevel.index -----------------------
  static const List<Color> sevHue = [
    Color(0xFF4A5560), // upcoming (not due): same as its text
    Color(0xFFD9A520), // L1 honey
    Color(0xFFE8912B), // L2 amber
    Color(0xFFEE7A2E), // L3 tangerine
    Color(0xFFE8553A), // L4 coral
    Color(0xFFD93250), // L5 rose
    Color(0xFFB4194A), // OD raspberry
  ];
  static const List<Color> sevFill = [
    Color(0xFFEEF0F3),
    Color(0xFFFBEFC9),
    Color(0xFFFCE3C4),
    Color(0xFFFDD9C0),
    Color(0xFFFBCDC3),
    Color(0xFFF9CDD5),
    Color(0xFFB4194A),
  ];
  static const List<Color> sevText = [
    Color(0xFF4A5560),
    Color(0xFF5E4300),
    Color(0xFF5F3300),
    Color(0xFF6A2A00),
    Color(0xFF6E1A0C),
    Color(0xFF6E0A22),
    Color(0xFFFFFFFF),
  ];
  static const List<Color?> sevBorder = [
    Color.fromRGBO(74, 85, 96, 0.40), // upcoming: outlined
    null,
    null,
    null,
    null,
    Color(0xFFD93250), // L5: 1.5px rose border
    null, // OD: solid, no border in light
  ];
  static const Color paidFill = Color(0xFFDCF2E3);
  static const Color paidText = Color(0xFF14532D);
  static const Color waivedFill = Color(0xFFECEFF2);
  static const Color waivedText = Color(0xFF4A5560);
  static const Color waivedBorder = Color.fromRGBO(74, 85, 96, 0.40);
  static const Color notDueFill = Color(0xFFEEF0F3);
  static const Color notDueText = Color(0xFF4A5560);

  // ---- Attendance (UX 6). Index = AttendanceKind.index --------------------
  static const List<Color> attFill = [
    Color(0xFFE3F4E8), // present
    Color(0xFF3F4660), // absent: solid ink-slate
    Color(0xFFDDF1F7), // late
    Color(0xFFECEFF2), // leave / excused
  ];
  static const List<Color> attText = [
    Color(0xFF1B6B35),
    Color(0xFFFFFFFF),
    Color(0xFF0B5C73),
    Color(0xFF4A5560),
  ];
  static const List<Color?> attBorder = [
    null,
    null,
    null,
    Color.fromRGBO(74, 85, 96, 0.40), // excused: dashed outline
  ];
  static const Color heatLow = Color(0xFFE3F4E8);
  static const Color heatHigh = Color(0xFF1B6B35);
}

/// Dark theme ("Dusk"). Same member names as [LightTokens].
abstract final class DuskTokens {
  // ---- Backdrop -----------------------------------------------------------
  static const Color bg = Color(0xFF0A0C12);
  static const RadialGradient meshA = RadialGradient(
    center: Alignment.topLeft,
    radius: 1.0,
    colors: [Color.fromRGBO(90, 69, 208, 0.33), Color.fromRGBO(90, 69, 208, 0)],
    stops: [0.0, 0.7],
  );
  static const RadialGradient meshB = RadialGradient(
    center: Alignment(1.0, -0.56),
    radius: 1.0,
    colors: [Color.fromRGBO(14, 140, 134, 0.25), Color.fromRGBO(14, 140, 134, 0)],
    stops: [0.0, 0.7],
  );
  static const RadialGradient meshC = RadialGradient(
    center: Alignment.bottomLeft,
    radius: 1.0,
    colors: [Color.fromRGBO(58, 46, 143, 0.27), Color.fromRGBO(58, 46, 143, 0)],
    stops: [0.0, 0.7],
  );
  static const double grainOpacity = 0.07;

  // ---- Surfaces -----------------------------------------------------------
  static const Color glass = Color.fromRGBO(24, 28, 46, 0.55);
  static const Color glassNav = Color.fromRGBO(18, 21, 34, 0.62);
  static const Color glassNoBlur = Color.fromRGBO(22, 25, 40, 0.80);
  static const Color surfaceDense = Color.fromRGBO(20, 23, 36, 0.92);
  static const Color surfaceSolid = Color(0xFF151827);
  static const Color hairline = Color.fromRGBO(255, 255, 255, 0.07);
  static const Color topHighlight = Color.fromRGBO(255, 255, 255, 0.06);
  static const Color track = Color.fromRGBO(255, 255, 255, 0.08);
  static const Color scrim = Color.fromRGBO(5, 6, 10, 0.60);

  // ---- Text and accent ----------------------------------------------------
  static const Color textPrimary = Color(0xFFEEF0F8);
  static const Color textSecondary = Color(0xFF9298B0);
  static const Color textDisabled = Color.fromRGBO(238, 240, 248, 0.38);
  static const Color accent = Color(0xFFA8B8FF);
  static const Color onAccent = Color(0xFF141A3D);
  static const Color accentContainer = Color.fromRGBO(168, 184, 255, 0.14);
  static const Color onAccentContainer = Color(0xFFC3CCFF);
  static const Color avatarBg = Color.fromRGBO(120, 130, 220, 0.16);
  static const Color avatarText = Color(0xFFC3CCFF);
  static const Color statePillBg = Color.fromRGBO(255, 255, 255, 0.07);
  static const Color statePillText = Color(0xFFC9CDE0);
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF3B1A1E);
  static const Color onErrorContainer = Color(0xFFFFDAD6);
  static const Color errorContainerBorder = Color.fromRGBO(255, 180, 171, 0.40);
  static const Color info = Color(0xFF8FC8FF);
  static const Color infoContainer = Color.fromRGBO(143, 200, 255, 0.12);

  // ---- Hero card ----------------------------------------------------------
  static const Color heroBase = Color(0xFF1B2046);
  static const RadialGradient heroRadial1 = RadialGradient(
    center: Alignment.topLeft,
    radius: 0.9,
    colors: [Color.fromRGBO(90, 69, 208, 1.0), Color.fromRGBO(90, 69, 208, 0)],
  );
  static const RadialGradient heroRadial2 = RadialGradient(
    center: Alignment.bottomRight,
    radius: 0.8,
    colors: [Color.fromRGBO(14, 140, 134, 0.55), Color.fromRGBO(14, 140, 134, 0)],
  );
  static const Color heroText = Color(0xFFFFFFFF);
  static const Color heroTextSecondary = Color.fromRGBO(255, 255, 255, 0.85);
  static const Color heroCtaFill = Color(0xFFF6F7FF);
  static const Color heroCtaText = Color(0xFF12141C);
  static const Color heroTopHighlight = Color.fromRGBO(255, 255, 255, 0.12);
  static const Color heroShadow = Color.fromRGBO(90, 69, 208, 0.35);

  // ---- Severity (UX 5). Index = SeverityLevel.index -----------------------
  static const List<Color> sevHue = [
    Color(0xFFC3CBD3), // upcoming (not due): same as its text
    Color(0xFFD9A520),
    Color(0xFFE8912B),
    Color(0xFFEE7A2E),
    Color(0xFFE8553A),
    Color(0xFFD93250),
    Color(0xFFB4194A),
  ];
  static const List<Color> sevFill = [
    Color(0xFF2A2F35),
    Color(0xFF3A2E0A),
    Color(0xFF3D2510),
    Color(0xFF401F12),
    Color(0xFF431A17),
    Color(0xFF4A1424),
    Color(0xFFB4194A),
  ];
  static const List<Color> sevText = [
    Color(0xFFC3CBD3),
    Color(0xFFF5CF6A),
    Color(0xFFF7B567),
    Color(0xFFFF9F66),
    Color(0xFFFF8A73),
    Color(0xFFFF8FA3),
    Color(0xFFFFFFFF),
  ];
  // Dark tinted badges carry a 1px border of their text colour @ 40%.
  static const List<Color?> sevBorder = [
    Color.fromRGBO(195, 203, 211, 0.40),
    Color.fromRGBO(245, 207, 106, 0.40),
    Color.fromRGBO(247, 181, 103, 0.40),
    Color.fromRGBO(255, 159, 102, 0.40),
    Color.fromRGBO(255, 138, 115, 0.40),
    Color(0xFFD93250), // L5: 1.5px rose border
    Color.fromRGBO(255, 255, 255, 0.18), // OD: 1px white @ 18%
  ];
  static const Color paidFill = Color(0xFF163824);
  static const Color paidText = Color(0xFF9BE0B1);
  static const Color waivedFill = Color(0xFF2A3036);
  static const Color waivedText = Color(0xFFC3CBD3);
  static const Color waivedBorder = Color.fromRGBO(195, 203, 211, 0.40);
  static const Color notDueFill = Color(0xFF2A2F35);
  static const Color notDueText = Color(0xFFC3CBD3);

  // ---- Attendance (UX 6). Index = AttendanceKind.index --------------------
  static const List<Color> attFill = [
    Color(0xFF133222), // present
    Color(0xFF3F4660), // absent: solid ink-slate (same slab as light)
    Color(0xFF0F2E38), // late
    Color(0xFF2A3036), // leave / excused
  ];
  static const List<Color> attText = [
    Color(0xFF8FDCA6),
    Color(0xFFFFFFFF),
    Color(0xFF8BD3E8),
    Color(0xFFC3CBD3),
  ];
  static const List<Color?> attBorder = [
    Color.fromRGBO(143, 220, 166, 0.40),
    null,
    Color.fromRGBO(139, 211, 232, 0.40),
    Color.fromRGBO(195, 203, 211, 0.40),
  ];
  static const Color heatLow = Color(0xFF133222);
  static const Color heatHigh = Color(0xFF8FDCA6);
}
