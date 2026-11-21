// Small Bhor compositions shared by the attendance widgets: the status tag of
// an attendance mark (the save bar and the clash card are the library's
// BhorActionBar / BhorClashCard).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

/// Phosphor glyph of an attendance status (never the Material set).
IconData statusIcon(AttendanceStatus s) => switch (s) {
      AttendanceStatus.present => BhorIcons.present,
      AttendanceStatus.absent => BhorIcons.absent,
      AttendanceStatus.late => BhorIcons.late,
      AttendanceStatus.leave => BhorIcons.leave,
    };

/// Tag tone of an attendance status.
BhorTone attendanceTone(AttendanceStatus s) => switch (s) {
      AttendanceStatus.present => BhorTone.ok,
      AttendanceStatus.absent => BhorTone.absent,
      AttendanceStatus.late => BhorTone.late,
      AttendanceStatus.leave => BhorTone.neutral,
    };

/// A status as a tag: icon + word (never colour alone). [short] uses the
/// one-letter form.
Widget attendanceTag(BuildContext context, AttendanceStatus s, {bool short = false}) {
  final l10n = context.l10n;
  return BhorTag(
    label: short ? s.shortLabel(l10n) : s.label(l10n),
    tone: attendanceTone(s),
    icon: statusIcon(s),
  );
}
