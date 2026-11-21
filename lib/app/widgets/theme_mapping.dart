// Enum bridges between domain enums and the theme-local enums (Lead notes,
// M3-B). Features never repeat the index arithmetic.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:attendance_alamin/app/theme/tokens.dart' show AttendanceKind, SeverityLevel;
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

extension DueLevelTheme on DueLevel {
  /// Theme-local twin (same declaration order, locked by M1-B).
  SeverityLevel get severityLevel => SeverityLevel.values[index];

  IconData get icon {
    switch (this) {
      case DueLevel.upcoming:
        return BhorIcons.clock;
      case DueLevel.justDue:
        return BhorIcons.bell;
      case DueLevel.remind:
        return BhorIcons.remind;
      case DueLevel.followUp:
        return BhorIcons.infoFill;
      case DueLevel.urgent:
        return BhorIcons.warningFill;
      case DueLevel.finalDays:
        return BhorIcons.clock;
      case DueLevel.overdue:
        return BhorIcons.errorFill;
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case DueLevel.upcoming:
        return l10n.uiLevelUpcoming;
      case DueLevel.justDue:
        return l10n.uiLevelJustDue;
      case DueLevel.remind:
        return l10n.uiLevelRemind;
      case DueLevel.followUp:
        return l10n.uiLevelFollowUp;
      case DueLevel.urgent:
        return l10n.uiLevelUrgent;
      case DueLevel.finalDays:
        return l10n.uiLevelFinalDays;
      case DueLevel.overdue:
        return l10n.uiLevelOverdue;
    }
  }
}

extension AttendanceStatusTheme on AttendanceStatus {
  AttendanceKind get kind => AttendanceKind.values[index];

  IconData get icon {
    switch (this) {
      case AttendanceStatus.present:
        return BhorIcons.present;
      case AttendanceStatus.absent:
        return BhorIcons.absent;
      case AttendanceStatus.late:
        return BhorIcons.late;
      case AttendanceStatus.leave:
        return BhorIcons.leave;
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case AttendanceStatus.present:
        return l10n.uiAttPresent;
      case AttendanceStatus.absent:
        return l10n.uiAttAbsent;
      case AttendanceStatus.late:
        return l10n.uiAttLate;
      case AttendanceStatus.leave:
        return l10n.uiAttExcused;
    }
  }

  String shortLabel(AppLocalizations l10n) {
    switch (this) {
      case AttendanceStatus.present:
        return l10n.uiAttPresentShort;
      case AttendanceStatus.absent:
        return l10n.uiAttAbsentShort;
      case AttendanceStatus.late:
        return l10n.uiAttLateShort;
      case AttendanceStatus.leave:
        return l10n.uiAttExcusedShort;
    }
  }
}
