import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A student's marks in one batch, oldest first.
final studentBatchRecordsProvider = StreamProvider.family<
    List<AttendanceRecord>,
    ({String studentId, String batchId})>((ref, key) => ref
    .watch(attendanceRepositoryProvider)
    .watchRecords(studentId: key.studentId, batchId: key.batchId));

/// All enrollments of one student.
final studentEnrollmentsProvider = StreamProvider.family<List<Enrollment>,
        String>(
    (ref, studentId) =>
        ref.watch(enrollmentsRepositoryProvider).watchForStudent(studentId));

/// Attendance of one student in one batch, optionally for one month. Only
/// marks inside the enrollment (join date .. end date) count, so the
/// denominator is bounded by enrollment dates (lead note M2-C).
final attendanceTallyProvider = Provider.family<AsyncValue<AttendanceTally>,
    ({String studentId, String batchId, YearMonth? month})>((ref, key) {
  return combine2(
    ref.watch(studentBatchRecordsProvider(
        (studentId: key.studentId, batchId: key.batchId))),
    ref.watch(studentEnrollmentsProvider(key.studentId)),
    (records, enrollments) {
      final sessions = [
        for (final r in records) (date: r.date, status: r.status),
      ];
      var present = 0, absent = 0, late = 0, leave = 0;
      for (final e in enrollments) {
        if (e.batchId != key.batchId) continue;
        var from = e.joinDate;
        var to = e.endDate;
        final month = key.month;
        if (month != null) {
          if (month.firstDay.isAfter(from)) from = month.firstDay;
          final last = month.lastDay;
          if (to == null || last.isBefore(to)) to = last;
        }
        final t = AttendanceStats.tallyWithin(sessions, from: from, to: to);
        present += t.present;
        absent += t.absent;
        late += t.late;
        leave += t.leave;
      }
      return AttendanceTally(
          present: present, absent: absent, late: late, leave: leave);
    },
  );
});

/// The raw `local_meta` value of `absence_dismissed:<enrollmentId>`: the id of
/// the session whose streak was dismissed (plan M4-C).
final absenceDismissalProvider = StreamProvider.family<String?, String>(
    (ref, enrollmentId) => ref
        .watch(localMetaRepositoryProvider)
        .watchRaw(LocalMetaKeys.absenceDismissed(enrollmentId)));

/// A student absent in the last three held sessions of a batch (F16).
class AbsenceAlert {
  const AbsenceAlert({
    required this.student,
    required this.batch,
    required this.enrollmentId,
    required this.lastSessionId,
  });

  final Student student;
  final Batch batch;
  final String enrollmentId;

  /// Session of the latest absence; dismissing stores it, a newer absence
  /// brings the alert back.
  final String lastSessionId;

  @override
  bool operator ==(Object other) =>
      other is AbsenceAlert &&
      other.student == student &&
      other.batch == batch &&
      other.enrollmentId == enrollmentId &&
      other.lastSessionId == lastSessionId;

  @override
  int get hashCode => Object.hash(student, batch, enrollmentId, lastSessionId);

  @override
  String toString() => 'AbsenceAlert(${student.name}, ${batch.name})';
}

final _alertStudentsProvider = StreamProvider<List<Student>>((ref) => ref
    .watch(studentsRepositoryProvider)
    .watchAll(status: StudentStatus.active));

final _alertBatchesProvider = StreamProvider<List<Batch>>(
    (ref) => ref.watch(batchesRepositoryProvider).watchAll());

final _alertRecordsProvider = StreamProvider<List<AttendanceRecord>>(
    (ref) => ref.watch(attendanceRepositoryProvider).watchRecords());

/// Streak alerts for active students in live batches (open enrollments only),
/// minus the ones already dismissed for their latest absence.
final absenceAlertsProvider =
    Provider<AsyncValue<List<AbsenceAlert>>>((ref) {
  final candidates = combine2(
    combine2(
      ref.watch(_alertStudentsProvider),
      ref.watch(_alertBatchesProvider),
      (List<Student> s, List<Batch> b) => (students: s, batches: b),
    ),
    combine2(
      ref.watch(allEnrollmentsProvider),
      ref.watch(_alertRecordsProvider),
      (List<Enrollment> e, List<AttendanceRecord> r) =>
          (enrollments: e, records: r),
    ),
    (a, b) => _streakCandidates(
      students: a.students,
      batches: a.batches,
      enrollments: b.enrollments,
      records: b.records,
    ),
  );

  final list = candidates.value;
  if (list == null) {
    return candidates.hasError
        ? AsyncValue<List<AbsenceAlert>>.error(
            candidates.error!, candidates.stackTrace ?? StackTrace.empty)
        : AsyncValue<List<AbsenceAlert>>.loading();
  }
  final out = <AbsenceAlert>[];
  for (final alert in list) {
    final dismissal =
        ref.watch(absenceDismissalProvider(alert.enrollmentId));
    if (dismissal.hasError) {
      return AsyncValue<List<AbsenceAlert>>.error(
          dismissal.error!, dismissal.stackTrace ?? StackTrace.empty);
    }
    if (!dismissal.hasValue) return AsyncValue<List<AbsenceAlert>>.loading();
    if (dismissal.value == alert.lastSessionId) continue;
    out.add(alert);
  }
  return AsyncValue<List<AbsenceAlert>>.data(out);
});

List<AbsenceAlert> _streakCandidates({
  required List<Student> students,
  required List<Batch> batches,
  required List<Enrollment> enrollments,
  required List<AttendanceRecord> records,
}) {
  final studentById = {for (final s in students) s.id: s};
  final batchById = {for (final b in batches) b.id: b};
  final recordsByKey = <(String, String), List<AttendanceRecord>>{};
  for (final r in records) {
    (recordsByKey[(r.studentId, r.batchId)] ??= <AttendanceRecord>[]).add(r);
  }

  final out = <AbsenceAlert>[];
  for (final e in enrollments) {
    if (e.endDate != null) continue;
    final student = studentById[e.studentId];
    final batch = batchById[e.batchId];
    if (student == null || batch == null || batch.archived) continue;
    final mine = <AttendanceRecord>[
      for (final r in recordsByKey[(e.studentId, e.batchId)] ??
          const <AttendanceRecord>[])
        if (!r.date.isBefore(e.joinDate)) r,
    ];
    if (mine.isEmpty) continue;
    // Stable by date; the repository already orders ties by start time.
    final indexed = [for (var i = 0; i < mine.length; i++) (i, mine[i])]
      ..sort((a, b) {
        final c = a.$2.date.compareTo(b.$2.date);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    final ordered = [for (final p in indexed) p.$2];
    if (!AttendanceStats.absenceStreak(
        [for (final r in ordered) r.status])) {
      continue;
    }
    final lastAbsent = ordered
        .lastWhere((r) => r.status == AttendanceStatus.absent);
    out.add(AbsenceAlert(
      student: student,
      batch: batch,
      enrollmentId: e.id,
      lastSessionId: lastAbsent.sessionId,
    ));
  }
  out.sort((a, b) => a.student.name.compareTo(b.student.name));
  return out;
}
