import 'dart:typed_data';

import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:drift/drift.dart' hide Batch;
import 'package:flutter_test/flutter_test.dart';

import 'db_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openMemoryDb();
    await seedBasics(db);
  });

  test('subject round-trips; archived follows archived_at', () async {
    final row = await db.select(db.subjects).getSingle();
    expect(subjectFromRow(row), subjectA);
    expect(row.createdAt, t0);
    expect(row.rev, 1);
    expect(row.deviceId, dev);
    await (db.update(db.subjects)..where((t) => t.id.equals(subjectA.id)))
        .write(const SubjectsCompanion(archivedAt: Value(t0)));
    final archived = await db.select(db.subjects).getSingle();
    expect(subjectFromRow(archived).archived, isTrue);
  });

  test('batch round-trips; createdOn / archivedOn are center dates', () async {
    expect(batchFromRow(await db.select(db.batches).getSingle(), center), batchA);
    // 20:30 UTC on 2026-11-20 is 02:30 on 2026-11-21 in Dhaka.
    const lateUtc = 1795206600000;
    final archived = Batch(
      id: 'bat-2',
      subjectId: 'sub-1',
      name: 'SSC',
      billingType: BillingType.prepaid,
      createdOn: LocalDate.parse('2026-11-21'),
      sortOrder: 0,
      archivedOn: LocalDate.parse('2026-12-31'),
    );
    await db.into(db.batches).insert(
        stamp(batchToCompanion(archived, center).copyWith, at: lateUtc));
    final row = await (db.select(db.batches)..where((t) => t.id.equals('bat-2')))
        .getSingle();
    expect(batchFromRow(row, center), archived);
    expect(row.archivedAt, centerMidnightMs(LocalDate.parse('2026-12-31'), center));
    expect(row.reminderLeadMin, isNull);
  });

  test('slot round-trips', () async {
    expect(slotFromRow(await db.select(db.batchSlots).getSingle()), slotA);
    final bounded = Slot(
      id: 'slot-2',
      batchId: 'bat-1',
      weekday: 1,
      startMin: 0,
      endMin: 1440,
      validFrom: LocalDate.parse('2026-01-01'),
      validTo: LocalDate.parse('2026-06-30'),
    );
    await db.into(db.batchSlots).insert(stamp(slotToCompanion(bounded).copyWith));
    final row = await (db.select(db.batchSlots)..where((t) => t.id.equals('slot-2')))
        .getSingle();
    expect(row.validTo, '2026-06-30');
    expect(slotFromRow(row), bounded);
  });

  test('exceptions of every kind round-trip', () async {
    const occ = 's.slot-1.20261121';
    final all = [
      ScheduleException(
        id: Ids.exceptionForOcc(occ),
        batchId: 'bat-1',
        kind: ExceptionKind.cancel,
        slotId: 'slot-1',
        originalDate: LocalDate.parse('2026-11-21'),
        note: 'Eid',
      ),
      ScheduleException(
        id: Ids.exceptionForOcc('s.slot-1.20261128'),
        batchId: 'bat-1',
        kind: ExceptionKind.reschedule,
        slotId: 'slot-1',
        originalDate: LocalDate.parse('2026-11-28'),
        newDate: LocalDate.parse('2026-11-29'),
        newStartMin: 600,
        newEndMin: 690,
      ),
      ScheduleException(
        id: 'extra-1',
        batchId: 'bat-1',
        kind: ExceptionKind.extra,
        newDate: LocalDate.parse('2026-11-30'),
        newStartMin: 1200,
        newEndMin: 1290,
      ),
    ];
    for (final e in all) {
      await db.into(db.scheduleExceptions).insert(stamp(exceptionToCompanion(e).copyWith));
    }
    final rows = await db.select(db.scheduleExceptions).get();
    expect(rows.map(exceptionFromRow).toSet(), all.toSet());
  });

  test('fee histories round-trip with deterministic ids', () async {
    await db.into(db.batchFees).insert(stamp(batchFeeToCompanion('bat-1', fee(202611, 1500)).copyWith));
    final feeRow = await db.select(db.batchFees).getSingle();
    expect(feeRow.id, Ids.batchFee('bat-1', YearMonth.fromInt(202611)));
    expect(feeFromRow(feeRow), fee(202611, 1500));
    expect(() => batchFeeToCompanion('bat-1', fee(202612, null)), throwsArgumentError);

    await db.into(db.enrollmentFees).insert(stamp(enrollmentFeeToCompanion('enr-1', fee(202611, 0)).copyWith));
    await db.into(db.enrollmentFees).insert(stamp(enrollmentFeeToCompanion('enr-1', fee(202702, null)).copyWith));
    final overrides = await (db.select(db.enrollmentFees)
          ..orderBy([(t) => OrderingTerm.asc(t.effectiveMonth)]))
        .get();
    expect(overrides.first.id, Ids.enrollmentFee('enr-1', YearMonth.fromInt(202611)));
    expect(overrides.map(overrideFromRow).toList(), [fee(202611, 0), fee(202702, null)]);
  });

  test('student and photo round-trip', () async {
    expect(studentFromRow(await db.select(db.students).getSingle()), studentA);
    final left = Student(
      id: 'stu-2',
      name: 'করিম',
      admissionDate: LocalDate.parse('2025-01-10'),
      status: StudentStatus.left,
      leftDate: LocalDate.parse('2026-10-31'),
    );
    await db.into(db.students).insert(stamp(studentToCompanion(left).copyWith));
    final row = await (db.select(db.students)..where((t) => t.id.equals('stu-2'))).getSingle();
    expect(studentFromRow(row), left);
    expect(row.hasPhoto, isFalse);

    final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
    await db.into(db.studentPhotos).insert(StudentPhotosCompanion.insert(
        id: 'stu-1', createdAt: t0, updatedAt: t0, deviceId: dev, jpeg: bytes));
    expect((await db.select(db.studentPhotos).getSingle()).jpeg, bytes);
  });

  test('enrollment round-trips incl. end month / end date', () async {
    expect(enrollmentFromRow(await db.select(db.enrollments).getSingle()), enrollmentA);
    final ended = Enrollment(
      id: 'enr-2',
      studentId: 'stu-1',
      batchId: 'bat-1',
      joinDate: LocalDate.parse('2026-01-05'),
      startMonth: YearMonth.fromInt(202601),
      endMonth: YearMonth.fromInt(202606),
      endDate: LocalDate.parse('2026-06-20'),
    );
    await db.into(db.enrollments).insert(stamp(enrollmentToCompanion(ended).copyWith));
    final row = await (db.select(db.enrollments)..where((t) => t.id.equals('enr-2'))).getSingle();
    expect(row.endMonth, 202606);
    expect(enrollmentFromRow(row), ended);
  });

  test('session and records (all four statuses) round-trip', () async {
    for (final s in AttendanceStatus.values) {
      final occ = 's.slot-1.2026112${s.index}';
      final session = sessionFor(occ);
      await db.into(db.attendanceSessions).insert(stamp(sessionToCompanion(session).copyWith));
      final record = recordFor(occ, s);
      await db.into(db.attendanceRecords).insert(stamp(recordToCompanion(record).copyWith));
      final sRow = await (db.select(db.attendanceSessions)..where((t) => t.occ.equals(occ)))
          .getSingle();
      expect(sessionFromRow(sRow), session);
      final rRow = await (db.select(db.attendanceRecords)
            ..where((t) => t.sessionId.equals(session.id)))
          .getSingle();
      expect(rRow.status, s.code);
      expect(recordFromRow(rRow), record);
    }
  });

  test('payments round-trip incl. custom method and waiver', () async {
    final paid = paymentFor('pay-1', method: PaymentMethod.custom('উপায়'));
    final waived = paymentFor('pay-2', amount: 0, waived: true, method: PaymentMethod.other);
    for (final p in [paid, waived]) {
      await db.into(db.payments).insert(stamp(paymentToCompanion(p).copyWith));
    }
    final rows = await (db.select(db.payments)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    expect(rows.first.method, 'custom:উপায়');
    expect(rows.first.receiptId, 'rcpt-1');
    expect(rows.map(paymentFromRow).toList(), [paid, waived]);
  });

  test('other income round-trips with and without a student', () async {
    final a = incomeFor('oi-1');
    final b = incomeFor('oi-2', studentId: null, method: PaymentMethod.custom('Book'));
    for (final o in [a, b]) {
      await db.into(db.otherIncome).insert(stamp(otherIncomeToCompanion(o).copyWith));
    }
    final rows = await (db.select(db.otherIncome)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    expect(rows.map(otherIncomeFromRow).toList(), [a, b]);
  });

  test('settings, local meta, safety snapshots and import log store rows', () async {
    await db.into(db.syncedSettings).insert(SyncedSettingsCompanion.insert(
        id: 'center_name', createdAt: t0, updatedAt: t0, deviceId: dev, value: '"Al Amin"'));
    expect((await db.select(db.syncedSettings).getSingle()).value, '"Al Amin"');

    await db.into(db.localMeta).insert(LocalMetaCompanion.insert(metaKey: 'locale', metaValue: 'bn'));
    expect((await db.select(db.localMeta).getSingle()).metaValue, 'bn');

    final gz = Uint8List.fromList([0x1F, 0x8B, 8, 0]);
    await db.into(db.safetySnapshots).insert(
        SafetySnapshotsCompanion.insert(id: 'snap-1', createdAt: t0, reason: 'import', bytes: gz));
    expect((await db.select(db.safetySnapshots).getSingle()).bytes, gz);

    await db.into(db.importLog).insert(ImportLogCompanion.insert(
        id: 'log-1',
        importedAt: t0,
        snapshotId: 'snap-in',
        sourceDeviceId: 'other-device',
        summaryJson: '{}'));
    expect((await db.select(db.importLog).getSingle()).sourceDeviceId, 'other-device');
  });

  test('unknown enum codes surface as FormatException, not silent defaults', () async {
    await db.customStatement('PRAGMA ignore_check_constraints = ON');
    await (db.update(db.students)..where((t) => t.id.equals('stu-1')))
        .write(const StudentsCompanion(status: Value('gone')));
    final row = await db.select(db.students).getSingle();
    expect(() => studentFromRow(row), throwsFormatException);
  });
}
