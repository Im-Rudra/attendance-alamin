// Plain data and providers shared by the roll call screens: the class being
// taken (a real occurrence or a new ad-hoc one), the session choices of a day,
// and the lookups that turn an occurrence id into a batch + date.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

/// Fallback class time of an ad-hoc roll call when the batch has no slots.
const int kDefaultAdHocStartMin = 960;
const int kDefaultAdHocEndMin = 1020;

/// What a roll call is about: an existing occurrence, or (when
/// [occurrence] is null) a new extra class that the first save creates.
class RollTarget {
  const RollTarget({
    required this.batch,
    required this.subjectName,
    required this.date,
    required this.startMin,
    required this.endMin,
    this.occurrence,
    this.cancelled = false,
  });

  final Batch batch;
  final String subjectName;
  final LocalDate date;
  final int startMin;
  final int endMin;
  final Occurrence? occurrence;

  /// The occurrence was cancelled; saving removes the cancellation.
  final bool cancelled;

  bool get adHoc => occurrence == null;

  /// Key of the unsaved draft (`rollcall_draft:<this>`).
  String get draftOcc => occurrence?.occ ?? 'adhoc.${batch.id}.${date.toCompact()}';

  RollTarget copyWith({int? startMin, int? endMin, Occurrence? occurrence, bool? cancelled}) =>
      RollTarget(
        batch: batch,
        subjectName: subjectName,
        date: date,
        startMin: startMin ?? this.startMin,
        endMin: endMin ?? this.endMin,
        occurrence: occurrence ?? this.occurrence,
        cancelled: cancelled ?? this.cancelled,
      );
}

/// One class of a batch on a day, as offered by the chooser and the chips.
class SessionChoice {
  const SessionChoice({
    required this.occ,
    required this.startMin,
    required this.endMin,
    this.taken = false,
    this.cancelled = false,
    this.tally,
  });

  final String occ;
  final int startMin;
  final int endMin;
  final bool taken;
  final bool cancelled;
  final AttendanceTally? tally;
}

/// The first class that has no roll call yet (cancelled ones last), else the first.
SessionChoice? defaultChoice(List<SessionChoice> choices) {
  if (choices.isEmpty) return null;
  for (final SessionChoice c in choices) {
    if (!c.taken && !c.cancelled) return c;
  }
  for (final SessionChoice c in choices) {
    if (!c.taken) return c;
  }
  return choices.first;
}

/// The most common (start, end) among the batch's live slots; the earliest on a
/// tie. Falls back to 16:00-17:00.
({int start, int end}) commonSlotTimes(List<Slot> slots) {
  final Map<(int, int), int> count = <(int, int), int>{};
  for (final Slot s in slots) {
    if (s.validTo != null) continue;
    final (int, int) key = (s.startMin, s.endMin);
    count[key] = (count[key] ?? 0) + 1;
  }
  if (count.isEmpty) {
    for (final Slot s in slots) {
      final (int, int) key = (s.startMin, s.endMin);
      count[key] = (count[key] ?? 0) + 1;
    }
  }
  if (count.isEmpty) return (start: kDefaultAdHocStartMin, end: kDefaultAdHocEndMin);
  (int, int)? best;
  var bestCount = 0;
  for (final MapEntry<(int, int), int> e in count.entries) {
    if (e.value > bestCount || (e.value == bestCount && best != null && e.key.$1 < best.$1)) {
      best = e.key;
      bestCount = e.value;
    }
  }
  return (start: best!.$1, end: best.$2);
}

/// The classes of [batchId] on one day (cancelled ones included) plus saved
/// sessions the schedule no longer shows (e.g. of an archived batch).
List<SessionChoice> choicesFor({
  required String batchId,
  required DayPlan plan,
  required List<SessionSummary> summaries,
}) {
  final List<SessionChoice> out = <SessionChoice>[
    for (final DayClass c in plan.classes)
      if (c.batch.id == batchId)
        SessionChoice(
          occ: c.occ,
          startMin: c.startMin,
          endMin: c.endMin,
          taken: c.taken,
          cancelled: c.cancelled,
          tally: c.tally,
        ),
  ];
  for (final SessionSummary s in summaries) {
    if (s.session.batchId != batchId) continue;
    if (out.any((SessionChoice c) => c.occ == s.session.occ)) continue;
    out.add(SessionChoice(
      occ: s.session.occ,
      startMin: s.session.startMin,
      endMin: s.session.endMin,
      taken: true,
      tally: s.tally,
    ));
  }
  out.sort((SessionChoice a, SessionChoice b) {
    final int c = a.startMin.compareTo(b.startMin);
    return c != 0 ? c : a.occ.compareTo(b.occ);
  });
  return out;
}

/// Batch and date of an occurrence id (the route `/rollcall/:occ` has only the id).
class RollLocation {
  const RollLocation({required this.batchId, required this.date});

  final String batchId;
  final LocalDate date;
}

final rollLocationProvider =
    FutureProvider.autoDispose.family<RollLocation?, String>((Ref ref, String occ) async {
  final OccurrenceInfo? info = await ref.read(scheduleRepositoryProvider).resolve(occ);
  final Occurrence? o = info?.occurrence;
  if (o != null) return RollLocation(batchId: o.batchId, date: o.date);
  final (AttendanceSession, List<AttendanceRecord>)? saved =
      await ref.read(attendanceRepositoryProvider).getSession(occ);
  if (saved != null) {
    return RollLocation(batchId: saved.$1.batchId, date: saved.$1.date);
  }
  return null;
});

/// A batch (null when it no longer exists), live.
final rollBatchProvider = StreamProvider.autoDispose.family<Batch?, String>(
    (Ref ref, String id) => ref.watch(batchesRepositoryProvider).watchById(id));
