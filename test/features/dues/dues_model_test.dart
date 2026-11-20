// Dues list model (M7-C): severity sort, filters, the grey group, partial and
// waive targets. Pure Dart, today = 2026-11-05 (a prepaid November fee is on
// day 5 = "follow up"; anything older is overdue).

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';

const LocalDate _today = LocalDate(2026, 11, 5);

EnrollmentTerms _terms(
  String student, {
  String? enrollment,
  String batch = 'b1',
  String batchName = 'Physics A',
  BillingType billing = BillingType.prepaid,
  YearMonth start = const YearMonth(2026, 9),
  int fee = 1000,
  bool left = false,
  bool archived = false,
}) =>
    EnrollmentTerms(
      enrollmentId: enrollment ?? 'e-$student-$batch',
      studentId: student,
      batchId: batch,
      studentName: student,
      batchName: batchName,
      subjectName: 'Subject',
      billing: billing,
      start: start,
      batchFees: <FeePeriod>[FeePeriod(effective: const YearMonth(2026, 1), amount: fee)],
      studentLeft: left,
      batchArchived: archived,
    );

PaymentFact _paid(String enrollment, YearMonth month, int amount) =>
    PaymentFact(enrollmentId: enrollment, month: month, amount: amount);

DuesReport _report(List<EnrollmentTerms> terms, [List<PaymentFact> facts = const <PaymentFact>[]]) =>
    DuesEngine.report(today: _today, terms: terms, payments: facts);

List<String> _ids(List<DuesRow> rows) => <String>[for (final DuesRow r in rows) r.studentId];

void main() {
  // A: Sep+Oct+Nov unpaid (overdue, 3 months)   B: Oct+Nov unpaid (overdue, 2)
  // C: Nov unpaid (day 5)   D: postpaid Oct unpaid (due 1 Nov, day 5, 800)
  // L: left student owes Oct   X: archived batch owes Oct
  final List<EnrollmentTerms> terms = <EnrollmentTerms>[
    _terms('A'),
    _terms('B', start: const YearMonth(2026, 10)),
    _terms('C', start: const YearMonth(2026, 11)),
    _terms('D', batch: 'b2', batchName: 'Chem B', billing: BillingType.postpaid, start: const YearMonth(2026, 10), fee: 800),
    _terms('L', left: true, start: const YearMonth(2026, 10)),
    _terms('X', batch: 'b3', batchName: 'Old', archived: true, start: const YearMonth(2026, 10)),
  ];
  final DuesReport report = _report(terms);

  test('active rows sort by level, open months, total, name', () {
    final DuesView v = buildDuesView(report, const DuesFilter(), _today);
    // A (OD, 3 months) > B (OD, 2) > C (level 3, 1000) > D (level 3, 800).
    expect(_ids(v.active), <String>['A', 'B', 'C', 'D']);
    expect(v.active.first.level, DueLevel.overdue);
    expect(v.active.first.monthCount, 3);
    expect(v.active.first.total, 3000);
    expect(v.active[2].level, DueLevel.followUp);
    expect(v.active[2].dayInDue, 5);
    expect(v.active.first.dayInDue, isNull, reason: 'overdue has no day count');
  });

  test('left and archived dues go to the grey group with no severity', () {
    final DuesView v = buildDuesView(report, const DuesFilter(), _today);
    expect(_ids(v.inactive), <String>['L', 'X']);
    for (final DuesRow r in v.inactive) {
      expect(r.inactive, isTrue);
      expect(r.level, isNull);
      expect(r.dayInDue, isNull);
    }
    expect(v.inactive.first.reason, InactiveReason.left);
    expect(v.inactive.last.reason, InactiveReason.archived);
    expect(v.ofLevel(DueLevel.overdue).map((DuesRow r) => r.studentId), <String>['A', 'B']);
  });

  test('overdue filter keeps only overdue students and drops the grey group', () {
    final DuesView v = buildDuesView(report, const DuesFilter(scope: DuesScope.overdue), _today);
    expect(_ids(v.active), <String>['A', 'B']);
    expect(v.inactive, isEmpty);
  });

  test('this-month filter keeps students whose current month is open', () {
    final DuesView v = buildDuesView(report, const DuesFilter(scope: DuesScope.thisMonth), _today);
    expect(_ids(v.active), <String>['A', 'B', 'C']);
    // Only the November part counts: A owes 1000 of 3000, and November itself
    // is on day 5, not overdue.
    final DuesRow a = v.active.first;
    expect(a.total, 1000);
    expect(a.level, DueLevel.followUp);
    expect(a.months, <YearMonth>[const YearMonth(2026, 11)]);
  });

  test('month filter (from the collection summary) lists that month only', () {
    final DuesView v = buildDuesView(
      report,
      DuesFilter(month: const YearMonth(2026, 10)),
      _today,
    );
    expect(_ids(v.active), <String>['A', 'B', 'D']);
    expect(_ids(v.inactive), <String>['L', 'X']);
    expect(v.active.first.total, 1000);
  });

  test('batch filter keeps one batch and its amount', () {
    final DuesView v = buildDuesView(report, const DuesFilter(batchId: 'b2'), _today);
    expect(_ids(v.active), <String>['D']);
    expect(v.active.single.batchNames, <String>['Chem B']);
    expect(v.inactive, isEmpty);
  });

  test('a filter that matches nobody gives an empty view', () {
    final DuesView v = buildDuesView(report, const DuesFilter(batchId: 'nope'), _today);
    expect(v.isEmpty, isTrue);
  });

  test('a partly paid month shows its remainder and is the waive target', () {
    final DuesReport r = _report(
      <EnrollmentTerms>[_terms('P', start: const YearMonth(2026, 11))],
      <PaymentFact>[_paid('e-P-b1', const YearMonth(2026, 11), 600)],
    );
    final DuesRow row = buildDuesView(r, const DuesFilter(), _today).active.single;
    expect(row.total, 400);
    expect(row.partialRemaining, 400);
    expect(row.level, DueLevel.followUp, reason: 'a partial payment does not reset the level');
    expect(row.waiveEnrollmentId, 'e-P-b1');
    expect(row.waiveMonth, const YearMonth(2026, 11));
  });

  test('several open months have no single waive target', () {
    final DuesRow row = buildDuesView(report, const DuesFilter(), _today).active.first;
    expect(row.waiveEnrollmentId, isNull);
    expect(row.partialRemaining, isNull);
  });

  test('a student in two batches is one row with both batch names', () {
    final DuesReport r = _report(<EnrollmentTerms>[
      _terms('S', start: const YearMonth(2026, 11)),
      _terms('S', batch: 'b2', batchName: 'Chem B', billing: BillingType.postpaid, start: const YearMonth(2026, 10), fee: 800),
    ]);
    final DuesView v = buildDuesView(r, const DuesFilter(), _today);
    expect(v.active, hasLength(1));
    expect(v.active.single.batchNames, <String>['Chem B', 'Physics A']);
    expect(v.active.single.total, 1800);
    expect(v.active.single.months, <YearMonth>[const YearMonth(2026, 10), const YearMonth(2026, 11)]);
  });

  test('escalation day is the day of month inside the first ten days only', () {
    expect(escalationDay(const LocalDate(2026, 11, 5)), 5);
    expect(escalationDay(const LocalDate(2026, 11, 10)), 10);
    expect(escalationDay(const LocalDate(2026, 11, 11)), isNull);
  });
}
