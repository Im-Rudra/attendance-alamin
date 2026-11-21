// Bhor tags of the dues feature: the severity tag of a due level (icon + word
// + day / month count) and the state tag of one month of a student's ledger.
// Replace the Aurora SeverityBadge / MonthStateChip.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';

/// "জরুরি · ৭ম দিন · ২ মাস" of [level].
String dueLevelLabel(
  BuildContext context,
  DueLevel level, {
  int? dayInDue,
  int monthCount = 1,
  int? partialRemaining,
  bool compact = false,
}) {
  final l10n = context.l10n;
  final fmt = context.fmt;
  final List<String> parts = <String>[level.label(l10n)];
  if (dayInDue != null && level != DueLevel.upcoming) {
    parts.add(l10n.uiDayCount(fmt.number(dayInDue)));
  }
  if (!compact) {
    if (monthCount > 1) parts.add(l10n.uiMonthsDue(fmt.number(monthCount)));
    if (partialRemaining != null) parts.add(l10n.uiPartialLeft(fmt.money(partialRemaining)));
  }
  return parts.join(' · ');
}

/// Severity tag of [level] (honey to rose; overdue is solid).
Widget dueLevelTag(
  BuildContext context,
  DueLevel level, {
  int? dayInDue,
  int monthCount = 1,
  int? partialRemaining,
  bool compact = false,
}) {
  return BhorTag.severity(
    level: level.severityLevel,
    icon: level.icon,
    label: dueLevelLabel(
      context,
      level,
      dayInDue: dayInDue,
      monthCount: monthCount,
      partialRemaining: partialRemaining,
      compact: compact,
    ),
  );
}

/// State tag of one month: paid / advance / waived / free / not due / level.
Widget monthStateTag(BuildContext context, MonthDue due) {
  final l10n = context.l10n;
  final fmt = context.fmt;
  switch (due.state) {
    case MonthState.paid:
      final bool advance = !due.isDue;
      return BhorTag(
        label: advance ? l10n.uiStateAdvance : l10n.uiStatePaid,
        tone: BhorTone.ok,
        icon: advance ? Icons.add_circle : Icons.check_circle,
      );
    case MonthState.waived:
      return BhorTag(label: l10n.uiStateWaived, icon: Icons.do_not_disturb_on);
    case MonthState.free:
      return BhorTag(label: l10n.uiStateFree, icon: Icons.circle_outlined);
    case MonthState.partial:
    case MonthState.unpaid:
      final DueLevel? level = due.level;
      final String partial = l10n.uiPartialLeft(fmt.money(due.remaining));
      if (level == null || level == DueLevel.upcoming) {
        return BhorTag(
          label: due.state == MonthState.partial ? partial : l10n.uiLevelUpcoming,
          icon: Icons.schedule,
        );
      }
      return BhorTag.severity(
        level: level.severityLevel,
        icon: level.icon,
        label: due.state == MonthState.partial ? partial : level.label(l10n),
      );
  }
}
