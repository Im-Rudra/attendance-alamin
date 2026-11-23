import 'dart:convert';

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:drift/drift.dart' hide Batch, isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';

import 'structure_fixtures.dart';

Matcher validation(String code) => throwsA(
    isA<ValidationException>().having((e) => e.code, 'code', code));

/// Inserts an active student with an open enrollment in [batchId].
Future<String> addEnrollment(
  Harness h,
  String batchId, {
  String student = 'stu-1',
  String id = 'enr-1',
  YearMonth start = const YearMonth(2026, 11),
  YearMonth? endMonth,
  LocalDate? endDate,
}) async {
  await h.db.into(h.db.students).insert(stamped(studentToCompanion(Student(
        id: student,
        name: 'Rahim',
        admissionDate: today,
        status: StudentStatus.active,
      )).copyWith));
  await h.db.into(h.db.enrollments).insert(stamped(enrollmentToCompanion(
        Enrollment(
          id: id,
          studentId: student,
          batchId: batchId,
          joinDate: today,
          startMonth: start,
          endMonth: endMonth,
          endDate: endDate,
        ),
      ).copyWith));
  return id;
}

Future<void> addPayment(
  Harness h,
  String batchId, {
  required String id,
  required YearMonth month,
  required int amount,
  String enrollment = 'enr-1',
  String student = 'stu-1',
  bool waived = false,
  String receipt = 'rcpt-1',
}) =>
    h.db.into(h.db.payments).insert(stamped(paymentToCompanion(Payment(
          id: id,
          receiptId: receipt,
          studentId: student,
          enrollmentId: enrollment,
          batchId: batchId,
          billingMonth: month,
          amount: amount,
          paidOn: today,
          method: PaymentMethod.cash,
          waived: waived,
        )).copyWith));

void main() {
  late Harness h;

  setUp(() => h = Harness());

  group('create', () {
    test('writes batch, first fee and slots in one stamped transaction',
        () async {
      final physics = await h.physicsA();
      final b = await h.batchRow(physics);
      expect(b.name, 'Physics A');
      expect(b.billingType, 'prepaid');
      expect(b.sortOrder, 0);
      expect(b.reminderLeadMin, isNull);
      expectInserted(
          createdAt: b.createdAt,
          updatedAt: b.updatedAt,
          rev: b.rev,
          deviceId: b.deviceId,
          deletedAt: b.deletedAt);

      final fees = await h.batches.watchFees(physics).first;
      expect(fees, [const FeePeriod(effective: YearMonth(2026, 11), amount: 1000)]);
      final feeRow = await (h.db.select(h.db.batchFees)).getSingle();
      expect(feeRow.id, Ids.batchFee(physics, const YearMonth(2026, 11)));
      expectInserted(
          createdAt: feeRow.createdAt,
          updatedAt: feeRow.updatedAt,
          rev: feeRow.rev,
          deviceId: feeRow.deviceId,
          deletedAt: feeRow.deletedAt);

      final slots = await h.slotRows(physics);
      expect(slots, hasLength(3));
      for (final s in slots) {
        expect(s.validFrom, '2026-11-20');
        expect(s.validTo, isNull);
        expectInserted(
            createdAt: s.createdAt,
            updatedAt: s.updatedAt,
            rev: s.rev,
            deviceId: s.deviceId,
            deletedAt: s.deletedAt);
      }
      expect((await h.batches.getById(physics))?.createdOn, today);
    });

    test('a batch can be created with fee 0 (no fee yet) and priced later',
        () async {
      final sub = await h.subject('Physics');
      final id = await h.batch(sub, 'Physics Z',
          fee: 0, slots: [slot(sat, 960, 1020)]);
      expect(await h.batches.watchFees(id).first,
          [const FeePeriod(effective: YearMonth(2026, 11), amount: 0)]);
      await h.batches.setFee(id, 900, const YearMonth(2026, 12));
      expect(await h.batches.watchFees(id).first, [
        const FeePeriod(effective: YearMonth(2026, 11), amount: 0),
        const FeePeriod(effective: YearMonth(2026, 12), amount: 900),
      ]);
    });

    test('remembers the billing type as last_billing_type', () async {
      await h.chemB();
      final row = await (h.db.select(h.db.localMeta)
            ..where((t) => t.metaKey.equals('last_billing_type')))
          .getSingle();
      expect(jsonDecode(row.metaValue), 'postpaid');
      await h.physicsA();
      final again = await (h.db.select(h.db.localMeta)
            ..where((t) => t.metaKey.equals('last_billing_type')))
          .getSingle();
      expect(jsonDecode(again.metaValue), 'prepaid');
    });

    test('sort order grows', () async {
      final a = await h.physicsA();
      final b = await h.chemB();
      expect((await h.batchRow(a)).sortOrder, 0);
      expect((await h.batchRow(b)).sortOrder, 1);
      final list = await h.batches.watchAll().first;
      expect([for (final x in list) x.name], ['Physics A', 'Chem B']);
    });

    test('validates input and writes nothing on failure', () async {
      final sub = await h.subject('Physics');
      Future<String> make({
        String name = 'X',
        int fee = 1000,
        List<SlotDraft>? slots,
        int? lead,
        String? subjectId,
      }) =>
          h.batch(subjectId ?? sub, name,
              slots: slots ?? [slot(sat, 960, 1020)], fee: fee, lead: lead);

      await expectLater(make(name: ' '), validation(ErrorCodes.nameRequired));
      await expectLater(make(fee: -1), validation(ErrorCodes.amountInvalid));
      await expectLater(
          make(fee: 1000001), validation(ErrorCodes.amountTooLarge));
      await expectLater(make(slots: []), validation(ErrorCodes.slotsEmpty));
      await expectLater(make(slots: [slot(sat, 1020, 960)]),
          validation(ErrorCodes.slotTimeInvalid));
      await expectLater(make(slots: [slot(sat, 0, 1441)]),
          validation(ErrorCodes.slotTimeInvalid));
      await expectLater(make(slots: [slot(8, 600, 660)]),
          validation(ErrorCodes.slotTimeInvalid));
      await expectLater(make(lead: 721), validation(ErrorCodes.amountInvalid));
      await expectLater(
          make(subjectId: 'missing'), throwsA(isA<NotFoundException>()));
      expect(await h.db.select(h.db.batches).get(), isEmpty);
      expect(await h.db.select(h.db.batchSlots).get(), isEmpty);
      expect(await h.db.select(h.db.batchFees).get(), isEmpty);
    });

    test('a clash refuses the whole batch (Product 18 through create)',
        () async {
      await h.chemB();
      final sub = await h.subject('Math');
      // Sun 11:00-12:00 touches Chem B's 10:00-11:00: allowed.
      final ok = await h.batch(sub, 'Math C', slots: [slot(sun, 660, 720)]);
      expect(await h.batches.getById(ok), isNotNull);
      // Sun 10:55-11:55 overlaps.
      final e = await expectClash(() async {
        await h.batch(sub, 'Math D', slots: [slot(sun, 655, 715)]);
      });
      expect(e.code, ErrorCodes.scheduleClash);
      expect(e.result.groups.where((g) => g.startMin == 600 && g.everyWeek),
          hasLength(1));
      expect((await h.db.select(h.db.batches).get()).map((b) => b.name),
          isNot(contains('Math D')));
    });

    test('a batch\'s own slots must not overlap', () async {
      final sub = await h.subject('Physics');
      await expectClash(() async {
        await h.batch(sub, 'P',
            slots: [slot(fri, 480, 540), slot(fri, 500, 560)]);
      });
    });
  });

  group('simple edits', () {
    test('rename / billing / lead / notes stamp updatedAt and rev', () async {
      final id = await h.physicsA();
      h.setNow(DateTime.fromMillisecondsSinceEpoch(t0 + 2000, isUtc: true));
      await h.batches.rename(id, '  Physics Z ');
      await h.batches.setBillingType(id, BillingType.postpaid);
      await h.batches.setReminderLead(id, 0);
      await h.batches.setNotes(id, ' evening ');
      final b = await h.batchRow(id);
      expect(b.name, 'Physics Z');
      expect(b.billingType, 'postpaid');
      expect(b.reminderLeadMin, 0);
      expect(b.notes, 'evening');
      expect(b.rev, 5);
      expect(b.updatedAt, t0 + 2003); // t0+2000, then +1 each for 3 more
      expect(b.createdAt, t0);
      expect(b.deviceId, dev);

      await h.batches.setReminderLead(id, null);
      await h.batches.setNotes(id, '  ');
      final c = await h.batches.getById(id);
      expect(c?.reminderLeadMin, isNull);
      expect(c?.notes, isNull);
    });

    test('validation and not-found', () async {
      final id = await h.physicsA();
      await expectLater(
          h.batches.rename(id, ''), validation(ErrorCodes.nameRequired));
      await expectLater(h.batches.setReminderLead(id, 721),
          validation(ErrorCodes.amountInvalid));
      await expectLater(h.batches.setReminderLead(id, -1),
          validation(ErrorCodes.amountInvalid));
      await expectLater(
          h.batches.rename('nope', 'X'), throwsA(isA<NotFoundException>()));
    });

    test('watchById emits the batch and null after a soft delete', () async {
      final id = await h.physicsA();
      expect((await h.batches.watchById(id).first)?.name, 'Physics A');
      await h.batches.softDelete(id);
      expect(await h.batches.watchById(id).first, isNull);
    });
  });

  group('fees', () {
    test('setFee adds history rows effective from a month (Product 11)',
        () async {
      final id = await h.physicsA();
      await h.batches.setFee(id, 1200, const YearMonth(2026, 12));
      final fees = await h.batches.watchFees(id).first;
      expect(fees, [
        const FeePeriod(effective: YearMonth(2026, 11), amount: 1000),
        const FeePeriod(effective: YearMonth(2026, 12), amount: 1200),
      ]);
      final row = await (h.db.select(h.db.batchFees)
            ..where((t) => t.effectiveMonth.equals(202612)))
          .getSingle();
      expect(row.id, Ids.batchFee(id, const YearMonth(2026, 12)));
      expect(row.rev, 1);
    });

    test('setFee for the same month replaces the amount (rev + 1)', () async {
      final id = await h.physicsA();
      h.setNow(DateTime.fromMillisecondsSinceEpoch(t0 + 100, isUtc: true));
      await h.batches.setFee(id, 900, const YearMonth(2026, 11));
      final fees = await h.batches.watchFees(id).first;
      expect(fees, [const FeePeriod(effective: YearMonth(2026, 11), amount: 900)]);
      final row = await (h.db.select(h.db.batchFees)).getSingle();
      expect(row.rev, 2);
      expect(row.updatedAt, t0 + 100);
      // Same value again is a no-op.
      await h.batches.setFee(id, 900, const YearMonth(2026, 11));
      expect((await (h.db.select(h.db.batchFees)).getSingle()).rev, 2);
    });

    test('QA-01: a fee from before the first record keeps earlier months',
        () async {
      // Batch fee ৳1000 from Nov; a migrated student billed from Aug.
      final id = await h.physicsA();
      await addEnrollment(h, id, start: const YearMonth(2026, 8));
      await h.batches.setFee(id, 1200, const YearMonth(2026, 10));
      final fees = await h.batches.watchFees(id).first;
      expect(fees, [
        const FeePeriod(effective: YearMonth(2026, 8), amount: 1000),
        const FeePeriod(effective: YearMonth(2026, 10), amount: 1200),
        const FeePeriod(effective: YearMonth(2026, 11), amount: 1000),
      ]);
    });

    test('QA-01: preview counts paid months before the first fee record',
        () async {
      final id = await h.physicsA(); // ৳1000 from Nov
      await addEnrollment(h, id, start: const YearMonth(2026, 9));
      await addPayment(h, id,
          id: 'p-sep', month: const YearMonth(2026, 9), amount: 1000);
      await addPayment(h, id,
          id: 'p-oct', month: const YearMonth(2026, 10), amount: 1000);
      // Sep and Oct are billed at the backdated ৳1000; a rise from Sep
      // (bounded by the Nov row) splits both.
      expect(
          await h.batches
              .previewPartialMonths(id, 1200, const YearMonth(2026, 9)),
          2);
    });

    test('setFee validates', () async {
      final id = await h.physicsA();
      await expectLater(h.batches.setFee(id, -5, const YearMonth(2026, 12)),
          validation(ErrorCodes.amountInvalid));
      await expectLater(
          h.batches.setFee(id, 2000000, const YearMonth(2026, 12)),
          validation(ErrorCodes.amountTooLarge));
      await expectLater(
          h.batches.setFee('nope', 5, const YearMonth(2026, 12)),
          throwsA(isA<NotFoundException>()));
    });

    test('previewPartialMonths counts fully paid months a rise would split',
        () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      await addPayment(h, id,
          id: 'p-nov', month: const YearMonth(2026, 11), amount: 1000);
      await addPayment(h, id,
          id: 'p-dec', month: const YearMonth(2026, 12), amount: 1000);
      await addPayment(h, id,
          id: 'p-jan', month: const YearMonth(2027, 1), amount: 400);

      // From Dec: only Dec was fully paid at 1000 and would fall short of 1200.
      expect(
          await h.batches
              .previewPartialMonths(id, 1200, const YearMonth(2026, 12)),
          1);
      // From Nov: Nov and Dec.
      expect(
          await h.batches
              .previewPartialMonths(id, 1200, const YearMonth(2026, 11)),
          2);
      // A cut never makes a month partial.
      expect(
          await h.batches
              .previewPartialMonths(id, 800, const YearMonth(2026, 11)),
          0);
      // A later fee row bounds the affected months.
      await h.batches.setFee(id, 1000, const YearMonth(2026, 12));
      expect(
          await h.batches
              .previewPartialMonths(id, 1200, const YearMonth(2026, 11)),
          1);
    });

    test('previewPartialMonths skips waived months and overrides', () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      await addPayment(h, id,
          id: 'p-nov', month: const YearMonth(2026, 11), amount: 1000);
      await addPayment(h, id,
          id: 'w-dec',
          month: const YearMonth(2026, 12),
          amount: 0,
          waived: true,
          receipt: 'w-dec');
      await addPayment(h, id,
          id: 'p-dec', month: const YearMonth(2026, 12), amount: 1000);
      expect(
          await h.batches
              .previewPartialMonths(id, 1200, const YearMonth(2026, 11)),
          1);
      // An override in effect from Nov exempts the enrollment.
      await h.db.into(h.db.enrollmentFees).insert(stamped(
          enrollmentFeeToCompanion('enr-1',
                  const FeePeriod(effective: YearMonth(2026, 11), amount: 800))
              .copyWith));
      expect(
          await h.batches
              .previewPartialMonths(id, 1200, const YearMonth(2026, 11)),
          0);
    });
  });

  group('archive / unarchive (Product 9)', () {
    test('archive sets the date and the last billable month', () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      h.setNow(DateTime.fromMillisecondsSinceEpoch(t0 + 4000, isUtc: true));
      await h.batches.archive(id,
          on: d(2026, 11, 15), lastBillableMonth: const YearMonth(2026, 11));

      final b = await h.batches.getById(id);
      expect(b?.archivedOn, d(2026, 11, 15));
      expect(b?.archived, isTrue);
      final row = await h.batchRow(id);
      expect(row.rev, 2);
      expect(row.updatedAt, t0 + 4000);
      final e = await h.enrollmentRow('enr-1');
      expect(e.endMonth, 202611);
      expect(e.endDate, isNull);
      expect(e.rev, 2);
      expect(e.updatedAt, t0 + 4000);

      expect(await h.batches.watchAll().first, isEmpty);
      expect(
          [for (final x in await h.batches.watchAll(includeArchived: true).first) x.id],
          [id]);

      // No classes, no roll call.
      final occ = ScheduleEngine.expand(
              range: DateRange(d(2026, 11, 21), d(2026, 11, 30)),
              batches: await h.loaded())
          .occurrences;
      expect(occ, isEmpty);

      await expectLater(
          h.batches.archive(id,
              on: d(2026, 11, 16), lastBillableMonth: const YearMonth(2026, 11)),
          validation(ErrorCodes.batchArchived));
    });

    test('archive leaves already ended enrollments alone', () async {
      final id = await h.physicsA();
      await addEnrollment(h, id,
          endMonth: const YearMonth(2026, 10), endDate: d(2026, 10, 25));
      await h.batches.archive(id,
          on: d(2026, 11, 15), lastBillableMonth: const YearMonth(2026, 11));
      final e = await h.enrollmentRow('enr-1');
      expect(e.endMonth, 202610);
      expect(e.rev, 1);
    });

    test('unarchive reopens enrollments and waives the gap months', () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      await h.batches.archive(id,
          on: d(2026, 11, 15), lastBillableMonth: const YearMonth(2026, 11));

      // 2027-01-10: December is the gap (November was the last billable month).
      h.setNow(DateTime.utc(2027, 1, 10, 6));
      expect((await h.batches.previewUnarchive(id)).ok, isTrue);
      final gap = await h.batches.unarchive(id);
      expect(gap, 1);

      expect((await h.batches.getById(id))?.archived, isFalse);
      final e = await h.enrollmentRow('enr-1');
      expect(e.endMonth, isNull);
      expect(e.rev, 3);

      final waiver = await (h.db.select(h.db.payments)).getSingle();
      expect(waiver.id, Ids.waiver('enr-1', const YearMonth(2026, 12)));
      expect(waiver.waived, isTrue);
      expect(waiver.amount, 0);
      expect(waiver.billingMonth, 202612);
      expect(waiver.enrollmentId, 'enr-1');
      expect(waiver.batchId, id);
      expect(waiver.studentId, 'stu-1');
      expect(waiver.rev, 1);
      expect(waiver.paidOn, '2027-01-10');
      expect(waiver.createdAt, h.nowMs);
    });

    test('unarchive without waiving, and with no gap', () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      await h.batches.archive(id,
          on: d(2026, 11, 15), lastBillableMonth: const YearMonth(2026, 11));
      h.setNow(DateTime.utc(2027, 1, 10, 6));
      expect(await h.batches.unarchive(id, waiveGap: false), 1);
      expect(await h.db.select(h.db.payments).get(), isEmpty);

      // Archive and unarchive in the same month: no gap.
      await h.batches.archive(id,
          on: d(2027, 1, 12), lastBillableMonth: const YearMonth(2027, 1));
      expect(await h.batches.unarchive(id), 0);
      expect(await h.db.select(h.db.payments).get(), isEmpty);
    });

    test('unarchive does not reopen enrollments that left on their own',
        () async {
      final id = await h.physicsA();
      await addEnrollment(h, id,
          endMonth: const YearMonth(2026, 10), endDate: d(2026, 10, 25));
      await h.batches.archive(id,
          on: d(2026, 11, 15), lastBillableMonth: const YearMonth(2026, 11));
      h.setNow(DateTime.utc(2027, 1, 10, 6));
      await h.batches.unarchive(id);
      final e = await h.enrollmentRow('enr-1');
      expect(e.endMonth, 202610);
      expect(e.endDate, '2026-10-25');
    });

    test('finished-on date: the batch is finished on the chosen past day',
        () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      await h.batches.archive(id,
          on: d(2026, 11, 3), lastBillableMonth: const YearMonth(2026, 10));
      expect((await h.batches.getById(id))?.archivedOn, d(2026, 11, 3));
      final e = await h.enrollmentRow('enr-1');
      expect(e.endMonth, 202610);
    });

    test('reopen date: billing restarts from that month', () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      await h.batches.archive(id,
          on: d(2026, 11, 15), lastBillableMonth: const YearMonth(2026, 11));
      h.setNow(DateTime.utc(2027, 1, 10, 6));

      // Classes started again on 5 Jan: December is the closed month.
      expect(await h.batches.unarchive(id, on: d(2027, 1, 5)), 1);
      expect((await h.batches.getById(id))?.archived, isFalse);
      final e = await h.enrollmentRow('enr-1');
      expect(e.endMonth, isNull);
      final waivers = await h.db.select(h.db.payments).get();
      expect([for (final w in waivers) w.billingMonth], [202612]);
      // The waiver is recorded on the real day, not the reopen date.
      expect(waivers.single.paidOn, '2027-01-10');
    });

    test('reopen date in the month after finishing leaves no gap', () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      await h.batches.archive(id,
          on: d(2026, 11, 15), lastBillableMonth: const YearMonth(2026, 11));
      h.setNow(DateTime.utc(2027, 1, 10, 6));
      // 20 Dec: classes restart in December, so December is billed.
      expect(await h.batches.unarchive(id, on: d(2026, 12, 20)), 0);
      expect(await h.db.select(h.db.payments).get(), isEmpty);
      expect((await h.enrollmentRow('enr-1')).endMonth, isNull);
    });

    test('reopen date without waiving keeps the closed months as dues',
        () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      await h.batches.archive(id,
          on: d(2026, 11, 15), lastBillableMonth: const YearMonth(2026, 11));
      h.setNow(DateTime.utc(2027, 1, 10, 6));
      expect(
          await h.batches.unarchive(id, waiveGap: false, on: d(2027, 1, 2)), 1);
      expect(await h.db.select(h.db.payments).get(), isEmpty);
    });

    test('reopen date must lie between the day after finishing and today',
        () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      await h.batches.archive(id,
          on: d(2026, 11, 15), lastBillableMonth: const YearMonth(2026, 11));
      h.setNow(DateTime.utc(2027, 1, 10, 6));
      // Not on or before the finish day.
      await expectLater(h.batches.unarchive(id, on: d(2026, 11, 15)),
          validation(ErrorCodes.dateInvalid));
      await expectLater(h.batches.unarchive(id, on: d(2026, 10, 1)),
          validation(ErrorCodes.dateInvalid));
      // Not in the future.
      await expectLater(h.batches.unarchive(id, on: d(2027, 1, 11)),
          validation(ErrorCodes.dateInFuture));
      expect((await h.batches.getById(id))?.archived, isTrue);
      // The day after finishing is the earliest allowed.
      await h.batches.unarchive(id, on: d(2026, 11, 16));
      expect((await h.batches.getById(id))?.archived, isFalse);
    });

    test('unarchive of a live batch is a no-op', () async {
      final id = await h.physicsA();
      expect(await h.batches.unarchive(id), 0);
      expect((await h.batchRow(id)).rev, 1);
    });
  });

  group('un-archive clash (Product 21)', () {
    Future<String> archivedOldBio() async {
      final bio = await h.subject('Biology');
      final old = await h.batch(bio, 'Old Bio', slots: [slot(sat, 960, 1020)]);
      await h.batches.archive(old,
          on: d(2026, 11, 20), lastBillableMonth: const YearMonth(2026, 11));
      return old;
    }

    test('an archived batch never conflicts', () async {
      await archivedOldBio();
      // Physics A has the same Sat 16:00-17:00 slot: saves.
      final physics = await h.physicsA();
      expect(await h.batches.getById(physics), isNotNull);
    });

    test('un-archiving lists the clash and needs acceptance', () async {
      final old = await archivedOldBio();
      final physics = await h.physicsA();

      final preview = await h.batches.previewUnarchive(old);
      expect(preview.ok, isFalse);
      expect(preview.groups, hasLength(1));
      final g = preview.groups.single;
      expect(g.batchId, physics);
      expect(g.everyWeek, isTrue);
      expect(g.weekday, sat);
      expect(g.startMin, 960);
      expect(g.endMin, 1020);

      final e = await expectClash(() async {
        await h.batches.unarchive(old);
      });
      expect(e.result.groups.single.batchId, physics);
      expect((await h.batches.getById(old))?.archived, isTrue);

      await h.batches.unarchive(old, acceptClashes: true);
      expect((await h.batches.getById(old))?.archived, isFalse);
    });

    test('un-archiving without a clash just works', () async {
      final old = await archivedOldBio();
      expect((await h.batches.previewUnarchive(old)).ok, isTrue);
      await h.batches.unarchive(old);
      expect((await h.batches.getById(old))?.archived, isFalse);
    });
  });

  group('delete', () {
    test('deleteImpact counts what goes with the batch', () async {
      final id = await h.physicsA();
      await addEnrollment(h, id);
      await addPayment(h, id,
          id: 'p1', month: const YearMonth(2026, 11), amount: 500);
      await addPayment(h, id,
          id: 'p2', month: const YearMonth(2026, 12), amount: 500);
      await addPayment(h, id,
          id: 'p3',
          month: const YearMonth(2027, 1),
          amount: 500,
          receipt: 'rcpt-2');
      final slotId = await h.slotId(id, sat);
      await h.db.into(h.db.attendanceSessions).insert(stamped(
          sessionToCompanion(AttendanceSession(
            id: 'ses-1',
            occ: 's.$slotId.20261121',
            batchId: id,
            slotId: slotId,
            originalDate: d(2026, 11, 21),
            date: d(2026, 11, 21),
            startMin: 960,
            endMin: 1020,
          )).copyWith));

      final impact = await h.batches.deleteImpact(id);
      expect(impact.sessions, 1);
      expect(impact.payments, 2); // two receipts
      expect(impact.students, 1);
    });

    test('softDelete tombstones the batch and everything under it', () async {
      final physics = await h.physicsA();
      final chem = await h.chemB();
      await addEnrollment(h, physics);
      await addPayment(h, physics,
          id: 'p1', month: const YearMonth(2026, 11), amount: 500);
      final slotId = await h.slotId(physics, sat);
      await h.schedule.cancel('s.$slotId.20261121');
      await h.db.into(h.db.attendanceSessions).insert(stamped(
          sessionToCompanion(AttendanceSession(
            id: 'ses-1',
            occ: 's.$slotId.20261121',
            batchId: physics,
            slotId: slotId,
            originalDate: d(2026, 11, 21),
            date: d(2026, 11, 21),
            startMin: 960,
            endMin: 1020,
          )).copyWith));
      await h.db.into(h.db.attendanceRecords).insert(stamped(
          recordToCompanion(AttendanceRecord(
            id: 'rec-1',
            sessionId: 'ses-1',
            batchId: physics,
            studentId: 'stu-1',
            date: d(2026, 11, 21),
            status: AttendanceStatus.present,
          )).copyWith));

      h.setNow(DateTime.fromMillisecondsSinceEpoch(t0 + 7000, isUtc: true));
      await h.batches.softDelete(physics);

      Future<void> tombstoned(String table, String column) async {
        final rows = await h.db.customSelect(
          'SELECT deleted_at, rev FROM $table WHERE $column = ?',
          variables: [Variable.withString(physics)],
        ).get();
        expect(rows, isNotEmpty, reason: table);
        for (final r in rows) {
          expect(r.read<int>('deleted_at'), t0 + 7000, reason: table);
          expect(r.read<int>('rev'), 2, reason: table);
        }
      }

      await tombstoned('batches', 'id');
      await tombstoned('batch_slots', 'batch_id');
      await tombstoned('batch_fees', 'batch_id');
      await tombstoned('schedule_exceptions', 'batch_id');
      await tombstoned('enrollments', 'batch_id');
      await tombstoned('payments', 'batch_id');
      await tombstoned('attendance_sessions', 'batch_id');
      await tombstoned('attendance_records', 'batch_id');

      // The other batch is untouched and nothing is hard deleted.
      expect((await h.batches.getById(chem))?.name, 'Chem B');
      expect(await h.batches.getById(physics), isNull);
      expect([for (final b in await h.loaded()) b.batch.id], [chem]);
      expect(await h.batches.watchAll().first, hasLength(1));
      await expectLater(
          h.batches.deleteImpact(physics), throwsA(isA<NotFoundException>()));
      await expectLater(
          h.batches.softDelete(physics), throwsA(isA<NotFoundException>()));
    });
  });
}
