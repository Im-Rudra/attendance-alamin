// Per-place month totals (schema v2, feedback item 3): Physics A stays at the
// default place, Chem B moves to a second centre. Each place sees only its
// batches' dues and fees and its own other income; general income is apart.

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';

import '../../helpers/fixtures.dart';

const YearMonth _nov = YearMonth(2026, 11);
const String _second = 'place-2';

EnrollmentTerms _at(EnrollmentTerms t, String placeId) => EnrollmentTerms(
      enrollmentId: t.enrollmentId,
      studentId: t.studentId,
      batchId: t.batchId,
      studentName: t.studentName,
      batchName: t.batchName,
      subjectName: t.subjectName,
      billing: t.billing,
      start: t.start,
      end: t.end,
      batchFees: t.batchFees,
      overrides: t.overrides,
      batchArchived: t.batchArchived,
      studentLeft: t.studentLeft,
      enrollmentEnded: t.enrollmentEnded,
      placeId: placeId,
    );

List<EnrollmentTerms> _terms() => <EnrollmentTerms>[
      for (final EnrollmentTerms t in termsFor(kEnrollments)) t.batchId == kBatChemB ? _at(t, _second) : t,
    ];

List<PaymentFact> _facts() => <PaymentFact>[
      for (final Payment p in kPayments)
        PaymentFact(enrollmentId: p.enrollmentId, month: p.billingMonth, amount: p.amount, waived: p.waived),
    ];

OtherIncome _income(String id, int amount, String? placeId) => OtherIncome(
      id: id,
      label: 'Exam fee',
      amount: amount,
      paidOn: const LocalDate(2026, 11, 5),
      method: PaymentMethod.cash,
      placeId: placeId,
    );

final List<OtherIncome> _other = <OtherIncome>[
  _income('o1', 200, kDefaultPlaceId),
  _income('o2', 300, _second),
  _income('o3', 50, null),
];

void main() {
  test('terms default to the default place', () {
    expect(termsFor(kEnrollments).every((EnrollmentTerms t) => t.placeId == kDefaultPlaceId), isTrue);
  });

  test('each place sees only its own batches and income', () {
    final CollectionSummary home = buildPlaceCollectionSummary(
      placeId: kDefaultPlaceId,
      month: _nov,
      today: kToday,
      terms: _terms(),
      facts: _facts(),
      payments: kPayments,
      otherIncome: _other,
    );
    expect(home.batches.map((BatchMonthSummary b) => b.batchId), <String>[kBatPhysA]);
    expect(home.otherIncome, 200);

    final CollectionSummary second = buildPlaceCollectionSummary(
      placeId: _second,
      month: _nov,
      today: kToday,
      terms: _terms(),
      facts: _facts(),
      payments: kPayments,
      otherIncome: _other,
    );
    expect(second.batches.map((BatchMonthSummary b) => b.batchId), <String>[kBatChemB]);
    expect(second.otherIncome, 300);
    for (final ReceiptLine r in second.receipts) {
      expect(kPayments.firstWhere((Payment p) => p.receiptId == r.receiptId).batchId, kBatChemB);
    }
  });

  test('the places add up to the whole month; general income is kept apart', () {
    final CollectionSummary all = buildCollectionSummary(
      month: _nov,
      today: kToday,
      terms: _terms(),
      facts: _facts(),
      payments: kPayments,
      otherIncome: _other,
    );
    final PlacesMonthBreakdown split = buildPlacesMonthBreakdown(
      placeIds: <String>[kDefaultPlaceId, _second],
      month: _nov,
      today: kToday,
      terms: _terms(),
      facts: _facts(),
      payments: kPayments,
      otherIncome: _other,
    );
    expect(split.places.map((PlaceMonthSummary p) => p.placeId), <String>[kDefaultPlaceId, _second]);
    int sum(int Function(PlaceMonthSummary p) f) => split.places.fold(0, (int s, PlaceMonthSummary p) => s + f(p));
    expect(sum((PlaceMonthSummary p) => p.collected), all.feesCash);
    expect(sum((PlaceMonthSummary p) => p.dues), all.totals.outstanding);
    expect(sum((PlaceMonthSummary p) => p.otherIncome) + split.generalOtherIncome, all.otherIncome);
    expect(split.generalOtherIncome, 50);
  });

  test('with one place the breakdown equals the plain summary', () {
    final CollectionSummary all = buildCollectionSummary(
      month: _nov,
      today: kToday,
      terms: termsFor(kEnrollments),
      facts: _facts(),
      payments: kPayments,
      otherIncome: const <OtherIncome>[],
    );
    final PlacesMonthBreakdown split = buildPlacesMonthBreakdown(
      placeIds: const <String>[kDefaultPlaceId],
      month: _nov,
      today: kToday,
      terms: termsFor(kEnrollments),
      facts: _facts(),
      payments: kPayments,
      otherIncome: const <OtherIncome>[],
    );
    final PlaceMonthSummary only = split.places.single;
    expect(only.collected, all.feesCash);
    expect(only.dues, all.totals.outstanding);
    expect(only.summary.totals.expected, all.totals.expected);
    expect(only.summary.receipts.length, all.receipts.length);
  });
}
