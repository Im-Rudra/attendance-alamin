import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'people_harness.dart';

void main() {
  group('record', () {
    test('writes one row per month with one receipt id, stamped', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202609);
      final now = h.stamper.nowMs();

      final receiptId = await h.payments.record(h.draft(
          r.student, r.enrollment, {202609: 1000, 202610: 600},
          method: PaymentMethod.bkash, note: '  first  '));

      final rows = await h.allPaymentRows();
      expect(rows, hasLength(2));
      for (final row in rows) {
        expect(row.receiptId, receiptId);
        expect((row.createdAt, row.updatedAt, row.rev, row.deviceId, row.deletedAt),
            (now, now, 1, dev, null));
        expect(row.batchId, batPhy);
        expect(row.studentId, r.student);
        expect(row.method, 'bkash');
        expect(row.note, 'first');
        expect(row.paidOn, '2026-11-20');
        expect(row.waived, isFalse);
      }
      final receipt = await h.payments.receipt(receiptId);
      expect([for (final p in receipt) (p.billingMonth, p.amount)],
          [(ym(202609), 1000), (ym(202610), 600)]);
    });

    test('allocations to the same month are merged into one row', () async {
      final h = PeopleHarness();
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202611);
      final id = await h.payments.record(PaymentDraft(
        studentId: r.student,
        enrollmentId: r.enrollment,
        allocations: [
          Allocation(month: ym(202611), amount: 300),
          Allocation(month: ym(202611), amount: 200),
        ],
        paidOn: h.today,
        method: PaymentMethod.cash,
      ));
      final rows = await h.payments.receipt(id);
      expect(rows.single.amount, 500);
    });

    test('a failure mid-way leaves nothing (atomic receipt)', () async {
      final h = PeopleHarness(today: '2026-11-02');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202609);
      await h.db.customStatement(
          'CREATE TRIGGER fail_oct BEFORE INSERT ON payments '
          'WHEN NEW.billing_month = 202610 '
          "BEGIN SELECT RAISE(ABORT, 'boom'); END");

      await expectLater(
          h.payments.record(h.draft(
              r.student, r.enrollment, {202609: 1000, 202610: 1000, 202611: 500})),
          throwsA(anything));

      expect(await h.allPaymentRows(), isEmpty);
      expect(await h.payments.watchFacts().first, isEmpty);
    });

    group('validation (dues engine) writes nothing on failure', () {
      late PeopleHarness h;
      late ({String student, String enrollment}) r;

      setUp(() async {
        h = PeopleHarness(today: '2026-11-04');
        await h.seedBatches();
        r = await h.enrolled('Rahim', fbm: 202611);
      });

      Future<void> fails(Map<int, int> alloc, String code,
          {PaymentDraft? draft}) async {
        await expectLater(
            h.payments.record(draft ?? h.draft(r.student, r.enrollment, alloc)),
            throwsCode(code));
        expect(await h.allPaymentRows(), isEmpty);
      }

      test('more than the remaining of a month', () =>
          fails({202611: 1001}, ErrorCodes.allocationExceedsRemaining));
      test('a month before the first billable month', () =>
          fails({202610: 100}, ErrorCodes.allocationExceedsRemaining));
      test('beyond today + 12 months', () =>
          fails({202712: 100}, ErrorCodes.allocationBeyondHorizon));
      test('no allocations', () => fails({}, ErrorCodes.amountInvalid));
      test('a zero allocation', () =>
          fails({202611: 0}, ErrorCodes.amountInvalid));
      test('total above the money limit', () => fails(
          {}, ErrorCodes.amountTooLarge,
          draft: PaymentDraft(
            studentId: r.student,
            enrollmentId: r.enrollment,
            allocations: [Allocation(month: ym(202611), amount: 1000001)],
            paidOn: h.today,
            method: PaymentMethod.cash,
          )));
      test('invalid custom method', () => fails({202611: 100}, ErrorCodes.nameTooLong,
          draft: h.draft(r.student, r.enrollment, {202611: 100},
              method: const PaymentMethod('custom:abcdefghijklmnopqrstuvwxyz'))));
      test('unknown enrollment', () async {
        await expectLater(
            h.payments.record(h.draft(r.student, 'nope', {202611: 100})),
            throwsA(isA<NotFoundException>()));
      });
      test('enrollment of another student', () async {
        final other = await h.addStudent('Karim');
        await expectLater(
            h.payments.record(h.draft(other, r.enrollment, {202611: 100})),
            throwsA(isA<NotFoundException>()));
      });
    });

    test('advance allocation reaches exactly 12 months ahead', () async {
      final h = PeopleHarness(today: '2026-11-04');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202611);

      // Auto-allocation (Product 3.4): Nov 2026 .. Nov 2027 = 13 months.
      final dues = await h.dues(r.enrollment);
      expect(
          () => DuesEngine.autoAllocate(dues: dues, amount: 13001, today: h.today),
          throwsCode(ErrorCodes.allocationBeyondHorizon));
      final alloc =
          DuesEngine.autoAllocate(dues: dues, amount: 13000, today: h.today);
      expect(alloc.last.month, ym(202711));

      final receiptId = await h.payments.record(PaymentDraft(
        studentId: r.student,
        enrollmentId: r.enrollment,
        allocations: alloc,
        paidOn: h.today,
        method: PaymentMethod.cash,
      ));
      expect(await h.payments.receipt(receiptId), hasLength(13));
      final after = await h.dues(r.enrollment);
      expect(after.months.where((m) => m.state == MonthState.paid), hasLength(13));
    });

    test('a left student can still pay the open months that remain owed',
        () async {
      final h = PeopleHarness(today: '2026-11-05');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202610);
      await h.students.markLeft(r.student,
          on: h.today, lastBillableByEnrollment: const {});
      await h.payments.record(h.draft(r.student, r.enrollment, {202610: 1000}));
      await expectLater(
          h.payments.record(h.draft(r.student, r.enrollment, {202611: 1000})),
          throwsCode(ErrorCodes.allocationExceedsRemaining)); // not billable
      expect((await h.dues(r.enrollment)).totalOutstanding, 0);
    });
  });

  group('Product money scenarios (repo + dues engine)', () {
    test('4: partial then full payment', () async {
      final h = PeopleHarness(today: '2026-11-04');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202611);

      await h.payments.record(h.draft(r.student, r.enrollment, {202611: 600}));
      var nov = monthOf(await h.dues(r.enrollment), 202611);
      expect((nov.state, nov.remaining, nov.level),
          (MonthState.partial, 400, DueLevel.remind));

      await h.payments.record(h.draft(r.student, r.enrollment, {202611: 400}));
      nov = monthOf(await h.dues(r.enrollment), 202611);
      expect(nov.state, MonthState.paid);
      expect((await h.report()).active, isEmpty);
    });

    test('5: ৳2,500 auto-allocated over Sep, Oct, Nov', () async {
      final h = PeopleHarness(today: '2026-11-02');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202609);
      final alloc = DuesEngine.autoAllocate(
          dues: await h.dues(r.enrollment), amount: 2500, today: h.today);
      final receiptId = await h.payments.record(PaymentDraft(
        studentId: r.student,
        enrollmentId: r.enrollment,
        allocations: alloc,
        paidOn: h.today,
        method: PaymentMethod.cash,
      ));

      final dues = await h.dues(r.enrollment);
      expect(monthOf(dues, 202609).state, MonthState.paid);
      expect(monthOf(dues, 202610).state, MonthState.paid);
      expect((monthOf(dues, 202611).state, monthOf(dues, 202611).paid),
          (MonthState.partial, 500));
      expect(dues.totalOutstanding, 500);
      expect([for (final p in await h.payments.receipt(receiptId)) p.amount],
          [1000, 1000, 500]);
    });

    test('7: paying one batch leaves the other batch untouched', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final sara = await h.addStudent('Sara');
      final phy = await h.enrollments.enroll(
          studentId: sara, batchId: batPhy, joinDate: d('2026-11-01'),
          startMonth: ym(202611));
      final chem = await h.enrollments.enroll(
          studentId: sara, batchId: batChem, joinDate: d('2026-11-01'),
          startMonth: ym(202611));
      final chemBefore = await h.dues(chem);

      await h.payments.record(h.draft(sara, phy, {202611: 1000}));

      expect(monthOf(await h.dues(phy), 202611).state, MonthState.paid);
      expect(await h.dues(chem), chemBefore);
      expect(monthOf(chemBefore, 202611).remaining, 800);
    });

    test('10: waived month is not a due; fee override 0 never creates dues',
        () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202611);
      final free = await h.enrolled('Free', fbm: 202609, feeOverride: 0);
      expect((await h.report()).active.map((s) => s.name), ['Rahim']);

      await h.payments.waive(r.enrollment, ym(202611), reason: 'scholarship');

      expect(monthOf(await h.dues(r.enrollment), 202611).state, MonthState.waived);
      expect((await h.report()).active, isEmpty);
      final freeDues = await h.dues(free.enrollment);
      expect(freeDues.months.every((m) => m.state == MonthState.free), isTrue);
      expect(freeDues.totalOutstanding, 0);
    });
  });

  group('updateReceipt', () {
    test('re-validates without its own rows and keeps ids per month', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202609);
      final receiptId = await h.payments
          .record(h.draft(r.student, r.enrollment, {202609: 1000, 202610: 500}));
      final before = {for (final p in await h.payments.receipt(receiptId)) p.billingMonth: p};

      h.clock.tick();
      // Sep is fully paid by this receipt; validating with its own rows would
      // refuse Sep 1000 (remaining 0).
      await h.payments.updateReceipt(receiptId,
          h.draft(r.student, r.enrollment, {202609: 1000, 202610: 1000}));

      final rows = await h.allPaymentRows();
      expect(rows, hasLength(2));
      final sep = rows.firstWhere((x) => x.billingMonth == 202609);
      final oct = rows.firstWhere((x) => x.billingMonth == 202610);
      expect(sep.id, before[ym(202609)]!.id);
      expect(sep.rev, 1); // unchanged row is not rewritten
      expect(oct.id, before[ym(202610)]!.id);
      expect((oct.amount, oct.rev, oct.updatedAt), (1000, 2, h.stamper.nowMs()));
    });

    test('replaces months: dropped rows tombstoned, new rows same receipt',
        () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202609);
      final receiptId = await h.payments
          .record(h.draft(r.student, r.enrollment, {202609: 1000, 202610: 500}));
      h.clock.tick();

      await h.payments
          .updateReceipt(receiptId, h.draft(r.student, r.enrollment, {202611: 300}));

      final live = await h.payments.receipt(receiptId);
      expect([for (final p in live) (p.billingMonth, p.amount)],
          [(ym(202611), 300)]);
      final dead = (await h.allPaymentRows()).where((x) => x.deletedAt != null);
      expect(dead.map((x) => x.billingMonth).toSet(), {202609, 202610});
      for (final x in dead) {
        expect((x.rev, x.deletedAt), (2, h.stamper.nowMs()));
      }
      final dues = await h.dues(r.enrollment);
      expect(monthOf(dues, 202609).state, MonthState.unpaid);
      expect(monthOf(dues, 202611).paid, 300);
    });

    test('an invalid edit or a mid-way failure changes nothing', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202609);
      final other = await h.payments
          .record(h.draft(r.student, r.enrollment, {202610: 1000}));
      final receiptId = await h.payments
          .record(h.draft(r.student, r.enrollment, {202609: 1000}));
      final snapshot = await h.allPaymentRows();

      // Oct is fully paid by the other receipt.
      await expectLater(
          h.payments.updateReceipt(
              receiptId, h.draft(r.student, r.enrollment, {202610: 100})),
          throwsCode(ErrorCodes.allocationExceedsRemaining));

      await h.db.customStatement(
          'CREATE TRIGGER fail_nov BEFORE INSERT ON payments '
          'WHEN NEW.billing_month = 202611 '
          "BEGIN SELECT RAISE(ABORT, 'boom'); END");
      await expectLater(
          h.payments.updateReceipt(
              receiptId, h.draft(r.student, r.enrollment, {202611: 100})),
          throwsA(anything));

      expect(await h.allPaymentRows(), snapshot);
      expect(other, isNot(receiptId));
      await expectLater(
          h.payments.updateReceipt('missing', h.draft(r.student, r.enrollment, {202611: 1})),
          throwsA(isA<NotFoundException>()));
    });
  });

  group('deleteReceipt', () {
    test('tombstones every row; reads skip them; months reopen', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202610);
      final receiptId = await h.payments
          .record(h.draft(r.student, r.enrollment, {202610: 1000, 202611: 1000}));
      expect((await h.dues(r.enrollment)).totalOutstanding, 0);
      h.clock.tick();

      await h.payments.deleteReceipt(receiptId);

      final rows = await h.allPaymentRows();
      expect(rows, hasLength(2));
      for (final x in rows) {
        expect((x.deletedAt, x.rev, x.updatedAt, x.deviceId),
            (h.stamper.nowMs(), 2, h.stamper.nowMs(), dev));
      }
      expect(await h.payments.receipt(receiptId), isEmpty);
      expect(await h.payments.watchAll().first, isEmpty);
      expect(await h.payments.watchForStudent(r.student).first, isEmpty);
      expect(await h.payments.watchFacts().first, isEmpty);
      expect((await h.dues(r.enrollment)).totalOutstanding, 2000);
      await expectLater(h.payments.deleteReceipt(receiptId),
          throwsA(isA<NotFoundException>()));
    });
  });

  group('waivers', () {
    test('waive / re-waive / unwaive / waive again reuse the v5 id', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202610);
      final id = Ids.waiver(r.enrollment, ym(202611));

      await h.payments.waive(r.enrollment, ym(202611), reason: 'sick');
      var row = (await h.allPaymentRows()).single;
      expect((row.id, row.receiptId, row.amount, row.waived, row.note, row.rev),
          (id, id, 0, true, 'sick', 1));

      await h.payments.waive(r.enrollment, ym(202611), reason: 'sick'); // no-op
      expect((await h.allPaymentRows()).single.rev, 1);
      h.clock.tick();
      await h.payments.waive(r.enrollment, ym(202611), reason: 'poor');
      row = (await h.allPaymentRows()).single;
      expect((row.note, row.rev), ('poor', 2));

      h.clock.tick();
      await h.payments.unwaive(r.enrollment, ym(202611));
      row = (await h.allPaymentRows()).single;
      expect((row.deletedAt, row.rev), (h.stamper.nowMs(), 3));
      expect(monthOf(await h.dues(r.enrollment), 202611).state, MonthState.unpaid);
      await h.payments.unwaive(r.enrollment, ym(202611)); // idempotent

      h.clock.tick();
      await h.payments.waive(r.enrollment, ym(202611));
      row = (await h.allPaymentRows()).single;
      expect((row.deletedAt, row.rev, row.note), (null, 4, null));
      expect(monthOf(await h.dues(r.enrollment), 202611).state, MonthState.waived);
    });

    test('a waived month accepts no payment and is not a receipt', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202611);
      await h.payments.waive(r.enrollment, ym(202611));
      await expectLater(
          h.payments.record(h.draft(r.student, r.enrollment, {202611: 100})),
          throwsCode(ErrorCodes.allocationExceedsRemaining));
      final id = Ids.waiver(r.enrollment, ym(202611));
      expect(await h.payments.receipt(id), isEmpty);
      await expectLater(
          h.payments.deleteReceipt(id), throwsA(isA<NotFoundException>()));
      expect((await h.payments.watchFacts().first).single.waived, isTrue);
    });

    test('only billable months can be waived', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202611);
      await expectLater(h.payments.waive(r.enrollment, ym(202610)),
          throwsCode(ErrorCodes.dateInvalid));
      await h.enrollments.end(r.enrollment,
          on: d('2026-12-05'), lastBillableMonth: ym(202611));
      await expectLater(h.payments.waive(r.enrollment, ym(202612)),
          throwsCode(ErrorCodes.dateInvalid));
      await expectLater(h.payments.waive('nope', ym(202611)),
          throwsA(isA<AppException>()));
      expect(await h.allPaymentRows(), isEmpty);
    });
  });

  test('history reads: newest first, per student, tombstones skipped', () async {
    final h = PeopleHarness(today: '2026-11-10');
    await h.seedBatches();
    final a = await h.enrolled('Rahim', fbm: 202610);
    final b = await h.enrolled('Karim', fbm: 202610);
    await h.payments.record(h.draft(a.student, a.enrollment, {202610: 1000}));
    h.setToday('2026-11-12');
    final second = await h.payments
        .record(h.draft(a.student, a.enrollment, {202611: 1000}));
    await h.payments.record(h.draft(b.student, b.enrollment, {202610: 1000}));

    final all = await h.payments.watchAll().first;
    expect(all.first.paidOn, d('2026-11-12'));
    expect(all, hasLength(3));
    final mine = await h.payments.watchForStudent(a.student).first;
    expect([for (final p in mine) p.receiptId].first, second);
    expect(mine, hasLength(2));
    final facts = await h.payments.watchFacts().first;
    expect(facts.map((f) => f.amount), everyElement(1000));
  });
}
