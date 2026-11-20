import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/db_queries.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:drift/drift.dart' hide Batch, isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'db_fixtures.dart';

/// Polls until [cond] holds (drift stream updates are asynchronous).
Future<void> eventually(bool Function() cond, {String reason = ''}) async {
  for (var i = 0; i < 100; i++) {
    if (cond()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('condition not met: $reason');
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openMemoryDb();
    await seedBasics(db);
  });

  /// Soft-deletes row [id] of [table] (stream listeners are notified).
  Future<void> tombstone(TableInfo<Table, dynamic> table, String id) async {
    final count = await db.customUpdate(
      'UPDATE ${table.actualTableName} SET deleted_at = ?, rev = rev + 1 WHERE id = ?',
      variables: [Variable.withInt(t0 + 1000), Variable.withString(id)],
      updates: {table},
    );
    expect(count, 1, reason: 'tombstone $id');
  }

  group('watchComposite', () {
    test('emits once on listen and again after a write to each watched table',
        () async {
      var loads = 0;
      final stream = db.watchComposite(scheduleTables(db), () async => ++loads);
      final seen = <int>[];
      final sub = stream.listen(seen.add);
      addTearDown(sub.cancel);
      await eventually(() => seen.isNotEmpty, reason: 'initial emission');

      Future<void> expectEmitAfter(String what, Future<void> Function() write) async {
        final before = seen.length;
        await write();
        await eventually(() => seen.length > before, reason: what);
      }

      await expectEmitAfter('subjects', () async {
        await db.into(db.subjects).insert(stamp(subjectToCompanion(
                const Subject(id: 'sub-2', name: 'Math', sortOrder: 0))
            .copyWith));
      });
      await expectEmitAfter('batches', () async {
        await (db.update(db.batches)..where((t) => t.id.equals('bat-1')))
            .write(const BatchesCompanion(name: Value('HSC 1 (A)')));
      });
      await expectEmitAfter('batch_slots', () async {
        await (db.update(db.batchSlots)..where((t) => t.id.equals('slot-1')))
            .write(const BatchSlotsCompanion(startMin: Value(900)));
      });
      await expectEmitAfter('schedule_exceptions', () async {
        await db.into(db.scheduleExceptions).insert(stamp(exceptionToCompanion(
                ScheduleException(
                    id: 'x1',
                    batchId: 'bat-1',
                    kind: ExceptionKind.extra,
                    newDate: LocalDate.parse('2026-11-30'),
                    newStartMin: 600,
                    newEndMin: 660))
            .copyWith));
      });
      expect(seen.last, loads);
    });

    test('does not re-run for unrelated tables', () async {
      final seen = <int>[];
      var loads = 0;
      final sub = db
          .watchComposite({db.subjects}, () async => ++loads).listen(seen.add);
      addTearDown(sub.cancel);
      await eventually(() => seen.isNotEmpty);
      await db.into(db.localMeta)
          .insert(LocalMetaCompanion.insert(metaKey: 'k', metaValue: 'v'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(seen, [1]);
    });
  });

  group('loadAllSchedules', () {
    test('live batches with their live slots and exceptions', () async {
      final archived = Batch(
        id: 'bat-arch',
        subjectId: 'sub-1',
        name: 'Old',
        billingType: BillingType.prepaid,
        createdOn: center.dateOfEpochMs(t0),
        sortOrder: 5,
        archivedOn: LocalDate.parse('2026-10-31'),
      );
      final gone = Batch(
        id: 'bat-gone',
        subjectId: 'sub-1',
        name: 'Deleted',
        billingType: BillingType.prepaid,
        createdOn: center.dateOfEpochMs(t0),
        sortOrder: 0,
      );
      await db.into(db.batches).insert(stamp(batchToCompanion(archived, center).copyWith));
      await db.into(db.batches).insert(stamp(batchToCompanion(gone, center).copyWith));
      await tombstone(db.batches, 'bat-gone');

      final oldSlot = Slot(
          id: 'slot-old', batchId: 'bat-1', weekday: 2, startMin: 600, endMin: 660);
      await db.into(db.batchSlots).insert(stamp(slotToCompanion(oldSlot).copyWith));
      await tombstone(db.batchSlots, 'slot-old');

      final cancel = ScheduleException(
        id: 'exc-1',
        batchId: 'bat-1',
        kind: ExceptionKind.cancel,
        slotId: 'slot-1',
        originalDate: LocalDate.parse('2026-11-21'),
      );
      final undone = ScheduleException(
        id: 'exc-2',
        batchId: 'bat-1',
        kind: ExceptionKind.cancel,
        slotId: 'slot-1',
        originalDate: LocalDate.parse('2026-11-28'),
      );
      for (final e in [cancel, undone]) {
        await db.into(db.scheduleExceptions).insert(stamp(exceptionToCompanion(e).copyWith));
      }
      await tombstone(db.scheduleExceptions, 'exc-2');

      final schedules = await loadAllSchedules(db, center);
      expect(schedules.map((s) => s.batch.id).toList(), ['bat-1', 'bat-arch']);
      final main = schedules.first;
      expect(main.batch, batchA);
      expect(main.subjectName, 'Physics');
      expect(main.slots, [slotA]);
      expect(main.exceptions, [cancel]);
      expect(schedules.last.batch.archived, isTrue);
      expect(schedules.last.slots, isEmpty);
    });

    test('subject name is empty when the subject is tombstoned', () async {
      await tombstone(db.subjects, 'sub-1');
      final schedules = await loadAllSchedules(db, center);
      expect(schedules.single.subjectName, '');
    });
  });

  group('loadEnrollmentTerms', () {
    test('builds dues inputs from live rows only', () async {
      await db.into(db.batchFees).insert(stamp(batchFeeToCompanion('bat-1', fee(202701, 1800)).copyWith));
      await db.into(db.batchFees).insert(stamp(batchFeeToCompanion('bat-1', fee(202611, 1500)).copyWith));
      await db.into(db.batchFees).insert(stamp(batchFeeToCompanion('bat-1', fee(202612, 1600)).copyWith));
      await tombstone(db.batchFees, batchFeeToCompanion('bat-1', fee(202612, 1)).id.value);
      await db.into(db.enrollmentFees).insert(stamp(enrollmentFeeToCompanion('enr-1', fee(202702, null)).copyWith));
      await db.into(db.enrollmentFees).insert(stamp(enrollmentFeeToCompanion('enr-1', fee(202611, 1000)).copyWith));

      final terms = await loadEnrollmentTerms(db, center);
      final t = terms.single;
      expect(t.enrollmentId, 'enr-1');
      expect(t.studentId, 'stu-1');
      expect(t.batchId, 'bat-1');
      expect(t.studentName, 'Rahim');
      expect(t.batchName, 'HSC 1');
      expect(t.subjectName, 'Physics');
      expect(t.billing, BillingType.postpaid);
      expect(t.start, YearMonth.fromInt(202611));
      expect(t.end, isNull);
      expect(t.batchFees, [fee(202611, 1500), fee(202701, 1800)]);
      expect(t.overrides, [fee(202611, 1000), fee(202702, null)]);
      expect(t.batchArchived, isFalse);
      expect(t.studentLeft, isFalse);
      expect(t.enrollmentEnded, isFalse);
    });

    test('flags and exclusions', () async {
      final left = Student(
        id: 'stu-2',
        name: 'Anika',
        admissionDate: LocalDate.parse('2026-01-01'),
        status: StudentStatus.left,
      );
      await db.into(db.students).insert(stamp(studentToCompanion(left).copyWith));
      final ended = Enrollment(
        id: 'enr-2',
        studentId: 'stu-2',
        batchId: 'bat-1',
        joinDate: LocalDate.parse('2026-01-01'),
        startMonth: YearMonth.fromInt(202601),
        endMonth: YearMonth.fromInt(202610),
        endDate: LocalDate.parse('2026-10-15'),
      );
      final dropped = Enrollment(
        id: 'enr-3',
        studentId: 'stu-1',
        batchId: 'bat-1',
        joinDate: LocalDate.parse('2026-01-01'),
        startMonth: YearMonth.fromInt(202601),
      );
      for (final e in [ended, dropped]) {
        await db.into(db.enrollments).insert(stamp(enrollmentToCompanion(e).copyWith));
      }
      await tombstone(db.enrollments, 'enr-3');
      await (db.update(db.batches)..where((t) => t.id.equals('bat-1')))
          .write(const BatchesCompanion(archivedAt: Value(t0)));

      final terms = await loadEnrollmentTerms(db, center);
      expect(terms.map((t) => t.enrollmentId).toList(), ['enr-2', 'enr-1']);
      final anika = terms.first;
      expect(anika.studentLeft, isTrue);
      expect(anika.enrollmentEnded, isTrue);
      expect(anika.end, YearMonth.fromInt(202610));
      expect(terms.every((t) => t.batchArchived), isTrue);

      await tombstone(db.students, 'stu-2');
      expect((await loadEnrollmentTerms(db, center)).map((t) => t.enrollmentId),
          ['enr-1']);
    });

    test('enrollmentTermsTables triggers a reload on fee changes', () async {
      final seen = <int>[];
      final sub = db
          .watchComposite(enrollmentTermsTables(db),
              () async => (await loadEnrollmentTerms(db, center)).single.batchFees.length)
          .listen(seen.add);
      addTearDown(sub.cancel);
      await eventually(() => seen.isNotEmpty);
      expect(seen.last, 0);
      await db.into(db.batchFees).insert(stamp(batchFeeToCompanion('bat-1', fee(202611, 1500)).copyWith));
      await eventually(() => seen.last == 1, reason: 'fee insert');
    });
  });

  test('tombstoned rows are filtered by deletedAt.isNull()', () async {
    await tombstone(db.students, 'stu-1');
    final live = await (db.select(db.students)..where((t) => t.deletedAt.isNull())).get();
    expect(live, isEmpty);
    // The tombstone itself is kept (rows are never hard-deleted).
    expect(await db.select(db.students).get(), hasLength(1));
  });
}
