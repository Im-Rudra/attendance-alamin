// Shared multi-table reads used by several repositories (plan M3-A, 2.6).
// No SQL joins in v1: each table is read once (live rows only) and combined
// in Dart. Wrap these in `db.watchComposite(...)` with the matching
// `*Tables(db)` set for a stream.

import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:drift/drift.dart' hide Batch;

/// Tables read by [loadAllSchedules].
Set<ResultSetImplementation<dynamic, dynamic>> scheduleTables(AppDatabase db) =>
    {db.subjects, db.batches, db.batchSlots, db.scheduleExceptions};

/// Tables read by [loadEnrollmentTerms].
Set<ResultSetImplementation<dynamic, dynamic>> enrollmentTermsTables(
        AppDatabase db) =>
    {
      db.subjects,
      db.batches,
      db.batchFees,
      db.students,
      db.enrollments,
      db.enrollmentFees,
    };

/// Every live (not tombstoned) batch, archived ones included (`batch.archived`),
/// with its live slots and exceptions. Sorted by sort order, then name, then
/// id; slots by weekday, start, id; exceptions by id. `subjectName` is `''`
/// when the subject row is missing or tombstoned.
Future<List<BatchSchedule>> loadAllSchedules(AppDatabase db, CenterTime c) async {
  final subjects = await (db.select(db.subjects)
        ..where((t) => t.deletedAt.isNull()))
      .get();
  final subjectNames = {for (final s in subjects) s.id: s.name};

  final batches = await (db.select(db.batches)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.name),
          (t) => OrderingTerm.asc(t.id),
        ]))
      .get();

  final slotRows = await (db.select(db.batchSlots)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([
          (t) => OrderingTerm.asc(t.weekday),
          (t) => OrderingTerm.asc(t.startMin),
          (t) => OrderingTerm.asc(t.id),
        ]))
      .get();
  final slotsByBatch = <String, List<Slot>>{};
  for (final r in slotRows) {
    (slotsByBatch[r.batchId] ??= []).add(slotFromRow(r));
  }

  final excRows = await (db.select(db.scheduleExceptions)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();
  final excByBatch = <String, List<ScheduleException>>{};
  for (final r in excRows) {
    (excByBatch[r.batchId] ??= []).add(exceptionFromRow(r));
  }

  return [
    for (final b in batches)
      BatchSchedule(
        batch: batchFromRow(b, c),
        subjectName: subjectNames[b.subjectId] ?? '',
        slots: slotsByBatch[b.id] ?? const [],
        exceptions: excByBatch[b.id] ?? const [],
      ),
  ];
}

/// Dues-engine input for every live enrollment whose student and batch are
/// live. Fee histories (live rows) are sorted ascending by month.
/// `enrollmentEnded` = the enrollment has an `end_date`; `studentLeft` =
/// student status `left`; `batchArchived` = batch `archived_at` set.
/// Sorted by student name, batch name, enrollment id.
Future<List<EnrollmentTerms>> loadEnrollmentTerms(
    AppDatabase db, CenterTime c) async {
  final subjects = await (db.select(db.subjects)
        ..where((t) => t.deletedAt.isNull()))
      .get();
  final subjectNames = {for (final s in subjects) s.id: s.name};

  final batches = await (db.select(db.batches)
        ..where((t) => t.deletedAt.isNull()))
      .get();
  final batchById = {for (final b in batches) b.id: b};

  final students = await (db.select(db.students)
        ..where((t) => t.deletedAt.isNull()))
      .get();
  final studentById = {for (final s in students) s.id: s};

  final feeRows = await (db.select(db.batchFees)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.effectiveMonth)]))
      .get();
  final feesByBatch = <String, List<FeePeriod>>{};
  for (final r in feeRows) {
    (feesByBatch[r.batchId] ??= []).add(feeFromRow(r));
  }

  final overrideRows = await (db.select(db.enrollmentFees)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.effectiveMonth)]))
      .get();
  final overridesByEnrollment = <String, List<FeePeriod>>{};
  for (final r in overrideRows) {
    (overridesByEnrollment[r.enrollmentId] ??= []).add(overrideFromRow(r));
  }

  final enrollments = await (db.select(db.enrollments)
        ..where((t) => t.deletedAt.isNull()))
      .get();

  final terms = <EnrollmentTerms>[];
  for (final e in enrollments) {
    final batch = batchById[e.batchId];
    final student = studentById[e.studentId];
    if (batch == null || student == null) continue;
    final en = enrollmentFromRow(e);
    terms.add(EnrollmentTerms(
      enrollmentId: en.id,
      studentId: en.studentId,
      batchId: en.batchId,
      studentName: student.name,
      batchName: batch.name,
      subjectName: subjectNames[batch.subjectId] ?? '',
      billing: BillingType.parse(batch.billingType),
      start: en.startMonth,
      end: en.endMonth,
      batchFees: feesByBatch[batch.id] ?? const [],
      overrides: overridesByEnrollment[en.id] ?? const [],
      batchArchived: batch.archivedAt != null,
      studentLeft: StudentStatus.parse(student.status) == StudentStatus.left,
      enrollmentEnded: en.endDate != null,
    ));
  }
  terms.sort((a, b) {
    final byStudent = a.studentName.compareTo(b.studentName);
    if (byStudent != 0) return byStudent;
    final byBatch = a.batchName.compareTo(b.batchName);
    if (byBatch != 0) return byBatch;
    return a.enrollmentId.compareTo(b.enrollmentId);
  });
  return terms;
}
