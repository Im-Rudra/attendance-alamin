import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/db_queries.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/drift/people_common.dart';
import 'package:attendance_alamin/data/repositories/enrollments_repository.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:drift/drift.dart' hide Batch;

class DriftEnrollmentsRepository implements EnrollmentsRepository {
  DriftEnrollmentsRepository(this._db, this._stamper,
      {CenterTime center = CenterTime.dhaka})
      : _center = center;

  final AppDatabase _db;
  final SyncStamper _stamper;
  final CenterTime _center;

  Stream<List<Enrollment>> _watch(
      Expression<bool> Function($EnrollmentsTable t)? filter) {
    final q = _db.select(_db.enrollments)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.joinDate),
        (t) => OrderingTerm.asc(t.id),
      ]);
    if (filter != null) q.where(filter);
    return q.watch().map((rows) => rows.map(enrollmentFromRow).toList());
  }

  @override
  Stream<List<Enrollment>> watchAll() => _watch(null);

  @override
  Stream<List<Enrollment>> watchForStudent(String studentId) =>
      _watch((t) => t.studentId.equals(studentId));

  @override
  Stream<List<Enrollment>> watchForBatch(String batchId) =>
      _watch((t) => t.batchId.equals(batchId));

  @override
  Stream<List<EnrollmentTerms>> watchTerms() => _db.watchComposite(
      enrollmentTermsTables(_db), () => loadEnrollmentTerms(_db, _center));

  @override
  Future<String> enroll({
    required String studentId,
    required String batchId,
    required LocalDate joinDate,
    required YearMonth startMonth,
    int? feeOverride,
  }) async {
    if (feeOverride != null) checkAmount(feeOverride, field: 'feeOverride');
    return _db.transaction(() async {
      await requireStudent(_db, studentId);
      final batch = await requireBatch(_db, batchId);
      if (batch.archivedAt != null) {
        throw const ValidationException(ErrorCodes.batchArchived,
            field: 'batchId');
      }
      final open = await (_db.select(_db.enrollments)
            ..where((t) =>
                t.studentId.equals(studentId) &
                t.batchId.equals(batchId) &
                t.deletedAt.isNull() &
                t.endDate.isNull()))
          .get();
      if (open.isNotEmpty) {
        throw const ValidationException(ErrorCodes.duplicateOpenEnrollment,
            field: 'batchId');
      }
      final id = Ids.v4();
      final now = _stamper.nowMs();
      await _db.into(_db.enrollments).insert(enrollmentToCompanion(Enrollment(
            id: id,
            studentId: studentId,
            batchId: batchId,
            joinDate: joinDate,
            startMonth: startMonth,
          )).copyWith(
            createdAt: Value(now),
            updatedAt: Value(now),
            deviceId: Value(_stamper.deviceId),
          ));
      if (feeOverride != null) {
        await _upsertOverride(id, startMonth, feeOverride);
      }
      return id;
    });
  }

  /// Live (or revived) override row `Ids.enrollmentFee(enrollmentId, from)`.
  Future<void> _upsertOverride(
      String enrollmentId, YearMonth from, int? amount) async {
    final id = Ids.enrollmentFee(enrollmentId, from);
    final existing = await (_db.select(_db.enrollmentFees)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final companion = enrollmentFeeToCompanion(
        enrollmentId, FeePeriod(effective: from, amount: amount));
    if (existing == null) {
      final now = _stamper.nowMs();
      await _db.into(_db.enrollmentFees).insert(companion.copyWith(
            createdAt: Value(now),
            updatedAt: Value(now),
            deviceId: Value(_stamper.deviceId),
          ));
      return;
    }
    if (existing.deletedAt == null && existing.amount == amount) return;
    await (_db.update(_db.enrollmentFees)..where((t) => t.id.equals(id)))
        .write(companion.copyWith(
      deletedAt: const Value(null),
      updatedAt: Value(_stamper.nextUpdatedAt(existing.updatedAt)),
      rev: Value(_stamper.nextRev(existing.rev)),
      deviceId: Value(_stamper.deviceId),
    ));
  }

  Future<List<EnrollmentFeeRow>> _liveOverrides(String enrollmentId) =>
      (_db.select(_db.enrollmentFees)
            ..where((t) =>
                t.enrollmentId.equals(enrollmentId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.effectiveMonth)]))
          .get();

  @override
  Future<void> setStartMonth(String enrollmentId, YearMonth m) {
    return _db.transaction(() async {
      final e = await requireEnrollment(_db, enrollmentId);
      final oldStart = YearMonth.fromInt(e.startMonth);
      if (oldStart == m) return;
      await (_db.update(_db.enrollments)
            ..where((t) => t.id.equals(enrollmentId)))
          .write(EnrollmentsCompanion(
        startMonth: Value(m.toInt()),
        updatedAt: Value(_stamper.nextUpdatedAt(e.updatedAt)),
        rev: Value(_stamper.nextRev(e.rev)),
        deviceId: Value(_stamper.deviceId),
      ));
      // The override given at enrollment starts at the FBM; keep it covering
      // the first billable month when the FBM moves earlier.
      if (!m.isBefore(oldStart)) return;
      final overrides = await _liveOverrides(enrollmentId);
      if (overrides.isEmpty) return;
      final first = overrides.first;
      if (first.effectiveMonth != oldStart.toInt()) return;
      await tombstoneId(_db, _stamper, _db.enrollmentFees, first.id);
      await _upsertOverride(enrollmentId, m, first.amount);
    });
  }

  @override
  Future<void> setOverride(String enrollmentId, int? amount,
      {required YearMonth from}) async {
    if (amount != null) checkAmount(amount, field: 'feeOverride');
    return _db.transaction(() async {
      await requireEnrollment(_db, enrollmentId);
      await _upsertOverride(enrollmentId, from, amount);
    });
  }

  @override
  Stream<List<FeePeriod>> watchOverrides(String enrollmentId) {
    final q = _db.select(_db.enrollmentFees)
      ..where((t) => t.enrollmentId.equals(enrollmentId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.effectiveMonth)]);
    return q.watch().map((rows) => rows.map(overrideFromRow).toList());
  }

  @override
  Future<void> end(String enrollmentId,
      {required LocalDate on, required YearMonth lastBillableMonth}) {
    return _db.transaction(() async {
      final e = await requireEnrollment(_db, enrollmentId);
      await (_db.update(_db.enrollments)
            ..where((t) => t.id.equals(enrollmentId)))
          .write(EnrollmentsCompanion(
        endDate: Value(on.toIso()),
        endMonth: Value(lastBillableMonth.toInt()),
        updatedAt: Value(_stamper.nextUpdatedAt(e.updatedAt)),
        rev: Value(_stamper.nextRev(e.rev)),
        deviceId: Value(_stamper.deviceId),
      ));
    });
  }

  @override
  Future<List<Student>> rosterOn(String batchId, LocalDate date) async {
    final enrollments = await (_db.select(_db.enrollments)
          ..where((t) => t.batchId.equals(batchId) & t.deletedAt.isNull()))
        .get();
    final ids = <String>{
      for (final r in enrollments)
        if (enrollmentFromRow(r).coversDate(date)) r.studentId,
    };
    if (ids.isEmpty) return const [];
    final rows = await (_db.select(_db.students)
          ..where((t) => t.id.isIn(ids) & t.deletedAt.isNull()))
        .get();
    final students = <Student>[];
    for (final r in rows) {
      final s = studentFromRow(r);
      final left = s.leftDate;
      final activeOnDate = s.status == StudentStatus.active ||
          (left != null && !date.isAfter(left));
      if (activeOnDate) students.add(s);
    }
    return students..sort(compareByRollThenName);
  }
}
