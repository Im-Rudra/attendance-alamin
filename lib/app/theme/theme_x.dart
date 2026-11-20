// Theme access (plan 2.10): no literal colours outside lib/app/theme/.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/app_theme.dart';
import 'package:attendance_alamin/app/theme/extensions/app_gradients.dart';
import 'package:attendance_alamin/app/theme/extensions/attendance_colors.dart';
import 'package:attendance_alamin/app/theme/extensions/aurora_tokens.dart';
import 'package:attendance_alamin/app/theme/extensions/severity_colors.dart';
import 'package:attendance_alamin/app/theme/tokens.dart';

export 'package:attendance_alamin/app/theme/app_theme.dart' show buildTheme;
export 'package:attendance_alamin/app/theme/extensions/app_gradients.dart';
export 'package:attendance_alamin/app/theme/extensions/attendance_colors.dart';
export 'package:attendance_alamin/app/theme/extensions/aurora_tokens.dart';
export 'package:attendance_alamin/app/theme/extensions/severity_colors.dart';
export 'package:attendance_alamin/app/theme/tokens.dart'
    show AttendanceKind, AuroraMetrics, SeverityLevel, kFontFamily;

extension ThemeX on BuildContext {
  AuroraTokens get aurora => Theme.of(this).extension<AuroraTokens>()!;
  AppGradients get gradients => Theme.of(this).extension<AppGradients>()!;
  SeverityColors get severity => Theme.of(this).extension<SeverityColors>()!;
  AttendanceColors get attendance => Theme.of(this).extension<AttendanceColors>()!;

  /// Big-number style (money, %, counts): 40/48 phone, 48/56 desktop width.
  /// Apply to digit / currency runs only (see [buildStatNumber]).
  TextStyle get statNumber => buildStatNumber(
        aurora.textPrimary,
        desktop: MediaQuery.sizeOf(this).width >= AuroraMetrics.desktopBreakpoint,
      );
}
