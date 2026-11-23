// Schema v2 slip numbers (feedback item 2): `{year}-{seq:4}` per receipt,
// year of the payment date, allocated inside the save transaction, never
// reused; backfill numbers old receipts in payment-date order.

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/schema_v2.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/receipt_no.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'people_harness.dart';

PaymentDraft _draft(String student, String enrollment, int month, int amount, LocalDate paidOn) =>
    PaymentDraft(
      studentId: student,
      enrollmentId: enrollment,
      allocations: <Allocation>[Allocation(month: ym(month), amount: amount)],
      paidOn: paidOn,
      method: PaymentMethod.cash,
    );

Future<String?> _noOf(PeopleHarness h, String receiptId) async =>
    (await h.payments.receipt(receiptId)).first.receiptNo;

void main() {
  group('ReceiptNo', () {
    test('formats and parses', () {
      expect(ReceiptNo.format(2026, 7), '2026-0007');
      expect(ReceiptNo.format(2026, 12345), '2026-12345');
      expect(ReceiptNo.tryParse('2026-0007'), (2026, 7));
      expect(ReceiptNo.tryParse('2026-7'), isNull);
      expect(ReceiptNo.tryParse(null), isNull);
    });
  });

  group('record', () {
    test('numbers receipts one after another; every row of a receipt shares it', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202609);

      final a = await h.payments.record(h.draft(r.student, r.enrollment, {202609: 1000, 202610: 1000}));
      final b = await h.payments.record(h.draft(r.student, r.enrollment, {202611: 100}));

      final rowsA = await h.payments.receipt(a);
      expect(rowsA.map((Payment p) => p.receiptNo), <String>['2026-0001', '2026-0001']);
      expect(await _noOf(h, b), '2026-0002');
    });

    test('saves at the same time never share a number', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202611);

      final List<String> ids = await Future.wait(<Future<String>>[
        for (var i = 0; i < 6; i++) h.payments.record(h.draft(r.student, r.enrollment, {202611: 100})),
      ]);
      final Set<String?> numbers = <String?>{for (final String id in ids) await _noOf(h, id)};
      expect(numbers, <String>{for (var i = 1; i <= 6; i++) ReceiptNo.format(2026, i)});
    });

    test('a deleted receipt keeps its number; the next one moves on', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202611);
      await h.payments.record(h.draft(r.student, r.enrollment, {202611: 100}));
      final second = await h.payments.record(h.draft(r.student, r.enrollment, {202611: 100}));
      await h.payments.deleteReceipt(second);

      final third = await h.payments.record(h.draft(r.student, r.enrollment, {202611: 100}));
      expect(await _noOf(h, third), '2026-0003');
    });

    test('the year is the payment date year and restarts at 0001', () async {
      final h = PeopleHarness(today: '2026-12-31');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202611);
      final dec = await h.payments.record(h.draft(r.student, r.enrollment, {202611: 100}));
      expect(await _noOf(h, dec), '2026-0001');

      h.setToday('2027-01-01');
      final jan = await h.payments.record(h.draft(r.student, r.enrollment, {202611: 100}));
      expect(await _noOf(h, jan), '2027-0001');

      // Entered in 2027 but paid on 31 Dec 2026: a 2026 number.
      final backdated = await h.payments.record(_draft(r.student, r.enrollment, 202611, 100, d('2026-12-31')));
      expect(await _noOf(h, backdated), '2026-0002');
    });

    test('editing keeps the number, also on added months; waivers have none', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202609);
      final id = await h.payments.record(h.draft(r.student, r.enrollment, {202609: 1000}));

      await h.payments.updateReceipt(id, h.draft(r.student, r.enrollment, {202609: 1000, 202610: 500}));
      final rows = await h.payments.receipt(id);
      expect(rows, hasLength(2));
      expect(rows.map((Payment p) => p.receiptNo).toSet(), <String>{'2026-0001'});

      await h.payments.waive(r.enrollment, ym(202611));
      final waivers = (await h.allPaymentRows()).where((PaymentRow p) => p.waived);
      expect(waivers.single.receiptNo, isNull);
    });
  });

  group('backfill', () {
    Future<void> insertRaw(PeopleHarness h, String id, String receipt, String enrollment, String student,
        int month, String paidOn, {int at = 0, bool deleted = false}) {
      return h.db.into(h.db.payments).insert(paymentToCompanion(Payment(
            id: id,
            receiptId: receipt,
            studentId: student,
            enrollmentId: enrollment,
            batchId: batPhy,
            billingMonth: ym(month),
            amount: 100,
            paidOn: d(paidOn),
            method: PaymentMethod.cash,
          )).copyWith(
            createdAt: Value(1000 + at),
            updatedAt: Value(1000 + at),
            deviceId: const Value(dev),
            deletedAt: Value(deleted ? 2000 : null),
          ));
    }

    test('numbers unnumbered receipts by payment date, then recording time, continuing each year', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202601);
      // One receipt already numbered by the app.
      final numbered = await h.payments.record(_draft(r.student, r.enrollment, 202601, 100, d('2026-02-01')));

      await insertRaw(h, 'x3', 'R3', r.enrollment, r.student, 202603, '2026-03-10', at: 5);
      await insertRaw(h, 'x1', 'R1', r.enrollment, r.student, 202602, '2026-01-15', at: 9);
      await insertRaw(h, 'x2', 'R2', r.enrollment, r.student, 202602, '2026-03-10', at: 1);
      await insertRaw(h, 'x0', 'R0', r.enrollment, r.student, 202601, '2025-12-31');
      await insertRaw(h, 'xd', 'RD', r.enrollment, r.student, 202604, '2026-01-01', deleted: true);

      expect(await backfillReceiptNumbers(h.db), 4);
      final Map<String, String?> byId = <String, String?>{
        for (final PaymentRow p in await h.allPaymentRows()) p.id: p.receiptNo,
      };
      expect(await _noOf(h, numbered), '2026-0001');
      expect(byId['x0'], '2025-0001');
      expect(byId['x1'], '2026-0002');
      expect(byId['x2'], '2026-0003'); // 10 Mar, recorded before x3
      expect(byId['x3'], '2026-0004');
      expect(byId['xd'], isNull);

      // Idempotent.
      expect(await backfillReceiptNumbers(h.db), 0);
      final again = await h.payments.record(h.draft(r.student, r.enrollment, {202605: 100}));
      expect(await _noOf(h, again), '2026-0005');
    });

    test('numbers are never reused even when the rows that held them are gone', () async {
      final h = PeopleHarness(today: '2026-11-20');
      await h.seedBatches();
      final r = await h.enrolled('Rahim', fbm: 202611);
      await h.payments.record(h.draft(r.student, r.enrollment, {202611: 100}));
      await h.payments.record(h.draft(r.student, r.enrollment, {202611: 100}));
      // Restoring an older backup removes the rows for real.
      await h.db.customStatement('DELETE FROM payments');

      final next = await h.payments.record(h.draft(r.student, r.enrollment, {202611: 100}));
      expect(await _noOf(h, next), '2026-0003');
    });
  });
}
