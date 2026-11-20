// Class reminder texts (Product 3.11; plan section 1 #3). The planner's
// `PlannedReminder` carries no text (lead notes, M2-C): the title and body are
// built here from kind / start / end / lead, in the app language at scheduling
// time (recomputed when the language changes).
//
//   title  "{subject} · {batch}"
//   bn     "{start}–{end} ক্লাস — {N} মিনিট পর" + " (অতিরিক্ত ক্লাস)" / " (সময় বদলানো)"
//   en     "Class {start}–{end} — in {N} min" + " (extra class)" / " (rescheduled)"

import 'dart:ui' show Locale;

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/data/notifications/notification_providers.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class ReminderTexts {
  ReminderTexts(this.lang)
      : l10n = lookupAppLocalizations(Locale(lang.code)),
        fmt = AppFormat(lang);

  final Lang lang;
  final AppLocalizations l10n;
  final AppFormat fmt;

  /// "পদার্থবিজ্ঞান · ব্যাচ A"; just the batch when the subject has no name
  /// (a deleted subject reads as '').
  String title({required String subject, required String batch}) {
    final String s = subject.trim();
    return s.isEmpty ? batch : l10n.remindTitle(s, batch);
  }

  /// "বিকাল ৪:০০–৫:০০ ক্লাস — ১৫ মিনিট পর" (+ extra / rescheduled suffix).
  String body({
    required OccurrenceKind kind,
    required int startMin,
    required int endMin,
    required int leadMin,
  }) {
    final String range = fmt.timeRange(startMin, endMin);
    final String n = fmt.number(leadMin);
    return switch (kind) {
      OccurrenceKind.regular => l10n.remindBody(range, n),
      OccurrenceKind.extra => l10n.remindBodyExtra(range, n),
      OccurrenceKind.rescheduled => l10n.remindBodyRescheduled(range, n),
    };
  }

  /// The OS-ready notice for [r] of the batch [batch] of subject [subject].
  ScheduledNotice notice(PlannedReminder r, {required String subject, required String batch}) =>
      ScheduledNotice(
        id: r.id,
        fireAtUtc: r.fireAtUtc,
        title: title(subject: subject, batch: batch),
        body: body(kind: r.kind, startMin: r.startMin, endMin: r.endMin, leadMin: r.leadMin),
        payload: r.payload,
        actionLabel: l10n.remindAction,
      );
}
