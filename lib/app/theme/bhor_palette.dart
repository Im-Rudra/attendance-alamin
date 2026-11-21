// Raw Bhor colour values (docs/council/10-design-system-bhor.md, Tokens).
// Lives in lib/app/theme/ because colour literals may only appear there
// (tool/check_domain_purity.sh rule 3). Everything else reads colours through
// `context.bhor.colors`.
//
// AA deviations from the spec table (verified in test/app/ds/bhor_contrast_test.dart):
// light text3 #8C8F98 -> #686B74, dark text3 #7A7F8C -> #8A8F9C, light accent2
// #6E63EE -> #6A5FEC, light danger #C23A52 -> #BD3550; dark primary-button text
// is near-black (white on #8B83FF is only 3.1:1).

import 'package:flutter/widgets.dart';

abstract final class BhorPaletteLight {
  static const Color bg = Color(0xFFF6F5F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF1EFEA);
  static const Color line = Color(0xFFE5E2DA);
  static const Color text = Color(0xFF17181C);
  static const Color text2 = Color(0xFF5E616A);
  static const Color text3 = Color(0xFF686B74);
  static const Color accent = Color(0xFF5B4FE0);
  static const Color accent2 = Color(0xFF6A5FEC);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color accentTint = Color(0xFFEEECFC);
  static const Color accentLine = Color(0xFFCBC6F6);
  static const Color ok = Color(0xFF0F7A58);
  static const Color okBg = Color(0xFFE2F3EC);
  static const Color danger = Color(0xFFBD3550);
  static const Color dangerBg = Color(0xFFFBE9EC);
  static const Color onDanger = Color(0xFFFFFFFF);
  static const Color heroStart = Color(0xFF4C42C9);
  static const Color heroEnd = Color(0xFF6A5BE0);
  static const Color onHero = Color(0xFFFFFFFF);
  static const Color absent = Color(0xFF3F4660);
  static const Color onAbsent = Color(0xFFFFFFFF);
  static const Color lateBg = Color(0xFFDDF0F4);
  static const Color lateText = Color(0xFF0E5566);
  static const Color scrim = Color(0x6617181C);
  static const Color pressShade = Color(0x14000000);
}

abstract final class BhorPaletteDark {
  static const Color bg = Color(0xFF0D0E12);
  static const Color surface = Color(0xFF16181E);
  static const Color surface2 = Color(0xFF1D2028);
  static const Color line = Color(0xFF272A34);
  static const Color text = Color(0xFFECEDF1);
  static const Color text2 = Color(0xFFA3A7B3);
  static const Color text3 = Color(0xFF8A8F9C);
  static const Color accent = Color(0xFF8B83FF);
  static const Color accent2 = Color(0xFF9C95FF);
  static const Color onAccent = Color(0xFF0D0E12);
  static const Color ok = Color(0xFF4CC79A);
  static const Color danger = Color(0xFFF07C8F);
  static const Color onDanger = Color(0xFF0D0E12);
  static const Color heroStart = Color(0xFF3B3399);
  static const Color heroEnd = Color(0xFF5A4BC4);
  static const Color onHero = Color(0xFFFFFFFF);
  static const Color absent = Color(0xFF3F4660);
  static const Color onAbsent = Color(0xFFFFFFFF);
  static const Color lateHue = Color(0xFF4FC3D9);
  static const Color lateText = Color(0xFF7FD3E6);
  static const Color scrim = Color(0x99000000);
  static const Color pressShade = Color(0x1F000000);
}
