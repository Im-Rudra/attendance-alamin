// Bhor tags of the dues feature: the severity tag of a due level (icon + word
// + day / month count) and the state tag of one month of a student's ledger.
// Replace the Aurora SeverityBadge / MonthStateChip.

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

/// Calm tone of a due level: only the overdue tag is red; the middle levels
/// are amber, "just due" is the accent tint, upcoming is neutral.
BhorTone dueLevelTone(DueLevel level) => switch (level) {
      DueLevel.upcoming => BhorTone.neutral,
      DueLevel.justDue => BhorTone.accent,
      DueLevel.remind || DueLevel.followUp || DueLevel.urgent || DueLevel.finalDays => BhorTone.warn,
      DueLevel.overdue => BhorTone.overdue,
    };

IconData dueLevelIcon(DueLevel level) => switch (level) {
      DueLevel.upcoming => BhorIcons.clock,
      DueLevel.justDue || DueLevel.remind => BhorIcons.bell,
      DueLevel.followUp || DueLevel.urgent => BhorIcons.warning,
      DueLevel.finalDays => BhorIcons.clock,
      DueLevel.overdue => BhorIcons.warningFill,
    };

/// Pill tag of [level] (see [dueLevelTone]).
Widget dueLevelTag(
  BuildContext context,
  DueLevel level, {
  int? dayInDue,
  int monthCount = 1,
  int? partialRemaining,
  bool compact = false,
}) {
  return BhorTag(
    tone: dueLevelTone(level),
    icon: dueLevelIcon(level),
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
        icon: advance ? BhorIcons.addCircle : BhorIcons.checkCircleFill,
      );
    case MonthState.waived:
      return BhorTag(label: l10n.uiStateWaived, icon: BhorIcons.minus);
    case MonthState.free:
      return BhorTag(label: l10n.uiStateFree, icon: BhorIcons.minus);
    case MonthState.partial:
    case MonthState.unpaid:
      final DueLevel? level = due.level;
      final String partial = l10n.uiPartialLeft(fmt.money(due.remaining));
      if (level == null || level == DueLevel.upcoming) {
        return BhorTag(
          label: due.state == MonthState.partial ? partial : l10n.uiLevelUpcoming,
          icon: BhorIcons.clock,
        );
      }
      return BhorTag(
        tone: due.state == MonthState.partial ? BhorTone.warn : dueLevelTone(level),
        icon: dueLevelIcon(level),
        label: due.state == MonthState.partial ? partial : level.label(l10n),
      );
  }
}
