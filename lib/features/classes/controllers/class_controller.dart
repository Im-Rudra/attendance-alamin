// Shared logic of the class-action sheets (M6-B): occurrence lookup, the
// sheet results, the guardians' cancel message and the clash-card lines.
// Pure helpers (no widgets) so they can be unit tested.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// The class behind an occurrence id (re-resolved on every schedule change).
final occInfoProvider = FutureProvider.autoDispose.family<OccurrenceInfo?, String>((ref, occ) {
  ref.watch(schedulesProvider);
  return ref.watch(scheduleRepositoryProvider).resolve(occ);
});

/// What the class-actions sheet asks its opener to do after it closed.
sealed class ClassSheetResult {
  const ClassSheetResult();
}

class RescheduleRequested extends ClassSheetResult {
  const RescheduleRequested();
}

class RollCallRequested extends ClassSheetResult {
  const RollCallRequested();
}

/// The class was cancelled (or, for an extra class, removed). [guardianMessage]
/// is null for an extra class (nobody was told about it).
class CancelDone extends ClassSheetResult {
  const CancelDone({required this.occ, required this.removedExtra, this.guardianMessage});

  final String occ;
  final bool removedExtra;
  final String? guardianMessage;
}

/// Monday-based [DateTime]-free helper: first day of the week of [d] when weeks
/// start on ISO weekday [weekStart] (6 = Saturday).
LocalDate weekStartOf(LocalDate d, int weekStart) {
  final int back = (d.isoWeekday - weekStart + 7) % 7;
  return d.addDays(-back);
}

/// The next class of the same batch after [info]'s class (within 4 weeks), or null.
Occurrence? nextClassAfter(Occurrence current, List<BatchSchedule> schedules) {
  final ExpandResult res = ScheduleEngine.expand(
    range: DateRange(current.date, current.date.addDays(28)),
    batches: schedules,
  );
  Occurrence? best;
  for (final Occurrence o in res.occurrences) {
    if (o.batchId != current.batchId || o.occ == current.occ) continue;
    final int byDate = o.date.compareTo(current.date);
    if (byDate < 0 || (byDate == 0 && o.startMin <= current.startMin)) continue;
    if (best == null ||
        o.date.compareTo(best.date) < 0 ||
        (o.date == best.date && o.startMin < best.startMin)) {
      best = o;
    }
  }
  return best;
}

/// The cancel notice shared with guardians (Product 5, via the `cls` ARB).
String buildCancelMessage({
  required AppLocalizations l10n,
  required AppFormat fmt,
  required OccurrenceInfo info,
  required LocalDate today,
  required List<BatchSchedule> schedules,
  required String center,
}) {
  final Occurrence o = info.occurrence!;
  final String dateText = fmt.weekdayDate(o.date);
  final String when = o.date == today ? l10n.clsCancelWhenToday(dateText) : l10n.clsCancelWhenOn(dateText);
  final Occurrence? next = nextClassAfter(o, schedules);
  final String nextText = next == null
      ? ''
      : l10n.clsCancelNext('${fmt.weekdayDate(next.date)} ${fmt.time(next.startMin)}');
  final String base = l10n.clsCancelMessage(
    when,
    info.subjectName,
    info.batch.name,
    fmt.timeRange(o.startMin, o.endMin),
    nextText,
  );
  final String c = center.trim();
  return c.isEmpty ? base : '$base — $c';
}

/// One line of the clash card: "{subject} · {batch} · {date or every …} · {time}".
String clashLine({
  required AppLocalizations l10n,
  required AppFormat fmt,
  required ClashGroup group,
  required Map<String, BatchSchedule> byBatch,
}) {
  final BatchSchedule? bs = byBatch[group.batchId];
  final LocalDate? date = group.date;
  final String when = (group.everyWeek || date == null)
      ? l10n.clsEveryWeekday(fmt.weekdayName(group.weekday))
      : fmt.dateShort(date);
  return l10n.clsClashLine(
    bs?.subjectName ?? '',
    bs?.batch.name ?? '',
    when,
    fmt.timeRange(group.startMin, group.endMin),
  );
}

/// Duration chip text: 45 min, 1 h, 1 h 30 min.
String durationText(AppLocalizations l10n, AppFormat fmt, int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  if (h == 0) return l10n.clsDurationMin(fmt.digits('$m'));
  if (m == 0) return l10n.clsDurationHours(fmt.digits('$h'));
  return l10n.clsDurationHm(fmt.digits('$h'), fmt.digits('$m'));
}
