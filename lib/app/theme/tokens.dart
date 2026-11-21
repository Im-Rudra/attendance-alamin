// Shared theme tokens kept from the Aurora era for the Bhor design system
// (docs/council/10-design-system-bhor.md): the font family, the severity and
// attendance enums, and the dues severity hues (honey -> rose escalation and
// the solid overdue #B4194A), which Bhor reuses as compact tags.
//
// Colour literals may appear only under lib/app/theme/ (plan 2.10; enforced by
// tool/check_domain_purity.sh). Bhor reads these through `context.bhor`
// (lib/app/ds/foundation/bhor_tokens.dart). `LightTokens` and `DuskTokens`
// expose the SAME member names so the two themes can never drift apart.

import 'package:flutter/widgets.dart';

/// Font family bundled in pubspec (Hind Siliguri fork).
const String kFontFamily = 'HindSiliguri';

/// Index order of every per-level list below. Mirrors M1-B's `DueLevel`
/// declaration order (upcoming, justDue, remind, followUp, urgent,
/// finalDays, overdue), so `SeverityLevel.values[dueLevel.index]` maps 1:1.
enum SeverityLevel { upcoming, justDue, remind, followUp, urgent, finalDays, overdue }

/// Index order of the attendance statuses. Mirrors M1-B's `AttendanceStatus`
/// declaration order (present, absent, late, leave), so
/// `AttendanceKind.values[status.index]` maps 1:1 (`leave` = Excused).
enum AttendanceKind { present, absent, late, leave }

/// Light theme severity colours (UX 5). Index = SeverityLevel.index.
abstract final class LightTokens {
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
}

/// Dark theme severity colours (UX 5). Index = SeverityLevel.index.
abstract final class DuskTokens {
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
}
