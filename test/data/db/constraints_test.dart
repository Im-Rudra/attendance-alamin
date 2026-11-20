import 'dart:typed_data';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:drift/drift.dart' hide Batch, isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'db_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = openMemoryDb();
    await seedBasics(db);
  });

  group('batches', () {
    BatchesCompanion b(String id) =>
        stamp(batchToCompanion(batchA, center).copyWith).copyWith(id: Value(id));

    test('billing_type must be prepaid or postpaid', () async {
      await expectLater(
          db.into(db.batches).insert(b('b2').copyWith(billingType: const Value('monthly'))),
          checkFails);
      await db.into(db.batches).insert(b('b3').copyWith(billingType: const Value('prepaid')));
    });

    test('reminder_lead_min is NULL or 0..720', () async {
      for (final bad in [-1, 721]) {
        await expectLater(
            db.into(db.batches).insert(b('bad$bad').copyWith(reminderLeadMin: Value(bad))),
            checkFails);
      }
      for (final ok in [null, 0, 720]) {
        await db.into(db.batches).insert(b('ok$ok').copyWith(reminderLeadMin: Value(ok)));
      }
    });

    test('subject must exist', () async {
      await expectLater(
          db.into(db.batches).insert(b('b4').copyWith(subjectId: const Value('nope'))),
          fkFails);
    });
  });

  group('batch_slots', () {
    BatchSlotsCompanion s(String id, {int weekday = 1, int start = 600, int end = 660}) =>
        stamp(slotToCompanion(slotA).copyWith).copyWith(
            id: Value(id), weekday: Value(weekday), startMin: Value(start), endMin: Value(end));

    test('weekday 1..7', () async {
      await expectLater(db.into(db.batchSlots).insert(s('w0', weekday: 0)), checkFails);
      await expectLater(db.into(db.batchSlots).insert(s('w8', weekday: 8)), checkFails);
      await db.into(db.batchSlots).insert(s('w7', weekday: 7));
    });

    test('0 <= start < end <= 1440', () async {
      await expectLater(db.into(db.batchSlots).insert(s('a', start: -1)), checkFails);
      await expectLater(db.into(db.batchSlots).insert(s('b', start: 700, end: 700)), checkFails);
      await expectLater(db.into(db.batchSlots).insert(s('c', start: 700, end: 600)), checkFails);
      await expectLater(db.into(db.batchSlots).insert(s('d', start: 1400, end: 1441)), checkFails);
      await db.into(db.batchSlots).insert(s('e', start: 0, end: 1440));
    });

    test('several slots per batch and weekday are allowed', () async {
      await db.into(db.batchSlots).insert(s('m', weekday: 6, start: 480, end: 540));
      await db.into(db.batchSlots).insert(s('n', weekday: 6, start: 1200, end: 1260));
    });

    test('batch must exist', () async {
      await expectLater(
          db.into(db.batchSlots).insert(s('x').copyWith(batchId: const Value('nope'))), fkFails);
    });
  });

  group('schedule_exceptions', () {
    Future<void> put(ScheduleException e) =>
        db.into(db.scheduleExceptions).insert(stamp(exceptionToCompanion(e).copyWith));

    ScheduleException exc(String id, ExceptionKind kind,
            {String? slotId, String? original, String? newDate, int? start, int? end}) =>
        ScheduleException(
          id: id,
          batchId: 'bat-1',
          kind: kind,
          slotId: slotId,
          originalDate: original == null ? null : LocalDate.parse(original),
          newDate: newDate == null ? null : LocalDate.parse(newDate),
          newStartMin: start,
          newEndMin: end,
        );

    test('valid cancel, reschedule and extra are accepted', () async {
      await put(exc('c', ExceptionKind.cancel, slotId: 'slot-1', original: '2026-11-21'));
      await put(exc('r', ExceptionKind.reschedule,
          slotId: 'slot-1', original: '2026-11-28', newDate: '2026-11-29', start: 600, end: 690));
      await put(exc('x', ExceptionKind.extra, newDate: '2026-11-30', start: 600, end: 690));
    });

    test('kind is checked', () async {
      final bad = stamp(exceptionToCompanion(
              exc('k', ExceptionKind.cancel, slotId: 'slot-1', original: '2026-11-21'))
          .copyWith).copyWith(kind: const Value('move'));
      await expectLater(db.into(db.scheduleExceptions).insert(bad), checkFails);
    });

    test('cancel needs slot and original date', () async {
      await expectLater(put(exc('c1', ExceptionKind.cancel, original: '2026-11-21')), checkFails);
      await expectLater(put(exc('c2', ExceptionKind.cancel, slotId: 'slot-1')), checkFails);
    });

    test('reschedule needs slot, original and new date/time', () async {
      await expectLater(
          put(exc('r1', ExceptionKind.reschedule,
              slotId: 'slot-1', original: '2026-11-28', newDate: '2026-11-29', start: 600)),
          checkFails);
      await expectLater(
          put(exc('r2', ExceptionKind.reschedule,
              original: '2026-11-28', newDate: '2026-11-29', start: 600, end: 690)),
          checkFails);
      await expectLater(
          put(exc('r3', ExceptionKind.reschedule,
              slotId: 'slot-1', original: '2026-11-28', start: 600, end: 690)),
          checkFails);
    });

    test('extra needs new date/time only', () async {
      await expectLater(put(exc('x1', ExceptionKind.extra, start: 600, end: 690)), checkFails);
      await expectLater(
          put(exc('x2', ExceptionKind.extra,
              slotId: 'slot-1', newDate: '2026-11-30', start: 600, end: 690)),
          checkFails);
    });

    test('new time range is checked', () async {
      await expectLater(
          put(exc('t1', ExceptionKind.extra, newDate: '2026-11-30', start: 690, end: 600)),
          checkFails);
      await expectLater(
          put(exc('t2', ExceptionKind.extra, newDate: '2026-11-30', start: 1400, end: 1500)),
          checkFails);
    });

    test('slot must exist', () async {
      await expectLater(
          put(exc('f', ExceptionKind.cancel, slotId: 'nope', original: '2026-11-21')), fkFails);
    });
  });

  test('batch_fees amount >= 0', () async {
    final c = stamp(batchFeeToCompanion('bat-1', fee(202611, 1500)).copyWith);
    await db.into(db.batchFees).insert(c);
    await expectLater(
        db.into(db.batchFees).insert(c.copyWith(id: const Value('f2'), amount: const Value(-1))),
        checkFails);
  });

  group('students', () {
    test('status active or left', () async {
      final c = stamp(studentToCompanion(studentA).copyWith).copyWith(id: const Value('s2'));
      await expectLater(
          db.into(db.students).insert(c.copyWith(status: const Value('gone'))), checkFails);
      await db.into(db.students).insert(c.copyWith(status: const Value('left')));
    });

    test('has_photo is 0 or 1', () async {
      await expectLater(
          db.customStatement(
              "INSERT INTO students (id, created_at, updated_at, device_id, name, admission_date, "
              "status, has_photo) VALUES ('s3', 1, 1, 'd', 'n', '2026-11-01', 'active', 2)"),
          checkFails);
    });
  });

  group('student_photos', () {
    StudentPhotosCompanion photo(String id, int size) => StudentPhotosCompanion(
          id: Value(id),
          jpeg: Value(Uint8List(size)),
          createdAt: const Value(t0),
          updatedAt: const Value(t0),
          deviceId: const Value(dev),
        );

    test('id references students', () async {
      await expectLater(db.into(db.studentPhotos).insert(photo('nope', 10)), fkFails);
      await db.into(db.studentPhotos).insert(photo('stu-1', 204800));
    });

    test('jpeg at most 200 KB', () async {
      await expectLater(db.into(db.studentPhotos).insert(photo('stu-1', 204801)), checkFails);
    });
  });

  test('enrollments reference student and batch', () async {
    final c = stamp(enrollmentToCompanion(enrollmentA).copyWith).copyWith(id: const Value('e2'));
    await expectLater(
        db.into(db.enrollments).insert(c.copyWith(studentId: const Value('nope'))), fkFails);
    await expectLater(
        db.into(db.enrollments).insert(c.copyWith(batchId: const Value('nope'))), fkFails);
    // Re-enrolling in the same batch is allowed (no unique key).
    await db.into(db.enrollments).insert(c);
  });

  test('enrollment_fees amount NULL or >= 0', () async {
    await db.into(db.enrollmentFees).insert(stamp(enrollmentFeeToCompanion('enr-1', fee(202611, 0)).copyWith));
    await db.into(db.enrollmentFees).insert(stamp(enrollmentFeeToCompanion('enr-1', fee(202612, null)).copyWith));
    await expectLater(
        db.into(db.enrollmentFees).insert(stamp(enrollmentFeeToCompanion('enr-1', fee(202701, -5)).copyWith)),
        checkFails);
    await expectLater(
        db.into(db.enrollmentFees).insert(stamp(enrollmentFeeToCompanion('nope', fee(202701, 5)).copyWith)),
        fkFails);
  });

  group('attendance', () {
    test('session time range and references', () async {
      final ok = stamp(sessionToCompanion(sessionFor('s.slot-1.20261121')).copyWith);
      await expectLater(
          db.into(db.attendanceSessions).insert(ok.copyWith(startMin: const Value(1100))), checkFails);
      await expectLater(
          db.into(db.attendanceSessions).insert(ok.copyWith(slotId: const Value('nope'))), fkFails);
      await expectLater(
          db.into(db.attendanceSessions).insert(ok.copyWith(exceptionId: const Value('nope'))),
          fkFails);
      await db.into(db.attendanceSessions).insert(ok);
    });

    test('several sessions of one batch on one date', () async {
      await db.into(db.attendanceSessions)
          .insert(stamp(sessionToCompanion(sessionFor('s.slot-1.20261121')).copyWith));
      final second = sessionFor('s.slot-2.20261121', slotId: null);
      await db.into(db.attendanceSessions).insert(stamp(sessionToCompanion(second).copyWith));
      final rows = await db.select(db.attendanceSessions).get();
      expect(rows.map((r) => r.date).toSet(), {'2026-11-21'});
      expect(rows, hasLength(2));
    });

    test('record status P, A, L, E only; session must exist', () async {
      const occ = 's.slot-1.20261121';
      await db.into(db.attendanceSessions).insert(stamp(sessionToCompanion(sessionFor(occ)).copyWith));
      final rec = stamp(recordToCompanion(recordFor(occ, AttendanceStatus.leave)).copyWith);
      await expectLater(
          db.into(db.attendanceRecords).insert(rec.copyWith(status: const Value('X'))), checkFails);
      await expectLater(
          db.into(db.attendanceRecords).insert(rec.copyWith(status: const Value('p'))), checkFails);
      await expectLater(
          db.into(db.attendanceRecords).insert(rec.copyWith(sessionId: const Value('nope'))),
          fkFails);
      await db.into(db.attendanceRecords).insert(rec);
      expect((await db.select(db.attendanceRecords).getSingle()).status, 'E');
    });
  });

  group('payments', () {
    PaymentsCompanion p(String id) => stamp(paymentToCompanion(paymentFor(id)).copyWith);

    test('amount >= 0 and waived rows have amount 0', () async {
      await expectLater(
          db.into(db.payments).insert(p('a').copyWith(amount: const Value(-1))), checkFails);
      await expectLater(
          db.into(db.payments).insert(p('b').copyWith(waived: const Value(true))), checkFails);
      await db.into(db.payments)
          .insert(p('c').copyWith(waived: const Value(true), amount: const Value(0)));
    });

    test('method: built-ins and custom:<1..20 chars>', () async {
      for (final ok in ['cash', 'bkash', 'nagad', 'rocket', 'bank', 'other', 'custom:Upay',
        'custom:${'x' * 20}', 'custom:উপায়']) {
        await db.into(db.payments).insert(p('ok-$ok').copyWith(method: Value(ok)));
      }
      for (final bad in ['paypal', 'Cash', 'custom:', 'CUSTOM:x', 'custom:${'x' * 21}', '']) {
        await expectLater(
            db.into(db.payments).insert(p('bad-$bad').copyWith(method: Value(bad))),
            checkFails,
            reason: bad);
      }
    });

    test('waived is 0 or 1', () async {
      await expectLater(
          db.customStatement(
              "INSERT INTO payments (id, created_at, updated_at, device_id, receipt_id, student_id, "
              "enrollment_id, batch_id, billing_month, amount, paid_on, method, waived) VALUES "
              "('w', 1, 1, 'd', 'r', 'stu-1', 'enr-1', 'bat-1', 202611, 0, '2026-11-20', 'cash', 2)"),
          checkFails);
    });

    test('receipt_id is required', () async {
      await expectLater(
          db.customStatement(
              "INSERT INTO payments (id, created_at, updated_at, device_id, student_id, "
              "enrollment_id, batch_id, billing_month, amount, paid_on, method) VALUES "
              "('n', 1, 1, 'd', 'stu-1', 'enr-1', 'bat-1', 202611, 0, '2026-11-20', 'cash')"),
          sqlFails('NOT NULL constraint failed'));
    });

    test('references are enforced', () async {
      await expectLater(
          db.into(db.payments).insert(p('f1').copyWith(enrollmentId: const Value('nope'))),
          fkFails);
      await expectLater(
          db.into(db.payments).insert(p('f2').copyWith(studentId: const Value('nope'))), fkFails);
      await expectLater(
          db.into(db.payments).insert(p('f3').copyWith(batchId: const Value('nope'))), fkFails);
    });
  });

  group('other_income', () {
    test('amount, method and optional student', () async {
      final c = stamp(otherIncomeToCompanion(incomeFor('o1')).copyWith);
      await expectLater(
          db.into(db.otherIncome).insert(c.copyWith(amount: const Value(-1))), checkFails);
      await expectLater(
          db.into(db.otherIncome).insert(c.copyWith(method: const Value('gold'))), checkFails);
      await expectLater(
          db.into(db.otherIncome).insert(c.copyWith(studentId: const Value('nope'))), fkFails);
      await db.into(db.otherIncome).insert(c.copyWith(studentId: const Value(null)));
      await db.into(db.otherIncome).insert(
          c.copyWith(id: const Value('o2'), method: const Value('custom:Book shop')));
    });
  });

  test('sync columns are NOT NULL (except deleted_at)', () async {
    await expectLater(
        db.customStatement(
            "INSERT INTO subjects (id, created_at, updated_at, name) VALUES ('s', 1, 1, 'n')"),
        sqlFails('NOT NULL constraint failed'));
  });
}
