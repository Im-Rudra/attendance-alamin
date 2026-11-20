import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/widgets/state_pill.dart';
import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every batch with its slots and exceptions (live, from the repository).
final schedulesProvider = StreamProvider<List<BatchSchedule>>(
    (ref) => ref.watch(scheduleRepositoryProvider).watchAllSchedules());

/// All live enrollments (ended ones included; use [Enrollment.coversDate]).
final allEnrollmentsProvider = StreamProvider<List<Enrollment>>(
    (ref) => ref.watch(enrollmentsRepositoryProvider).watchAll());

/// Inclusive date span, a structural family key.
typedef DateSpan = ({LocalDate from, LocalDate to});

/// Roll-call sessions (with tallies) whose date lies in the span.
final sessionSummariesProvider =
    StreamProvider.family<List<SessionSummary>, DateSpan>((ref, span) => ref
        .watch(attendanceRepositoryProvider)
        .watchSummaries(from: span.from, to: span.to));

/// One class on a day's plan: scheduled, moved-in, extra or cancelled.
class DayClass {
  const DayClass({
    required this.occ,
    required this.batch,
    required this.subjectName,
    required this.startMin,
    required this.endMin,
    this.state,
    this.occurrence,
    this.session,
    this.tally,
    this.enrolledCount = 0,
    this.originalDate,
    this.originalStartMin,
  });

  final String occ;
  final Batch batch;
  final String subjectName;
  final int startMin;
  final int endMin;

  /// `cancelled` > `moved` (rescheduled in) > `extra` > `now` (today only,
  /// start <= now < end); `null` for an ordinary class.
  final ClassState? state;

  /// `null` for a cancelled class (it no longer occurs).
  final Occurrence? occurrence;

  /// The saved roll call of this occurrence, if taken.
  final AttendanceSession? session;
  final AttendanceTally? tally;

  /// Enrollments covering this date (before any roll call).
  final int enrolledCount;

  /// Where a moved-in class came from.
  final LocalDate? originalDate;
  final int? originalStartMin;

  bool get cancelled => state == ClassState.cancelled;
  bool get taken => session != null;

  @override
  bool operator ==(Object other) =>
      other is DayClass &&
      other.occ == occ &&
      other.batch == batch &&
      other.subjectName == subjectName &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.state == state &&
      other.occurrence == occurrence &&
      other.session == session &&
      other.tally == tally &&
      other.enrolledCount == enrolledCount &&
      other.originalDate == originalDate &&
      other.originalStartMin == originalStartMin;

  @override
  int get hashCode => Object.hash(occ, batch, subjectName, startMin, endMin,
      state, occurrence, session, tally, enrolledCount, originalDate,
      originalStartMin);

  @override
  String toString() => 'DayClass($occ, $startMin-$endMin, $state)';
}

/// One day: its classes by start time, and the classes moved away from it.
class DayPlan {
  const DayPlan({
    required this.date,
    required this.classes,
    required this.movedAway,
  });

  final LocalDate date;
  final List<DayClass> classes;
  final List<MovedAway> movedAway;

  @override
  bool operator ==(Object other) =>
      other is DayPlan &&
      other.date == date &&
      _listEq(other.classes, classes) &&
      _listEq(other.movedAway, movedAway);

  @override
  int get hashCode =>
      Object.hash(date, Object.hashAll(classes), Object.hashAll(movedAway));

  @override
  String toString() => 'DayPlan($date, ${classes.length} classes)';
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Pure builder behind [dayPlanProvider] / [weekPlanProvider]: one [DayPlan]
/// per day of [range]. [nowMin] only matters on [today].
List<DayPlan> buildDayPlans({
  required DateRange range,
  required LocalDate today,
  required int nowMin,
  required List<BatchSchedule> schedules,
  required List<SessionSummary> summaries,
  required List<Enrollment> enrollments,
}) {
  final expanded = ScheduleEngine.expand(range: range, batches: schedules);
  final byBatch = <String, BatchSchedule>{
    for (final s in schedules) s.batch.id: s,
  };
  final summaryByOcc = <String, SessionSummary>{
    for (final s in summaries) s.session.occ: s,
  };

  int enrolledOn(String batchId, LocalDate d) {
    var n = 0;
    for (final e in enrollments) {
      if (e.batchId == batchId && e.coversDate(d)) n++;
    }
    return n;
  }

  final classesByDate = <LocalDate, List<DayClass>>{};
  for (final o in expanded.occurrences) {
    final bs = byBatch[o.batchId];
    if (bs == null) continue;
    final summary = summaryByOcc[o.occ];
    ClassState? state;
    if (o.kind == OccurrenceKind.rescheduled) {
      state = ClassState.moved;
    } else if (o.kind == OccurrenceKind.extra) {
      state = ClassState.extra;
    } else if (o.date == today && o.startMin <= nowMin && nowMin < o.endMin) {
      state = ClassState.now;
    }
    (classesByDate[o.date] ??= <DayClass>[]).add(DayClass(
      occ: o.occ,
      batch: bs.batch,
      subjectName: bs.subjectName,
      startMin: o.startMin,
      endMin: o.endMin,
      state: state,
      occurrence: o,
      session: summary?.session,
      tally: summary?.tally,
      enrolledCount: enrolledOn(o.batchId, o.date),
      originalDate: o.originalDate,
      originalStartMin: o.originalStartMin,
    ));
  }
  for (final c in expanded.cancelled) {
    final bs = byBatch[c.batchId];
    if (bs == null) continue;
    (classesByDate[c.date] ??= <DayClass>[]).add(DayClass(
      occ: c.occ,
      batch: bs.batch,
      subjectName: bs.subjectName,
      startMin: c.startMin,
      endMin: c.endMin,
      state: ClassState.cancelled,
      enrolledCount: enrolledOn(c.batchId, c.date),
    ));
  }

  int compare(DayClass a, DayClass b) {
    var c = a.startMin.compareTo(b.startMin);
    if (c != 0) return c;
    c = a.endMin.compareTo(b.endMin);
    if (c != 0) return c;
    c = a.batch.sortOrder.compareTo(b.batch.sortOrder);
    if (c != 0) return c;
    return a.occ.compareTo(b.occ);
  }

  return [
    for (final d in range.days)
      DayPlan(
        date: d,
        classes: List<DayClass>.unmodifiable(
            (classesByDate[d] ?? const <DayClass>[]).toList()..sort(compare)),
        movedAway: List<MovedAway>.unmodifiable([
          for (final m in expanded.movedAway)
            if (m.originalDate == d) m,
        ]),
      ),
  ];
}

/// The plan of one date (classes, cancelled ones included).
final dayPlanProvider =
    Provider.family<AsyncValue<DayPlan>, LocalDate>((ref, date) {
  final today = ref.watch(todayProvider);
  final nowMin = date == today ? ref.watch(nowMinutesProvider) : -1;
  return combine3(
    ref.watch(schedulesProvider),
    ref.watch(sessionSummariesProvider((from: date, to: date))),
    ref.watch(allEnrollmentsProvider),
    (schedules, summaries, enrollments) => buildDayPlans(
      range: DateRange(date, date),
      today: today,
      nowMin: nowMin,
      schedules: schedules,
      summaries: summaries,
      enrollments: enrollments,
    ).single,
  );
});

/// Seven consecutive plans from the given week start date.
final weekPlanProvider =
    Provider.family<AsyncValue<List<DayPlan>>, LocalDate>((ref, weekStart) {
  final today = ref.watch(todayProvider);
  final nowMin = ref.watch(nowMinutesProvider);
  final end = weekStart.addDays(6);
  return combine3(
    ref.watch(schedulesProvider),
    ref.watch(sessionSummariesProvider((from: weekStart, to: end))),
    ref.watch(allEnrollmentsProvider),
    (schedules, summaries, enrollments) => buildDayPlans(
      range: DateRange(weekStart, end),
      today: today,
      nowMin: nowMin,
      schedules: schedules,
      summaries: summaries,
      enrollments: enrollments,
    ),
  );
});

/// Overlapping classes in the next 28 days (legacy data, import) for the
/// "সময়ের সংঘাত" banner.
final legacyConflictsProvider = Provider<AsyncValue<List<Clash>>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(schedulesProvider).whenData((schedules) {
    final occurrences = ScheduleEngine.expand(
      range: DateRange(today, today.addDays(27)),
      batches: schedules,
    ).occurrences;
    return ScheduleEngine.findClashes(
        candidates: occurrences, existing: occurrences);
  });
});
