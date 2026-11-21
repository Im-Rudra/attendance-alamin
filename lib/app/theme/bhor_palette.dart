// Raw Bhor colour values (docs/council/13-fluid-ui-spec.md, Tokens; first
// defined in 10-design-system-bhor.md). Lives in lib/app/theme/ because colour
// literals may only appear there (tool/check_domain_purity.sh rule 3).
// Everything else reads colours through `context.bhor.colors`.
//
// AA deviations from the fluid spec table (verified in
// test/app/ds/bhor_contrast_test.dart):
// - light text3 #74777F -> #686B74 (3.8:1 on the soft fill otherwise).
// - light error #C23A52 -> #BD3550 (4.5:1 on soft / overdue tint).
// - dark accent #7B72F6 is split: accent TEXT/icons #928BF9 (4.5:1 on soft and
//   on its own 16% tint) and the solid accent FILL #6A61EA under white text
//   (white on #7B72F6 is only 3.8:1). Hover fill #6158E3 (darker, so white
//   stays AA). Legacy `accent` fills keep a near-black `onAccent` in dark.
// - segmentEdge (not in the spec table): the selected segmented thumb's 1 px
//   edge. Dark #727786 is 3.5:1 on the soft track (the spec's #3A3F4B is
//   1.4:1, so the thumb was hard to find); light keeps the line colour (the
//   white thumb + shadow already separates it).

import 'package:flutter/widgets.dart';

abstract final class BhorPaletteLight {
  static const Color bg = Color(0xFFF6F5F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color soft = Color(0xFFEFEDE8);
  static const Color soft2 = Color(0xFFE3E0D8);
  static const Color line = Color(0xFFE7E4DD);
  static const Color text = Color(0xFF17181C);
  static const Color text2 = Color(0xFF55585F);
  static const Color text3 = Color(0xFF686B74);
  static const Color accent = Color(0xFF5B4FE0);
  static const Color accentHover = Color(0xFF5045D2);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color accentTint = Color(0xFFEDEBFC);
  static const Color accentLine = Color(0xFFCBC6F6);
  static const Color ok = Color(0xFF0F7A58);
  static const Color okBg = Color(0xFFE2F3EC);
  static const Color warn = Color(0xFF8A4A00);
  static const Color warnBg = Color(0xFFFCEBD5);
  static const Color overdue = Color(0xFFA3153F);
  static const Color overdueBg = Color(0xFFFBE3E8);
  static const Color absentText = Color(0xFF3F4660);
  static const Color absentBg = Color(0xFFE6E8EE);
  static const Color late = Color(0xFF0B6A80);
  static const Color lateBg = Color(0xFFDDF0F4);
  static const Color error = Color(0xFFBD3550);
  static const Color onDanger = Color(0xFFFFFFFF);
  static const Color heroStart = Color(0xFF4C42C9);
  static const Color heroEnd = Color(0xFF6A5BE0);
  static const Color onHero = Color(0xFFFFFFFF);
  static const Color heroButton = Color(0xFFFAFAFF);

  /// Legacy solid absent fill (white text) kept for existing callers.
  static const Color absent = Color(0xFF3F4660);
  static const Color onAbsent = Color(0xFFFFFFFF);
  static const Color lateText = Color(0xFF0B6A80);
  static const Color scrim = Color(0x6617181C);
  static const Color panelScrim = Color(0x3317181C);
  static const Color segmentEdge = Color(0xFFE3E0D8);
  static const Color pressShade = Color(0x14000000);
  static const Color shadow = Color(0x1A17181C);
  static const Color highlight = Color(0x29FFFFFF);
}

abstract final class BhorPaletteDark {
  static const Color bg = Color(0xFF0F1014);
  static const Color surface = Color(0xFF191B21);
  static const Color soft = Color(0xFF21242C);
  static const Color soft2 = Color(0xFF2E323C);
  static const Color line = Color(0xFF262932);
  static const Color text = Color(0xFFEDEEF2);
  static const Color text2 = Color(0xFFB0B4BF);
  static const Color text3 = Color(0xFF8D92A0);
  static const Color accent = Color(0xFF928BF9);
  static const Color accentFill = Color(0xFF6A61EA);
  static const Color accentFillHover = Color(0xFF6158E3);
  static const Color accentHover = Color(0xFF9C95FA);
  static const Color onAccent = Color(0xFF0F1014);
  static const Color onAccentFill = Color(0xFFFFFFFF);
  static const Color ok = Color(0xFF5CD3A6);
  static const Color warn = Color(0xFFF2B866);
  static const Color overdue = Color(0xFFFF8FA6);
  static const Color overdueHue = Color(0xFFE0526F);
  static const Color absentText = Color(0xFFD0D5E4);
  static const Color late = Color(0xFF8FDCEC);
  static const Color error = Color(0xFFF07C8F);
  static const Color onDanger = Color(0xFF0F1014);
  static const Color heroStart = Color(0xFF3B3399);
  static const Color heroEnd = Color(0xFF5A4BC4);
  static const Color onHero = Color(0xFFFFFFFF);
  static const Color heroButton = Color(0xFFF4F3FF);

  /// Legacy solid absent fill (white text) kept for existing callers.
  static const Color absent = Color(0xFF3F4660);
  static const Color onAbsent = Color(0xFFFFFFFF);
  static const Color lateText = Color(0xFF8FDCEC);
  static const Color scrim = Color(0x99000000);
  static const Color panelScrim = Color(0x59000000);
  static const Color segmentEdge = Color(0xFF727786);
  static const Color pressShade = Color(0x1F000000);
  static const Color shadow = Color(0x66000000);
  static const Color highlight = Color(0x29FFFFFF);
}
