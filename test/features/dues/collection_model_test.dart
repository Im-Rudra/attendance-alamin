// Monthly collection summary (Product 3.7): billing-month block per batch and
// in total, waived months, cash in by method and other income, receipts.
// Seed: Rahim owes Nov, Sara paid Nov of Physics A (bKash, 2 Nov) and owes
// Chem B's Oct, Nila and Karim owe Nov (Karim's is not due yet).

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/widgets/batch_fees_tab.dart';

import '../../helpers/fixtures.dart';

const YearMonth _nov = YearMonth(2026, 11);
const YearMonth _oct = YearMonth(2026, 10);

List<PaymentFact> _facts(List<Payment> payments, [List<PaymentFact> extra = const <PaymentFact>[]]) =>
    <PaymentFact>[
      for (final Payment p in payments)
        PaymentFact(enrollmentId: p.enrollmentId, month: p.billingMonth, amount: p.amount, waived: p.waived),
      ...extra,
    ];

CollectionSummary _summary(
  YearMonth month, {
  List<PaymentFact> extraFacts = const <PaymentFact>[],
  List<OtherIncome> other = const <OtherIncome>[],
}) =>
    buildCollectionSummary(
      month: month,
      today: kToday,
      terms: termsFor(kEnrollments),
      facts: _facts(kPayments, extraFacts),
      payments: kPayments,
      otherIncome: other,
    );

BatchMonthSummary _batch(CollectionSummary s, String id) =>
    s.batches.firstWhere((BatchMonthSummary b) => b.batchId == id);

void main() {
  test('billing block: expected, received and outstanding per batch and in total', () {
    final CollectionSummary s = _summary(_nov);
    final MonthTotals phys = _batch(s, kBatPhysA).totals;
    // Rahim 1000 unpaid, Sara 1000 paid, Nila 1000 unpaid.
    expect(phys.expected, 3000);
    expect(phys.received, 1000);
    expect(phys.outstanding, 2000);
    expect(phys.paidStudents, 1);
    expect(phys.totalStudents, 3);
    final MonthTotals chem = _batch(s, kBatChemB).totals;
    // Karim 800 and Sara 800: nothing paid.
    expect(chem.expected, 1600);
    expect(chem.received, 0);
    expect(chem.outstanding, 1600);
    expect(s.totals.expected, 4600);
    expect(s.totals.received, 1000);
    expect(s.totals.outstanding, 3600);
    // Sara paid Physics A but not Chem B: she has not paid in full.
    expect(s.totals.totalStudents, 4);
    expect(s.totals.paidStudents, 0);
  });

  test('a waived month is counted as waived, not expected', () {
    final CollectionSummary s = _summary(
      _nov,
      extraFacts: <PaymentFact>[
        PaymentFact(enrollmentId: kEnrNilaPhys, month: _nov, amount: 0, waived: true),
      ],
    );
    final MonthTotals phys = _batch(s, kBatPhysA).totals;
    expect(phys.expected, 2000);
    expect(phys.outstanding, 1000);
    expect(phys.waivedCount, 1);
    expect(phys.waivedAmount, 1000);
    expect(phys.totalStudents, 2, reason: 'a waived month is not a fee to collect');
    expect(s.totals.waivedCount, 1);
  });

  test('an earlier month and a month with no enrollment', () {
    final CollectionSummary oct = _summary(_oct);
    // Rahim and Sara paid Oct of Physics A; Sara owes Oct of Chem B (800).
    expect(oct.totals.expected, 1000 + 1000 + 800);
    expect(oct.totals.received, 2000);
    expect(oct.totals.outstanding, 800);
    final CollectionSummary none = _summary(const YearMonth(2025, 1));
    expect(none.totals.expected, 0);
    expect(none.batches, isEmpty);
  });

  test('cash in counts payments by their payment date, by method', () {
    final CollectionSummary nov = _summary(_nov);
    expect(nov.feesCash, 1000);
    expect(nov.byMethod.map((MethodTotal m) => m.method.code), <String>['bkash']);
    expect(nov.otherIncome, 0);
    expect(nov.cashTotal, 1000);
    expect(nov.receipts, hasLength(1));
    expect(nov.receipts.single.studentId, kStuSara);
    expect(nov.receipts.single.months, <YearMonth>[_nov]);

    final CollectionSummary oct = _summary(_oct);
    expect(oct.feesCash, 2000);
    // Equal amounts sort by method code: bkash before cash.
    expect(oct.byMethod.map((MethodTotal m) => m.method.code), <String>['bkash', 'cash']);
    expect(oct.receipts.map((ReceiptLine r) => r.studentId), <String>[kStuRahim, kStuSara],
        reason: 'newest payment first');
  });

  test('other income is a separate line and adds to the cash total', () {
    final CollectionSummary s = _summary(
      _nov,
      other: <OtherIncome>[
        const OtherIncome(
          id: 'o1',
          label: 'Exam fee',
          amount: 500,
          paidOn: LocalDate(2026, 11, 10),
          method: PaymentMethod.cash,
        ),
        const OtherIncome(
          id: 'o2',
          label: 'Book',
          amount: 300,
          paidOn: LocalDate(2026, 10, 30),
          method: PaymentMethod.cash,
        ),
      ],
    );
    expect(s.otherIncome, 500, reason: 'only the one paid in November');
    expect(s.cashTotal, 1500);
  });

  test('one receipt over several months is one line with the summed amount', () {
    final List<Payment> two = <Payment>[
      Payment(
        id: 'p1',
        receiptId: 'r1',
        studentId: kStuRahim,
        enrollmentId: kEnrRahimPhys,
        batchId: kBatPhysA,
        billingMonth: _oct,
        amount: 1000,
        paidOn: const LocalDate(2026, 11, 3),
        method: PaymentMethod.cash,
      ),
      Payment(
        id: 'p2',
        receiptId: 'r1',
        studentId: kStuRahim,
        enrollmentId: kEnrRahimPhys,
        batchId: kBatPhysA,
        billingMonth: _nov,
        amount: 500,
        paidOn: const LocalDate(2026, 11, 3),
        method: PaymentMethod.cash,
      ),
    ];
    final CollectionSummary s = buildCollectionSummary(
      month: _nov,
      today: kToday,
      terms: termsFor(kEnrollments),
      facts: _facts(two),
      payments: two,
      otherIncome: const <OtherIncome>[],
    );
    expect(s.receipts, hasLength(1));
    expect(s.receipts.single.amount, 1500);
    expect(s.receipts.single.months, <YearMonth>[_oct, _nov]);
    expect(s.feesCash, 1500);
  });

  test('batch tab rows: open due months first, then paid', () {
    final List<LedgerLine> lines = buildLedger(
      terms: termsFor(kEnrollments),
      facts: _facts(kPayments),
      today: kToday,
      month: _nov,
      batchId: kBatPhysA,
    );
    expect(lines, hasLength(3));
    final List<LedgerLine> sorted = sortLedger(lines);
    expect(sorted.last.terms.studentId, kStuSara, reason: 'paid sorts last');
    expect(sorted.first.due.isOpen, isTrue);
    expect(sorted.first.due.level, DueLevel.overdue);
    expect(sorted[1].due.isOpen, isTrue);
  });
}
