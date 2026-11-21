import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:flutter_test/flutter_test.dart';

// Product 6 seed: Physics A (prepaid, 1000), Chem B (postpaid, 800).
const physicsFees = <FeePeriod>[
  FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
];
const chemFees = <FeePeriod>[
  FeePeriod(effective: YearMonth(2026, 1), amount: 800),
];

YearMonth ym(int y, int m) => YearMonth(y, m);
LocalDate d(int y, int m, int day) => LocalDate(y, m, day);

EnrollmentTerms physics({
  String id = 'e-rahim-phy',
  String studentId = 's-rahim',
  String name = 'Rahim',
  YearMonth start = const YearMonth(2026, 9),
  YearMonth? end,
  List<FeePeriod> fees = physicsFees,
  List<FeePeriod> overrides = const <FeePeriod>[],
  bool archived = false,
  bool left = false,
  bool ended = false,
}) =>
    EnrollmentTerms(
      enrollmentId: id,
      studentId: studentId,
      batchId: 'b-phy',
      studentName: name,
      batchName: 'Physics A',
      subjectName: 'Physics',
      billing: BillingType.prepaid,
      start: start,
      end: end,
      batchFees: fees,
      overrides: overrides,
      batchArchived: archived,
      studentLeft: left,
      enrollmentEnded: ended,
    );

EnrollmentTerms chem({
  String id = 'e-karim-chem',
  String studentId = 's-karim',
  String name = 'Karim',
  YearMonth start = const YearMonth(2026, 11),
  YearMonth? end,
  List<FeePeriod> fees = chemFees,
  List<FeePeriod> overrides = const <FeePeriod>[],
  bool archived = false,
  bool left = false,
  bool ended = false,
}) =>
    EnrollmentTerms(
      enrollmentId: id,
      studentId: studentId,
      batchId: 'b-chem',
      studentName: name,
      batchName: 'Chem B',
      subjectName: 'Chemistry',
      billing: BillingType.postpaid,
      start: start,
      end: end,
      batchFees: fees,
      overrides: overrides,
      batchArchived: archived,
      studentLeft: left,
      enrollmentEnded: ended,
    );

PaymentFact pay(String enrollmentId, YearMonth m, int amount) =>
    PaymentFact(enrollmentId: enrollmentId, month: m, amount: amount);

PaymentFact waive(String enrollmentId, YearMonth m) =>
    PaymentFact(enrollmentId: enrollmentId, month: m, amount: 0, waived: true);

EnrollmentDues duesOf(
  EnrollmentTerms t,
  LocalDate today, [
  List<PaymentFact> payments = const <PaymentFact>[],
]) =>
    DuesEngine.forEnrollment(terms: t, payments: payments, today: today);

MonthDue monthOf(EnrollmentDues dues, YearMonth m) =>
    dues.months.firstWhere((x) => x.month == m);

Matcher throwsCode(String code) => throwsA(
      isA<ValidationException>().having((e) => e.code, 'code', code),
    );

List<PaymentFact> applyAllocations(
  String enrollmentId,
  List<Allocation> allocations,
) =>
    [for (final a in allocations) pay(enrollmentId, a.month, a.amount)];

void main() {
  // ---------------------------------------------------------------------------
  group('dueDate (Product 3.0)', () {
    final cases = <({BillingType b, YearMonth m, LocalDate due})>[
      (b: BillingType.prepaid, m: ym(2026, 11), due: d(2026, 11, 1)),
      (b: BillingType.postpaid, m: ym(2026, 11), due: d(2026, 12, 1)),
      (b: BillingType.prepaid, m: ym(2026, 12), due: d(2026, 12, 1)),
      (b: BillingType.postpaid, m: ym(2026, 12), due: d(2027, 1, 1)),
      (b: BillingType.postpaid, m: ym(2028, 1), due: d(2028, 2, 1)),
      (b: BillingType.postpaid, m: ym(2028, 2), due: d(2028, 3, 1)),
      (b: BillingType.prepaid, m: ym(2028, 2), due: d(2028, 2, 1)),
    ];
    for (final c in cases) {
      test('${c.b.name} ${c.m} is due ${c.due}', () {
        expect(DuesEngine.dueDate(c.b, c.m), c.due);
      });
    }
  });

  // ---------------------------------------------------------------------------
  group('feeFor (Product 3.1, plan 1 #10)', () {
    const raised = <FeePeriod>[
      FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
      FeePeriod(effective: YearMonth(2026, 12), amount: 1200),
    ];
    const override800 = <FeePeriod>[
      FeePeriod(effective: YearMonth(2026, 10), amount: 800),
    ];
    const override800Late = <FeePeriod>[
      FeePeriod(effective: YearMonth(2026, 12), amount: 800),
    ];
    const override800Cleared = <FeePeriod>[
      FeePeriod(effective: YearMonth(2026, 10), amount: 800),
      FeePeriod(effective: YearMonth(2027, 2)),
    ];
    final cases = <({
      String label,
      EnrollmentTerms t,
      YearMonth m,
      int fee,
      bool missing,
    })>[
      (
        label: 'batch fee before raise',
        t: physics(fees: raised),
        m: ym(2026, 11),
        fee: 1000,
        missing: false,
      ),
      (
        label: 'batch fee from raise month',
        t: physics(fees: raised),
        m: ym(2026, 12),
        fee: 1200,
        missing: false,
      ),
      (
        label: 'batch fee after raise month',
        t: physics(fees: raised),
        m: ym(2027, 1),
        fee: 1200,
        missing: false,
      ),
      (
        label: 'override wins from its month',
        t: physics(fees: raised, overrides: override800),
        m: ym(2026, 11),
        fee: 800,
        missing: false,
      ),
      (
        label: 'override survives a batch raise',
        t: physics(fees: raised, overrides: override800),
        m: ym(2026, 12),
        fee: 800,
        missing: false,
      ),
      (
        label: 'months before the override keep the batch fee',
        t: physics(fees: raised, overrides: override800),
        m: ym(2026, 9),
        fee: 1000,
        missing: false,
      ),
      (
        label: 'override still in effect before it is cleared',
        t: physics(fees: raised, overrides: override800Cleared),
        m: ym(2027, 1),
        fee: 800,
        missing: false,
      ),
      (
        label: 'cleared override falls back to the batch fee',
        t: physics(fees: raised, overrides: override800Cleared),
        m: ym(2027, 2),
        fee: 1200,
        missing: false,
      ),
      (
        label: 'override 0 = free',
        t: physics(overrides: const [
          FeePeriod(effective: YearMonth(2026, 11), amount: 0),
        ]),
        m: ym(2026, 11),
        fee: 0,
        missing: false,
      ),
      (
        label: 'no batch fee at all',
        t: physics(fees: const <FeePeriod>[]),
        m: ym(2026, 11),
        fee: 0,
        missing: true,
      ),
      (
        label: 'QA-01: earliest batch fee applies backwards',
        t: physics(fees: const [
          FeePeriod(effective: YearMonth(2026, 12), amount: 1000),
        ]),
        m: ym(2026, 11),
        fee: 1000,
        missing: false,
      ),
      (
        label: 'QA-01: backwards uses the earliest record, not a later raise',
        t: physics(fees: const [
          FeePeriod(effective: YearMonth(2027, 1), amount: 1200),
          FeePeriod(effective: YearMonth(2026, 11), amount: 1000),
        ]),
        m: ym(2026, 9),
        fee: 1000,
        missing: false,
      ),
      (
        label: 'QA-01: earliest override applies backwards',
        t: physics(fees: const [
          FeePeriod(effective: YearMonth(2026, 11), amount: 1000),
        ], overrides: const [
          FeePeriod(effective: YearMonth(2026, 11), amount: 700),
        ]),
        m: ym(2026, 9),
        fee: 700,
        missing: false,
      ),
      (
        label: 'QA-01: a later override does not reach back over the batch fee',
        t: physics(fees: const [
          FeePeriod(effective: YearMonth(2026, 11), amount: 1000),
        ], overrides: override800Late),
        m: ym(2026, 9),
        fee: 1000,
        missing: false,
      ),
      (
        label: 'QA-01: cleared override before the first batch fee',
        t: physics(fees: const [
          FeePeriod(effective: YearMonth(2026, 12), amount: 1000),
        ], overrides: const [
          FeePeriod(effective: YearMonth(2026, 9), amount: 500),
          FeePeriod(effective: YearMonth(2026, 10)),
        ]),
        m: ym(2026, 10),
        fee: 1000,
        missing: false,
      ),
      (
        label: 'override without any batch fee',
        t: physics(fees: const <FeePeriod>[], overrides: override800),
        m: ym(2026, 11),
        fee: 800,
        missing: false,
      ),
      (
        label: 'history order does not matter',
        t: physics(fees: const [
          FeePeriod(effective: YearMonth(2026, 12), amount: 1200),
          FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
        ]),
        m: ym(2026, 11),
        fee: 1000,
        missing: false,
      ),
      (
        label: 'same effective month: later entry wins',
        t: physics(fees: const [
          FeePeriod(effective: YearMonth(2026, 11), amount: 1000),
          FeePeriod(effective: YearMonth(2026, 11), amount: 1100),
        ]),
        m: ym(2026, 11),
        fee: 1100,
        missing: false,
      ),
    ];
    for (final c in cases) {
      test(c.label, () {
        final r = DuesEngine.feeFor(c.t, c.m);
        expect(r.fee, c.fee);
        expect(r.missing, c.missing);
      });
    }
  });

  // ---------------------------------------------------------------------------
  group('Scenario 1: prepaid escalation', () {
    final t = physics(start: ym(2026, 10));
    final payments = [pay(t.enrollmentId, ym(2026, 10), 1000)];
    final cases = <({LocalDate today, DueLevel level, int? day})>[
      (today: d(2026, 11, 1), level: DueLevel.justDue, day: 1),
      (today: d(2026, 11, 3), level: DueLevel.remind, day: 3),
      (today: d(2026, 11, 5), level: DueLevel.followUp, day: 5),
      (today: d(2026, 11, 7), level: DueLevel.urgent, day: 7),
      (today: d(2026, 11, 9), level: DueLevel.finalDays, day: 9),
      (today: d(2026, 11, 11), level: DueLevel.overdue, day: null),
    ];
    for (final c in cases) {
      test('${c.today} -> ${c.level.name}', () {
        final dues = duesOf(t, c.today, payments);
        final nov = monthOf(dues, ym(2026, 11));
        expect(nov.state, MonthState.unpaid);
        expect(nov.isDue, isTrue);
        expect(nov.level, c.level);
        expect(nov.dayInDue, c.day);
        expect(dues.openDue.map((m) => m.month), [ym(2026, 11)]);
        expect(dues.worst, c.level);
        expect(dues.worstDay, c.day);
        expect(dues.totalOutstanding, 1000);
        expect(dues.oldestOpenDue, ym(2026, 11));
        expect(monthOf(dues, ym(2026, 10)).state, MonthState.paid);
        expect(monthOf(dues, ym(2026, 10)).level, isNull);
      });
    }

    test('every day of November follows the 1-2/3-4/5-6/7-8/9-10/11+ bands',
        () {
      for (var day = 1; day <= 30; day++) {
        final nov =
            monthOf(duesOf(t, d(2026, 11, day), payments), ym(2026, 11));
        expect(nov.level, DueLevel.forDay(day), reason: 'day $day');
        expect(nov.dayInDue, day <= 10 ? day : null, reason: 'day $day');
      }
    });

    test('31 Oct: November is upcoming, not a warning', () {
      final dues = duesOf(t, d(2026, 10, 31), payments);
      final nov = monthOf(dues, ym(2026, 11));
      expect(nov.isDue, isFalse);
      expect(nov.level, DueLevel.upcoming);
      expect(nov.dayInDue, isNull);
      expect(dues.openDue, isEmpty);
      expect(dues.worst, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('1st / 10th / 11th / last day (Arch 4)', () {
    final pre = physics(start: ym(2026, 11));
    final post = chem(start: ym(2026, 11));
    final cases = <({
      EnrollmentTerms t,
      LocalDate today,
      DueLevel level,
      int? day,
      bool isDue,
    })>[
      (t: pre, today: d(2026, 11, 1), level: DueLevel.justDue, day: 1, isDue: true),
      (t: pre, today: d(2026, 11, 10), level: DueLevel.finalDays, day: 10, isDue: true),
      (t: pre, today: d(2026, 11, 11), level: DueLevel.overdue, day: null, isDue: true),
      (t: pre, today: d(2026, 11, 30), level: DueLevel.overdue, day: null, isDue: true),
      (t: post, today: d(2026, 11, 30), level: DueLevel.upcoming, day: null, isDue: false),
      (t: post, today: d(2026, 12, 1), level: DueLevel.justDue, day: 1, isDue: true),
      (t: post, today: d(2026, 12, 10), level: DueLevel.finalDays, day: 10, isDue: true),
      (t: post, today: d(2026, 12, 11), level: DueLevel.overdue, day: null, isDue: true),
      (t: post, today: d(2026, 12, 31), level: DueLevel.overdue, day: null, isDue: true),
    ];
    for (final c in cases) {
      test('${c.t.billing.name} Nov on ${c.today}', () {
        final nov = monthOf(duesOf(c.t, c.today), ym(2026, 11));
        expect(nov.isDue, c.isDue);
        expect(nov.level, c.level);
        expect(nov.dayInDue, c.day);
      });
    }
  });

  // ---------------------------------------------------------------------------
  group('Scenario 2: postpaid timing', () {
    final karim = chem(start: ym(2026, 11));

    test('20 Nov: no warning, Nov upcoming with due date 1 Dec', () {
      final dues = duesOf(karim, d(2026, 11, 20));
      final nov = monthOf(dues, ym(2026, 11));
      expect(nov.state, MonthState.unpaid);
      expect(nov.fee, 800);
      expect(nov.remaining, 800);
      expect(nov.dueDate, d(2026, 12, 1));
      expect(nov.isDue, isFalse);
      expect(nov.level, DueLevel.upcoming);
      expect(dues.openDue, isEmpty);
      expect(dues.worst, isNull);
      expect(dues.totalOutstanding, 0);
      final report = DuesEngine.report(
          today: d(2026, 11, 20), terms: [karim], payments: const []);
      expect(report.active, isEmpty);
      expect(report.studentsWithDues, 0);
    });

    test('5 Dec: Nov is level 3, Dec is upcoming (due 1 Jan)', () {
      final dues = duesOf(karim, d(2026, 12, 5));
      final nov = monthOf(dues, ym(2026, 11));
      expect(nov.level, DueLevel.followUp);
      expect(nov.dayInDue, 5);
      final dec = monthOf(dues, ym(2026, 12));
      expect(dec.dueDate, d(2027, 1, 1));
      expect(dec.level, DueLevel.upcoming);
      expect(dues.worst, DueLevel.followUp);
      expect(dues.worstDay, 5);
      expect(dues.totalOutstanding, 800);
    });
  });

  // ---------------------------------------------------------------------------
  group('Scenario 3: multi-month', () {
    final rahim = physics(start: ym(2026, 9));
    final sara = physics(
        id: 'e-sara-phy', studentId: 's-sara', name: 'Sara', start: ym(2026, 11));
    final today = d(2026, 11, 2);

    test('Sep, Oct, Nov unpaid on 2 Nov -> OD, 3 months, 3000, since Sep', () {
      final dues = duesOf(rahim, today);
      expect(dues.openDue.map((m) => m.month),
          [ym(2026, 9), ym(2026, 10), ym(2026, 11)]);
      expect(monthOf(dues, ym(2026, 9)).level, DueLevel.overdue);
      expect(monthOf(dues, ym(2026, 10)).level, DueLevel.overdue);
      expect(monthOf(dues, ym(2026, 11)).level, DueLevel.justDue);
      expect(monthOf(dues, ym(2026, 11)).dayInDue, 2);
      expect(dues.worst, DueLevel.overdue);
      expect(dues.worstDay, isNull);
      expect(dues.totalOutstanding, 3000);
      expect(dues.oldestOpenDue, ym(2026, 9));
    });

    test('report: Rahim sorts above a level-1 student', () {
      final report = DuesEngine.report(
          today: today, terms: [sara, rahim], payments: const []);
      expect(report.active.map((s) => s.name), ['Rahim', 'Sara']);
      final r = report.active.first;
      expect(r.worst, DueLevel.overdue);
      expect(r.openDueMonths, 3);
      expect(r.totalOutstanding, 3000);
      expect(r.oldestOpenDue, ym(2026, 9));
      expect(r.openMonths, [ym(2026, 9), ym(2026, 10), ym(2026, 11)]);
      expect(report.active[1].worst, DueLevel.justDue);
      expect(report.active[1].worstDay, 2);
      expect(report.countByLevel[DueLevel.overdue], 1);
      expect(report.countByLevel[DueLevel.justDue], 1);
      expect(report.countByLevel[DueLevel.followUp], 0);
      expect(report.overdueStudents, 1);
      expect(report.studentsWithDues, 2);
      expect(report.totalOutstandingActive, 4000);
    });
  });

  // ---------------------------------------------------------------------------
  group('Scenario 4: partial', () {
    final rahim = physics(start: ym(2026, 11));
    final today = d(2026, 11, 4);

    test('600 of 1000 on 4 Nov -> partial, 400 remaining, still level 2', () {
      final dues = duesOf(rahim, today, [pay(rahim.enrollmentId, ym(2026, 11), 600)]);
      expect(
        monthOf(dues, ym(2026, 11)),
        MonthDue(
          month: ym(2026, 11),
          fee: 1000,
          feeMissing: false,
          paid: 600,
          remaining: 400,
          state: MonthState.partial,
          dueDate: d(2026, 11, 1),
          isDue: true,
          level: DueLevel.remind,
          dayInDue: 4,
        ),
      );
      expect(dues.worst, DueLevel.remind);
      expect(dues.totalOutstanding, 400);
    });

    test('400 more -> paid and gone from the dues list', () {
      final payments = [
        pay(rahim.enrollmentId, ym(2026, 11), 600),
        pay(rahim.enrollmentId, ym(2026, 11), 400),
      ];
      final nov = monthOf(duesOf(rahim, today, payments), ym(2026, 11));
      expect(nov.state, MonthState.paid);
      expect(nov.remaining, 0);
      expect(nov.level, isNull);
      expect(nov.dayInDue, isNull);
      final report =
          DuesEngine.report(today: today, terms: [rahim], payments: payments);
      expect(report.active, isEmpty);
      expect(report.inactive, isEmpty);
    });

    test('partial counts as unpaid for warnings (day 7 -> urgent)', () {
      final dues = duesOf(
          rahim, d(2026, 11, 7), [pay(rahim.enrollmentId, ym(2026, 11), 999)]);
      expect(dues.openDue.single.state, MonthState.partial);
      expect(dues.worst, DueLevel.urgent);
      expect(dues.worstDay, 7);
      expect(dues.totalOutstanding, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('Scenario 5: multi-month auto-allocation', () {
    final rahim = physics(start: ym(2026, 9));
    final today = d(2026, 11, 5);

    test('2500 -> Sep 1000, Oct 1000, Nov 500', () {
      final dues = duesOf(rahim, today);
      final alloc =
          DuesEngine.autoAllocate(dues: dues, amount: 2500, today: today);
      expect(alloc, [
        Allocation(month: ym(2026, 9), amount: 1000),
        Allocation(month: ym(2026, 10), amount: 1000),
        Allocation(month: ym(2026, 11), amount: 500),
      ]);
      expect(
        () => DuesEngine.validateAllocations(dues: dues, allocations: alloc),
        returnsNormally,
      );
      final after = duesOf(rahim, today, applyAllocations(rahim.enrollmentId, alloc));
      expect(monthOf(after, ym(2026, 9)).state, MonthState.paid);
      expect(monthOf(after, ym(2026, 10)).state, MonthState.paid);
      final nov = monthOf(after, ym(2026, 11));
      expect(nov.state, MonthState.partial);
      expect(nov.paid, 500);
      expect(nov.remaining, 500);
      expect(after.totalOutstanding, 500);
    });
  });

  // ---------------------------------------------------------------------------
  group('Scenario 6: first billable month from the join date', () {
    final cases = <({LocalDate join, int cutoff, YearMonth fbm})>[
      (join: d(2026, 11, 10), cutoff: 15, fbm: ym(2026, 11)),
      (join: d(2026, 11, 20), cutoff: 15, fbm: ym(2026, 12)),
      (join: d(2026, 11, 1), cutoff: 15, fbm: ym(2026, 11)),
      (join: d(2026, 11, 15), cutoff: 15, fbm: ym(2026, 11)),
      (join: d(2026, 11, 16), cutoff: 15, fbm: ym(2026, 12)),
      (join: d(2026, 12, 15), cutoff: 15, fbm: ym(2026, 12)),
      (join: d(2026, 12, 16), cutoff: 15, fbm: ym(2027, 1)),
      (join: d(2026, 11, 10), cutoff: 10, fbm: ym(2026, 11)),
      (join: d(2026, 11, 11), cutoff: 10, fbm: ym(2026, 12)),
      (join: d(2026, 11, 1), cutoff: 1, fbm: ym(2026, 11)),
      (join: d(2026, 11, 2), cutoff: 1, fbm: ym(2026, 12)),
      (join: d(2028, 2, 28), cutoff: 28, fbm: ym(2028, 2)),
      (join: d(2028, 2, 29), cutoff: 28, fbm: ym(2028, 3)),
      (join: d(2027, 2, 28), cutoff: 28, fbm: ym(2027, 2)),
    ];
    for (final c in cases) {
      test('join ${c.join}, cutoff ${c.cutoff} -> ${c.fbm}', () {
        expect(DuesEngine.defaultFirstBillableMonth(c.join, c.cutoff), c.fbm);
      });
    }

    test('no proration: a 20 Nov joiner first owes the full Dec fee', () {
      final t = physics(
          start: DuesEngine.defaultFirstBillableMonth(d(2026, 11, 20), 15));
      final dues = duesOf(t, d(2026, 12, 5));
      expect(dues.months.first.month, ym(2026, 12));
      expect(dues.months.any((m) => m.month == ym(2026, 11)), isFalse);
      expect(dues.openDue.single.fee, 1000);
      expect(dues.totalOutstanding, 1000);
    });

    test('changing the cutoff later does not move an existing FBM', () {
      // Enrolled on 20 Nov while C = 15: stored start month = Dec.
      final existing = physics(
          start: DuesEngine.defaultFirstBillableMonth(d(2026, 11, 20), 15));
      // Teacher later sets C = 25: only new enrollments use it.
      final newer = physics(
        id: 'e-new',
        studentId: 's-new',
        name: 'Nila',
        start: DuesEngine.defaultFirstBillableMonth(d(2026, 11, 20), 25),
      );
      expect(existing.start, ym(2026, 12));
      expect(newer.start, ym(2026, 11));
      final today = d(2026, 12, 5);
      expect(duesOf(existing, today).totalOutstanding, 1000);
      expect(duesOf(newer, today).totalOutstanding, 2000);
    });
  });

  // ---------------------------------------------------------------------------
  group('Scenario 7: multiple batches', () {
    final saraPhy = physics(
        id: 'e-sara-phy', studentId: 's-sara', name: 'Sara', start: ym(2026, 10));
    final saraChem = chem(
        id: 'e-sara-chem', studentId: 's-sara', name: 'Sara', start: ym(2026, 10));
    final today = d(2026, 11, 5);
    final base = [pay(saraPhy.enrollmentId, ym(2026, 10), 1000)];

    test('before paying: dues per batch and a combined total', () {
      final report = DuesEngine.report(
          today: today, terms: [saraPhy, saraChem], payments: base);
      final s = report.active.single;
      expect(s.enrollments.map((e) => e.terms.batchName), ['Chem B', 'Physics A']);
      expect(s.enrollments[0].totalOutstanding, 800);
      expect(s.enrollments[1].totalOutstanding, 1000);
      expect(s.totalOutstanding, 1800);
      expect(s.openMonths, [ym(2026, 10), ym(2026, 11)]);
      expect(s.openDueMonths, 2);
      expect(s.worst, DueLevel.followUp);
      expect(s.worstDay, 5);
      expect(s.oldestOpenDue, ym(2026, 10));
    });

    test('paying Physics Nov leaves Chem B untouched', () {
      final after = [...base, pay(saraPhy.enrollmentId, ym(2026, 11), 1000)];
      expect(monthOf(duesOf(saraPhy, today, after), ym(2026, 11)).state,
          MonthState.paid);
      expect(duesOf(saraChem, today, after), duesOf(saraChem, today, base));
      final report = DuesEngine.report(
          today: today, terms: [saraPhy, saraChem], payments: after);
      final s = report.active.single;
      expect(s.enrollments.single.terms.batchName, 'Chem B');
      expect(s.totalOutstanding, 800);
      expect(s.openMonths, [ym(2026, 10)]);
    });

    test('sums several overdue months across two batches', () {
      final report = DuesEngine.report(
          today: d(2026, 12, 3), terms: [saraPhy, saraChem], payments: const []);
      final s = report.active.single;
      // Physics: Oct, Nov (OD) + Dec (day 3); Chem: Oct (OD) + Nov (day 3).
      expect(s.totalOutstanding, 3 * 1000 + 2 * 800);
      expect(s.openMonths, [ym(2026, 10), ym(2026, 11), ym(2026, 12)]);
      expect(s.openDueMonths, 3);
      expect(s.worst, DueLevel.overdue);
      expect(s.worstDay, isNull);
      expect(s.oldestOpenDue, ym(2026, 10));
      expect(report.countByLevel[DueLevel.overdue], 1);
      expect(report.totalOutstandingActive, 4600);
    });
  });

  // ---------------------------------------------------------------------------
  group('Scenario 8: left student', () {
    final lbmCases = <({LocalDate date, YearMonth lbm})>[
      (date: d(2026, 11, 5), lbm: ym(2026, 10)),
      (date: d(2026, 11, 1), lbm: ym(2026, 10)),
      (date: d(2026, 11, 10), lbm: ym(2026, 10)),
      (date: d(2026, 11, 11), lbm: ym(2026, 11)),
      (date: d(2026, 11, 15), lbm: ym(2026, 11)),
      (date: d(2026, 11, 30), lbm: ym(2026, 11)),
      (date: d(2027, 1, 5), lbm: ym(2026, 12)),
      (date: d(2027, 1, 11), lbm: ym(2027, 1)),
      (date: d(2028, 2, 29), lbm: ym(2028, 2)),
      (date: d(2028, 3, 10), lbm: ym(2028, 2)),
    ];
    for (final c in lbmCases) {
      test('left/archived on ${c.date} -> LBM ${c.lbm}', () {
        expect(DuesEngine.defaultLastBillableMonth(c.date), c.lbm);
      });
    }

    final leftOn = d(2026, 11, 5);
    final rahimLeft = physics(
      start: ym(2026, 10),
      end: DuesEngine.defaultLastBillableMonth(leftOn),
      left: true,
    );

    test('left 5 Nov: Nov not billable, Oct still owed in the grey group', () {
      final dues = duesOf(rahimLeft, leftOn);
      expect(dues.months.map((m) => m.month), [ym(2026, 10)]);
      expect(dues.inactive, isTrue);
      expect(dues.totalOutstanding, 1000);
      final report = DuesEngine.report(
          today: leftOn, terms: [rahimLeft], payments: const []);
      expect(report.active, isEmpty);
      final g = report.inactive.single;
      expect(g.name, 'Rahim');
      expect(g.worst, isNull);
      expect(g.worstDay, isNull);
      expect(g.totalOutstanding, 1000);
      expect(g.openMonths, [ym(2026, 10)]);
      expect(report.countByLevel.values.every((n) => n == 0), isTrue);
      expect(report.totalOutstandingActive, 0);
      expect(report.totalOutstandingInactive, 1000);
      expect(report.studentsWithDues, 0);
      expect(report.overdueStudents, 0);
    });

    test('payments can still be recorded against the left enrollment', () {
      final dues = duesOf(rahimLeft, leftOn);
      expect(DuesEngine.autoAllocate(dues: dues, amount: 1000, today: leftOn),
          [Allocation(month: ym(2026, 10), amount: 1000)]);
      expect(
        () => DuesEngine.autoAllocate(dues: dues, amount: 1500, today: leftOn),
        throwsCode(ErrorCodes.allocationBeyondHorizon),
      );
      expect(
        () => DuesEngine.validateAllocations(
            dues: dues, allocations: [Allocation(month: ym(2026, 11), amount: 100)]),
        throwsCode(ErrorCodes.allocationExceedsRemaining),
      );
    });

    final dayCases = <({LocalDate date, List<YearMonth> owed, int total})>[
      (date: d(2026, 11, 10), owed: [ym(2026, 10)], total: 1000),
      (date: d(2026, 11, 11), owed: [ym(2026, 10), ym(2026, 11)], total: 2000),
    ];
    for (final c in dayCases) {
      test('leaving on ${c.date} owes ${c.owed}', () {
        final t = physics(
          start: ym(2026, 10),
          end: DuesEngine.defaultLastBillableMonth(c.date),
          left: true,
        );
        final dues = duesOf(t, c.date);
        expect(dues.openDue.map((m) => m.month), c.owed);
        expect(dues.totalOutstanding, c.total);
      });
    }
  });

  // ---------------------------------------------------------------------------
  group('Scenario 9: archive', () {
    final archivedOn = d(2026, 11, 15);
    final lbm = DuesEngine.defaultLastBillableMonth(archivedOn);
    final rahim = physics(start: ym(2026, 10), end: lbm, archived: true);
    final sara = physics(
      id: 'e-sara-phy',
      studentId: 's-sara',
      name: 'Sara',
      start: ym(2026, 11),
      end: lbm,
      archived: true,
    );
    final payments = [pay(rahim.enrollmentId, ym(2026, 10), 1000)];

    test('LBM is Nov; Dec never becomes due', () {
      expect(lbm, ym(2026, 11));
      for (final today in [d(2026, 12, 20), d(2027, 6, 1)]) {
        final dues = duesOf(rahim, today, payments);
        expect(dues.months.last.month, ym(2026, 11));
        expect(dues.months.any((m) => m.month == ym(2026, 12)), isFalse);
        expect(dues.openDue.map((m) => m.month), [ym(2026, 11)]);
      }
    });

    test('existing dues stay visible in the grey group', () {
      final report = DuesEngine.report(
          today: d(2026, 12, 20), terms: [sara, rahim], payments: payments);
      expect(report.active, isEmpty);
      expect(report.inactive.map((s) => s.name), ['Rahim', 'Sara']);
      expect(report.totalOutstandingInactive, 2000);
      expect(report.countByLevel.values.every((n) => n == 0), isTrue);
    });

    test('unarchive (LBM cleared) restores billing incl. Dec', () {
      final restored = physics(start: ym(2026, 10));
      final today = d(2026, 12, 3);
      final report = DuesEngine.report(
          today: today, terms: [restored], payments: payments);
      expect(report.inactive, isEmpty);
      final s = report.active.single;
      expect(s.openMonths, [ym(2026, 11), ym(2026, 12)]);
      expect(s.totalOutstanding, 2000);
      expect(s.worst, DueLevel.overdue);
      final dec = monthOf(duesOf(restored, today, payments), ym(2026, 12));
      expect(dec.level, DueLevel.remind);
      expect(dec.dayInDue, 3);
    });
  });

  // ---------------------------------------------------------------------------
  group('Scenario 10: waive and free', () {
    final rahim = physics(start: ym(2026, 11));
    final today = d(2026, 11, 5);

    test('waived Nov is not a due', () {
      final payments = [waive(rahim.enrollmentId, ym(2026, 11))];
      final dues = duesOf(rahim, today, payments);
      final nov = monthOf(dues, ym(2026, 11));
      expect(nov.state, MonthState.waived);
      expect(nov.isOpen, isFalse);
      expect(nov.remaining, 0);
      expect(nov.level, isNull);
      expect(dues.openDue, isEmpty);
      expect(
          DuesEngine.report(today: today, terms: [rahim], payments: payments)
              .active,
          isEmpty);
    });

    test('waived month with allocations: allocations stay, nothing owed', () {
      final dues = duesOf(rahim, today, [
        pay(rahim.enrollmentId, ym(2026, 11), 600),
        waive(rahim.enrollmentId, ym(2026, 11)),
      ]);
      final nov = monthOf(dues, ym(2026, 11));
      expect(nov.state, MonthState.waived);
      expect(nov.paid, 600);
      expect(nov.remaining, 0);
      expect(nov.overpaid, 0);
      expect(dues.totalOutstanding, 0);
    });

    test('waived beats paid and free', () {
      final free = physics(start: ym(2026, 11), overrides: const [
        FeePeriod(effective: YearMonth(2026, 11), amount: 0),
      ]);
      final payments = [
        pay(rahim.enrollmentId, ym(2026, 11), 1000),
        waive(rahim.enrollmentId, ym(2026, 11)),
      ];
      expect(monthOf(duesOf(rahim, today, payments), ym(2026, 11)).state,
          MonthState.waived);
      expect(monthOf(duesOf(free, today, payments), ym(2026, 11)).state,
          MonthState.waived);
    });

    test('override 0: no dues are ever generated', () {
      final free = physics(start: ym(2026, 11), overrides: const [
        FeePeriod(effective: YearMonth(2026, 11), amount: 0),
      ]);
      final later = d(2027, 11, 30);
      final dues = duesOf(free, later);
      expect(dues.months, isNotEmpty);
      expect(dues.months.every((m) => m.state == MonthState.free), isTrue);
      expect(dues.months.every((m) => !m.feeMissing && m.level == null), isTrue);
      expect(dues.openDue, isEmpty);
      expect(
          DuesEngine.report(today: later, terms: [free], payments: const [])
              .active,
          isEmpty);
      expect(
          DuesEngine.autoAllocate(dues: dues, amount: 0, today: later), isEmpty);
      expect(
        () => DuesEngine.autoAllocate(dues: dues, amount: 100, today: later),
        throwsCode(ErrorCodes.allocationBeyondHorizon),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('Scenario 11: fee change', () {
    const raised = <FeePeriod>[
      FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
      FeePeriod(effective: YearMonth(2026, 12), amount: 1200),
    ];
    final today = d(2026, 12, 5);

    test('Nov stays 1000, Dec is 1200 without override', () {
      final dues = duesOf(physics(start: ym(2026, 11), fees: raised), today);
      expect(monthOf(dues, ym(2026, 11)).fee, 1000);
      expect(monthOf(dues, ym(2026, 12)).fee, 1200);
      expect(dues.totalOutstanding, 2200);
    });

    test('override 800 stays 800 across the batch raise', () {
      final dues = duesOf(
        physics(start: ym(2026, 11), fees: raised, overrides: const [
          FeePeriod(effective: YearMonth(2026, 11), amount: 800),
        ]),
        today,
      );
      expect(monthOf(dues, ym(2026, 11)).fee, 800);
      expect(monthOf(dues, ym(2026, 12)).fee, 800);
      expect(dues.totalOutstanding, 1600);
    });
  });

  // ---------------------------------------------------------------------------
  group('fee change making paid months partial (monthsBecomingPartial)', () {
    final before = physics(start: ym(2026, 10));
    final id = before.enrollmentId;
    final today = d(2026, 11, 20);
    // Oct, Nov paid; Dec, Jan paid in advance.
    final payments = [
      pay(id, ym(2026, 10), 1000),
      pay(id, ym(2026, 11), 1000),
      pay(id, ym(2026, 12), 1000),
      pay(id, ym(2027, 1), 1000),
    ];
    EnrollmentTerms withFees(List<FeePeriod> fees) =>
        physics(start: ym(2026, 10), fees: fees);

    final cases = <({String label, EnrollmentTerms after, int count})>[
      (
        label: 'raise from Dec hits the two advance-paid months',
        after: withFees(const [
          FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
          FeePeriod(effective: YearMonth(2026, 12), amount: 1200),
        ]),
        count: 2,
      ),
      (
        label: 'retroactive raise from Nov hits Nov, Dec, Jan',
        after: withFees(const [
          FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
          FeePeriod(effective: YearMonth(2026, 11), amount: 1200),
        ]),
        count: 3,
      ),
      (
        label: 'lowering the fee makes nothing partial',
        after: withFees(const [
          FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
          FeePeriod(effective: YearMonth(2026, 12), amount: 900),
        ]),
        count: 0,
      ),
      (
        label: 'override raise from Jan hits Jan only',
        after: physics(start: ym(2026, 10), overrides: const [
          FeePeriod(effective: YearMonth(2027, 1), amount: 1500),
        ]),
        count: 1,
      ),
      (
        label: 'unchanged terms',
        after: before,
        count: 0,
      ),
    ];
    for (final c in cases) {
      test(c.label, () {
        expect(
          DuesEngine.monthsBecomingPartial(
              before: [before], after: [c.after], payments: payments, today: today),
          c.count,
        );
      });
    }

    test('the raised months become partial with the difference remaining', () {
      final after = withFees(const [
        FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
        FeePeriod(effective: YearMonth(2026, 11), amount: 1200),
      ]);
      final dues = duesOf(after, today, payments);
      final nov = monthOf(dues, ym(2026, 11));
      expect(nov.state, MonthState.partial);
      expect(nov.remaining, 200);
      expect(nov.level, DueLevel.overdue);
      final dec = monthOf(dues, ym(2026, 12));
      expect(dec.state, MonthState.partial);
      expect(dec.remaining, 200);
      expect(dec.level, DueLevel.upcoming);
      expect(dues.totalOutstanding, 200);
      expect(monthOf(dues, ym(2026, 10)).state, MonthState.paid);
    });

    test('a student with an override is not affected by a batch raise', () {
      final o = physics(start: ym(2026, 10), overrides: const [
        FeePeriod(effective: YearMonth(2026, 10), amount: 800),
      ]);
      final oRaised = physics(
        start: ym(2026, 10),
        fees: const [
          FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
          FeePeriod(effective: YearMonth(2026, 11), amount: 1200),
        ],
        overrides: const [
          FeePeriod(effective: YearMonth(2026, 10), amount: 800),
        ],
      );
      final p = [
        pay(id, ym(2026, 10), 800),
        pay(id, ym(2026, 11), 800),
        pay(id, ym(2026, 12), 800),
      ];
      expect(
        DuesEngine.monthsBecomingPartial(
            before: [o], after: [oRaised], payments: p, today: today),
        0,
      );
    });

    test('waived months stay waived through a raise', () {
      final p = [...payments.take(2), waive(id, ym(2026, 12))];
      final after = withFees(const [
        FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
        FeePeriod(effective: YearMonth(2026, 12), amount: 1200),
      ]);
      expect(monthOf(duesOf(after, today, p), ym(2026, 12)).state,
          MonthState.waived);
      expect(
        DuesEngine.monthsBecomingPartial(
            before: [before], after: [after], payments: p, today: today),
        0,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('Dec -> Jan rollover', () {
    final post = chem(start: ym(2026, 12));
    final cases = <({LocalDate today, DueLevel level, int? day})>[
      (today: d(2026, 12, 31), level: DueLevel.upcoming, day: null),
      (today: d(2027, 1, 1), level: DueLevel.justDue, day: 1),
      (today: d(2027, 1, 10), level: DueLevel.finalDays, day: 10),
      (today: d(2027, 1, 11), level: DueLevel.overdue, day: null),
    ];
    for (final c in cases) {
      test('postpaid Dec on ${c.today} -> ${c.level.name}', () {
        final dec = monthOf(duesOf(post, c.today), ym(2026, 12));
        expect(dec.dueDate, d(2027, 1, 1));
        expect(dec.level, c.level);
        expect(dec.dayInDue, c.day);
      });
    }

    test('prepaid on 31 Dec: Dec overdue, Jan upcoming', () {
      final dues = duesOf(physics(start: ym(2026, 12)), d(2026, 12, 31));
      expect(monthOf(dues, ym(2026, 12)).level, DueLevel.overdue);
      final jan = monthOf(dues, ym(2027, 1));
      expect(jan.dueDate, d(2027, 1, 1));
      expect(jan.level, DueLevel.upcoming);
      expect(dues.openDue.map((m) => m.month), [ym(2026, 12)]);
    });

    test('prepaid on 1 Jan: Dec overdue, Jan just due', () {
      final dues = duesOf(physics(start: ym(2026, 12)), d(2027, 1, 1));
      expect(dues.openDue.map((m) => m.month), [ym(2026, 12), ym(2027, 1)]);
      expect(monthOf(dues, ym(2027, 1)).level, DueLevel.justDue);
      expect(dues.worst, DueLevel.overdue);
      expect(dues.oldestOpenDue, ym(2026, 12));
    });
  });

  // ---------------------------------------------------------------------------
  group('February and leap years', () {
    final cases = <({
      String label,
      EnrollmentTerms t,
      YearMonth m,
      LocalDate today,
      DueLevel level,
      int? day,
    })>[
      (
        label: 'postpaid Jan 2028 on 10 Feb (leap)',
        t: chem(start: ym(2028, 1)),
        m: ym(2028, 1),
        today: d(2028, 2, 10),
        level: DueLevel.finalDays,
        day: 10,
      ),
      (
        label: 'postpaid Jan 2028 on 29 Feb (leap)',
        t: chem(start: ym(2028, 1)),
        m: ym(2028, 1),
        today: d(2028, 2, 29),
        level: DueLevel.overdue,
        day: null,
      ),
      (
        label: 'postpaid Feb 2028 on 29 Feb is upcoming',
        t: chem(start: ym(2028, 1)),
        m: ym(2028, 2),
        today: d(2028, 2, 29),
        level: DueLevel.upcoming,
        day: null,
      ),
      (
        label: 'postpaid Feb 2028 on 1 Mar is just due',
        t: chem(start: ym(2028, 1)),
        m: ym(2028, 2),
        today: d(2028, 3, 1),
        level: DueLevel.justDue,
        day: 1,
      ),
      (
        label: 'prepaid Feb 2028 on 29 Feb',
        t: physics(start: ym(2028, 2)),
        m: ym(2028, 2),
        today: d(2028, 2, 29),
        level: DueLevel.overdue,
        day: null,
      ),
      (
        label: 'prepaid Feb 2028 on 1 Mar (older month = overdue)',
        t: physics(start: ym(2028, 2)),
        m: ym(2028, 2),
        today: d(2028, 3, 1),
        level: DueLevel.overdue,
        day: null,
      ),
      (
        label: 'postpaid Feb 2027 on 28 Feb (non-leap) is upcoming',
        t: chem(start: ym(2027, 2)),
        m: ym(2027, 2),
        today: d(2027, 2, 28),
        level: DueLevel.upcoming,
        day: null,
      ),
      (
        label: 'postpaid Feb 2027 on 1 Mar is just due',
        t: chem(start: ym(2027, 2)),
        m: ym(2027, 2),
        today: d(2027, 3, 1),
        level: DueLevel.justDue,
        day: 1,
      ),
    ];
    for (final c in cases) {
      test(c.label, () {
        final md = monthOf(duesOf(c.t, c.today), c.m);
        expect(md.level, c.level);
        expect(md.dayInDue, c.day);
      });
    }
  });

  // ---------------------------------------------------------------------------
  group('overdue across several months', () {
    final t = physics(start: ym(2026, 6));
    final payments = [
      pay(t.enrollmentId, ym(2026, 6), 1000),
      pay(t.enrollmentId, ym(2026, 8), 300),
    ];

    test('12 Nov: Jul..Nov open, 4700, since Jul, all overdue', () {
      final dues = duesOf(t, d(2026, 11, 12), payments);
      expect(dues.openDue.map((m) => m.month),
          [ym(2026, 7), ym(2026, 8), ym(2026, 9), ym(2026, 10), ym(2026, 11)]);
      expect(dues.openDue.every((m) => m.level == DueLevel.overdue), isTrue);
      expect(monthOf(dues, ym(2026, 8)).state, MonthState.partial);
      expect(monthOf(dues, ym(2026, 8)).remaining, 700);
      expect(dues.totalOutstanding, 4700);
      expect(dues.oldestOpenDue, ym(2026, 7));
      expect(dues.worst, DueLevel.overdue);
      expect(dues.worstDay, isNull);
      final s = DuesEngine.report(
              today: d(2026, 11, 12), terms: [t], payments: payments)
          .active
          .single;
      expect(s.openDueMonths, 5);
      expect(s.totalOutstanding, 4700);
      expect(s.oldestOpenDue, ym(2026, 7));
    });

    test('4 Nov: older months make the enrollment overdue, Nov is day 4', () {
      final dues = duesOf(t, d(2026, 11, 4), payments);
      expect(dues.worst, DueLevel.overdue);
      expect(dues.worstDay, isNull);
      final nov = monthOf(dues, ym(2026, 11));
      expect(nov.level, DueLevel.remind);
      expect(nov.dayInDue, 4);
      expect(dues.totalOutstanding, 4700);
    });
  });

  // ---------------------------------------------------------------------------
  group('months range', () {
    final cases = <({
      String label,
      EnrollmentTerms t,
      LocalDate today,
      int ahead,
      YearMonth? first,
      YearMonth? last,
      int count,
    })>[
      (
        label: 'open-ended: start .. today + 12',
        t: physics(start: ym(2026, 10)),
        today: d(2026, 11, 5),
        ahead: 12,
        first: ym(2026, 10),
        last: ym(2027, 11),
        count: 14,
      ),
      (
        label: 'end in the middle of the range',
        t: physics(start: ym(2026, 10), end: ym(2026, 12)),
        today: d(2026, 11, 5),
        ahead: 12,
        first: ym(2026, 10),
        last: ym(2026, 12),
        count: 3,
      ),
      (
        label: 'aheadMonths 0 stops at the current month',
        t: physics(start: ym(2026, 10)),
        today: d(2026, 11, 5),
        ahead: 0,
        first: ym(2026, 10),
        last: ym(2026, 11),
        count: 2,
      ),
      (
        label: 'today before the start month',
        t: physics(start: ym(2027, 1)),
        today: d(2026, 11, 20),
        ahead: 12,
        first: ym(2027, 1),
        last: ym(2027, 11),
        count: 11,
      ),
      (
        label: 'start beyond the horizon',
        t: physics(start: ym(2028, 1)),
        today: d(2026, 11, 20),
        ahead: 12,
        first: null,
        last: null,
        count: 0,
      ),
      (
        label: 'LBM before FBM (removed before billing started)',
        t: physics(start: ym(2026, 12), end: ym(2026, 11), ended: true),
        today: d(2026, 11, 20),
        ahead: 12,
        first: null,
        last: null,
        count: 0,
      ),
    ];
    for (final c in cases) {
      test(c.label, () {
        final dues = DuesEngine.forEnrollment(
            terms: c.t, payments: const [], today: c.today, aheadMonths: c.ahead);
        expect(dues.months.length, c.count);
        if (c.count > 0) {
          expect(dues.months.first.month, c.first);
          expect(dues.months.last.month, c.last);
        }
      });
    }

    test('today before start: everything upcoming, nothing due', () {
      final dues = duesOf(physics(start: ym(2027, 1)), d(2026, 11, 20));
      expect(dues.months.every((m) => m.level == DueLevel.upcoming), isTrue);
      expect(dues.months.every((m) => !m.isDue), isTrue);
      expect(dues.openDue, isEmpty);
      expect(dues.worst, isNull);
      expect(dues.totalOutstanding, 0);
    });

    test('payments outside the billable range or of other enrollments are ignored',
        () {
      final t = physics(start: ym(2026, 11));
      final dues = duesOf(t, d(2026, 11, 5), [
        pay(t.enrollmentId, ym(2026, 10), 1000),
        pay('someone-else', ym(2026, 11), 1000),
        waive('someone-else', ym(2026, 11)),
      ]);
      expect(dues.months.first.month, ym(2026, 11));
      expect(dues.openDue.single.state, MonthState.unpaid);
      expect(dues.totalOutstanding, 1000);
    });
  });

  // ---------------------------------------------------------------------------
  group('overpaid and feeMissing', () {
    final today = d(2026, 11, 5);

    test('overpaid month: excess reported, no carry-forward', () {
      final t = physics(start: ym(2026, 11));
      final dues = duesOf(t, today, [pay(t.enrollmentId, ym(2026, 11), 1500)]);
      final nov = monthOf(dues, ym(2026, 11));
      expect(nov.state, MonthState.paid);
      expect(nov.overpaid, 500);
      expect(nov.remaining, 0);
      expect(nov.level, isNull);
      final dec = monthOf(dues, ym(2026, 12));
      expect(dec.state, MonthState.unpaid);
      expect(dec.remaining, 1000);
    });

    test('no batch fee at all: feeMissing, never a due', () {
      final t = physics(start: ym(2026, 9), fees: const <FeePeriod>[]);
      final dues = duesOf(t, today);
      expect(dues.months.every((m) => m.feeMissing && m.fee == 0), isTrue);
      expect(dues.months.every((m) => m.state == MonthState.free), isTrue);
      expect(dues.openDue, isEmpty);
      expect(DuesEngine.report(today: today, terms: [t], payments: const [])
          .active, isEmpty);
    });

    test('QA-01: batch fee starting after the FBM bills the early month',
        () {
      final t = physics(start: ym(2026, 11), fees: const [
        FeePeriod(effective: YearMonth(2026, 12), amount: 1000),
      ]);
      final dues = duesOf(t, d(2026, 12, 2));
      final nov = monthOf(dues, ym(2026, 11));
      expect(nov.feeMissing, isFalse);
      expect(nov.state, MonthState.unpaid);
      expect(nov.fee, 1000);
      final dec = monthOf(dues, ym(2026, 12));
      expect(dec.feeMissing, isFalse);
      expect(dec.state, MonthState.unpaid);
      expect(dues.totalOutstanding, 2000);
    });

    test('QA-01: migrated student (FBM Sep, batch fee from Nov) owes 3 months',
        () {
      // Batch created 21 Nov with ৳1000; Sara's fee starts Sep (scenario 3).
      final sara = physics(
          id: 'e-sara-phy',
          studentId: 's-sara',
          name: 'Sara',
          start: ym(2026, 9),
          fees: const [FeePeriod(effective: YearMonth(2026, 11), amount: 1000)]);
      final today = d(2026, 11, 21);
      final dues = duesOf(sara, today);
      expect(dues.months.where((m) => m.state == MonthState.free), isEmpty);
      expect(dues.openDue.map((m) => m.month),
          [ym(2026, 9), ym(2026, 10), ym(2026, 11)]);
      expect(dues.totalOutstanding, 3000);
      expect(dues.worst, DueLevel.overdue);
      expect(dues.oldestOpenDue, ym(2026, 9));
      final report =
          DuesEngine.report(today: today, terms: [sara], payments: const []);
      expect(report.active.single.openDueMonths, 3);
      expect(report.active.single.totalOutstanding, 3000);
      expect(report.overdueStudents, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('autoAllocate (Product 3.4)', () {
    final today = d(2026, 11, 5);

    final cases = <({
      String label,
      EnrollmentTerms t,
      List<PaymentFact> payments,
      int amount,
      List<Allocation> expected,
    })>[
      (
        label: 'advance after all due months are paid',
        t: physics(start: ym(2026, 9)),
        payments: [
          pay('e-rahim-phy', ym(2026, 9), 1000),
          pay('e-rahim-phy', ym(2026, 10), 1000),
          pay('e-rahim-phy', ym(2026, 11), 1000),
        ],
        amount: 3000,
        expected: [
          Allocation(month: ym(2026, 12), amount: 1000),
          Allocation(month: ym(2027, 1), amount: 1000),
          Allocation(month: ym(2027, 2), amount: 1000),
        ],
      ),
      (
        label: 'partial month first takes only its remaining',
        t: physics(start: ym(2026, 11)),
        payments: [pay('e-rahim-phy', ym(2026, 11), 600)],
        amount: 900,
        expected: [
          Allocation(month: ym(2026, 11), amount: 400),
          Allocation(month: ym(2026, 12), amount: 500),
        ],
      ),
      (
        label: 'waived and paid months are skipped',
        t: physics(start: ym(2026, 9)),
        payments: [
          waive('e-rahim-phy', ym(2026, 10)),
          pay('e-rahim-phy', ym(2026, 11), 1000),
        ],
        amount: 2500,
        expected: [
          Allocation(month: ym(2026, 9), amount: 1000),
          Allocation(month: ym(2026, 12), amount: 1000),
          Allocation(month: ym(2027, 1), amount: 500),
        ],
      ),
      (
        label: 'follows the fee history',
        t: physics(start: ym(2026, 11), fees: const [
          FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
          FeePeriod(effective: YearMonth(2026, 12), amount: 1200),
        ]),
        payments: const <PaymentFact>[],
        amount: 2400,
        expected: [
          Allocation(month: ym(2026, 11), amount: 1000),
          Allocation(month: ym(2026, 12), amount: 1200),
          Allocation(month: ym(2027, 1), amount: 200),
        ],
      ),
      (
        label: 'free months (override 0) are skipped',
        t: physics(start: ym(2026, 11), overrides: const [
          FeePeriod(effective: YearMonth(2026, 11), amount: 0),
          FeePeriod(effective: YearMonth(2027, 1), amount: 500),
        ]),
        payments: const <PaymentFact>[],
        amount: 700,
        expected: [
          Allocation(month: ym(2027, 1), amount: 500),
          Allocation(month: ym(2027, 2), amount: 200),
        ],
      ),
      (
        label: 'amount 0 allocates nothing',
        t: physics(start: ym(2026, 11)),
        payments: const <PaymentFact>[],
        amount: 0,
        expected: const <Allocation>[],
      ),
    ];
    for (final c in cases) {
      test(c.label, () {
        final dues = duesOf(c.t, today, c.payments);
        final alloc =
            DuesEngine.autoAllocate(dues: dues, amount: c.amount, today: today);
        expect(alloc, c.expected);
        final total = alloc.fold<int>(0, (s, a) => s + a.amount);
        expect(total, c.amount);
      });
    }

    final fresh = physics(start: ym(2026, 11));

    test('exactly 12 months ahead fits (Nov 2026 .. Nov 2027)', () {
      final alloc = DuesEngine.autoAllocate(
          dues: duesOf(fresh, today), amount: 13000, today: today);
      expect(alloc.length, 13);
      expect(alloc.last, Allocation(month: ym(2027, 11), amount: 1000));
    });

    test('one taka beyond 12 months is rejected', () {
      expect(
        () => DuesEngine.autoAllocate(
            dues: duesOf(fresh, today), amount: 13001, today: today),
        throwsCode(ErrorCodes.allocationBeyondHorizon),
      );
    });

    test('horizon holds even if dues were computed further ahead', () {
      final wide = DuesEngine.forEnrollment(
          terms: fresh, payments: const [], today: today, aheadMonths: 24);
      expect(
        () => DuesEngine.autoAllocate(dues: wide, amount: 14000, today: today),
        throwsCode(ErrorCodes.allocationBeyondHorizon),
      );
    });

    test('negative amount is invalid', () {
      expect(
        () => DuesEngine.autoAllocate(
            dues: duesOf(fresh, today), amount: -1, today: today),
        throwsCode(ErrorCodes.amountInvalid),
      );
    });

    test('advance months become paid but are never due', () {
      final t = physics(start: ym(2026, 11));
      final alloc = DuesEngine.autoAllocate(
          dues: duesOf(t, today), amount: 3000, today: today);
      final after = duesOf(t, today, applyAllocations(t.enrollmentId, alloc));
      for (final m in [ym(2026, 12), ym(2027, 1)]) {
        final md = monthOf(after, m);
        expect(md.state, MonthState.paid);
        expect(md.isDue, isFalse);
        expect(md.level, isNull);
      }
      expect(after.openDue, isEmpty);
      expect(after.totalOutstanding, 0);
    });
  });

  // ---------------------------------------------------------------------------
  group('validateAllocations (Product 3.4)', () {
    final t = physics(start: ym(2026, 9));
    final id = t.enrollmentId;
    final today = d(2026, 11, 5);
    final dues = duesOf(t, today, [
      pay(id, ym(2026, 9), 1000),
      pay(id, ym(2026, 10), 600),
      waive(id, ym(2026, 12)),
    ]);

    test('valid manual split incl. advance up to the horizon', () {
      expect(
        () => DuesEngine.validateAllocations(dues: dues, allocations: [
          Allocation(month: ym(2026, 10), amount: 400),
          Allocation(month: ym(2026, 11), amount: 1000),
          Allocation(month: ym(2027, 1), amount: 1000),
          Allocation(month: ym(2027, 11), amount: 1000),
        ]),
        returnsNormally,
      );
    });

    final bad = <({String label, List<Allocation> allocations, String code})>[
      (
        label: 'more than a partial month remaining',
        allocations: [Allocation(month: ym(2026, 10), amount: 500)],
        code: ErrorCodes.allocationExceedsRemaining,
      ),
      (
        label: 'into a paid month',
        allocations: [Allocation(month: ym(2026, 9), amount: 1)],
        code: ErrorCodes.allocationExceedsRemaining,
      ),
      (
        label: 'into a waived month',
        allocations: [Allocation(month: ym(2026, 12), amount: 100)],
        code: ErrorCodes.allocationExceedsRemaining,
      ),
      (
        label: 'before the first billable month',
        allocations: [Allocation(month: ym(2026, 8), amount: 100)],
        code: ErrorCodes.allocationExceedsRemaining,
      ),
      (
        label: 'beyond today + 12 months',
        allocations: [Allocation(month: ym(2027, 12), amount: 100)],
        code: ErrorCodes.allocationBeyondHorizon,
      ),
      (
        label: 'same month twice summing above the fee',
        allocations: [
          Allocation(month: ym(2026, 11), amount: 600),
          Allocation(month: ym(2026, 11), amount: 600),
        ],
        code: ErrorCodes.allocationExceedsRemaining,
      ),
      (
        label: 'zero allocation',
        allocations: [Allocation(month: ym(2026, 11), amount: 0)],
        code: ErrorCodes.amountInvalid,
      ),
      (
        label: 'negative allocation',
        allocations: [Allocation(month: ym(2026, 11), amount: -5)],
        code: ErrorCodes.amountInvalid,
      ),
      (
        label: 'no allocations',
        allocations: const <Allocation>[],
        code: ErrorCodes.amountInvalid,
      ),
    ];
    for (final c in bad) {
      test('rejects: ${c.label}', () {
        expect(
          () => DuesEngine.validateAllocations(
              dues: dues, allocations: c.allocations),
          throwsCode(c.code),
        );
      });
    }
  });

  // ---------------------------------------------------------------------------
  group('report: sort order (plan 1 #8)', () {
    final today = d(2026, 11, 5); // current-window level = followUp (day 5)
    List<FeePeriod> fee(int amount) =>
        [FeePeriod(effective: ym(2026, 1), amount: amount)];
    EnrollmentTerms p(String name, YearMonth start, int amount) => physics(
          id: 'e-$name-phy',
          studentId: 's-$name',
          name: name,
          start: start,
          fees: fee(amount),
        );

    final terms = <EnrollmentTerms>[
      p('Hasan', ym(2026, 11), 1000), // FU, 1 month, 1000
      p('Anis', ym(2026, 10), 1000), // OD, 1 month (Nov paid), 1000
      p('Dipu', ym(2026, 11), 1000), // FU, 1 month, 1000
      p('Babu', ym(2026, 10), 1000), // OD, 2 months, 2000
      p('Farid', ym(2026, 11), 1500), // FU, 1 month, 1500
      p('Gopal', ym(2026, 9), 300), // OD, 3 months, 900
      p('Emon', ym(2026, 11), 1000), // FU (with Chem Oct): 2 months, 1800
      chem(
          id: 'e-Emon-chem',
          studentId: 's-Emon',
          name: 'Emon',
          start: ym(2026, 10)),
      p('Chandra', ym(2026, 10), 1250), // OD, 2 months, 2500
      p('Ilias', ym(2026, 12), 1000), // only upcoming -> not listed
    ];
    final payments = [pay('e-Anis-phy', ym(2026, 11), 1000)];

    test('level desc -> open months desc -> total desc -> name', () {
      final report =
          DuesEngine.report(today: today, terms: terms, payments: payments);
      expect(report.active.map((s) => s.name), [
        'Gopal',
        'Chandra',
        'Babu',
        'Anis',
        'Emon',
        'Farid',
        'Dipu',
        'Hasan',
      ]);
      expect(report.inactive, isEmpty);
      expect(report.studentsWithDues, 8);
      expect(report.overdueStudents, 4);
      expect(report.countByLevel, {
        DueLevel.justDue: 0,
        DueLevel.remind: 0,
        DueLevel.followUp: 4,
        DueLevel.urgent: 0,
        DueLevel.finalDays: 0,
        DueLevel.overdue: 4,
      });
      expect(report.totalOutstandingActive,
          900 + 2500 + 2000 + 1000 + 1800 + 1500 + 1000 + 1000);
    });

    test('input order does not change the result', () {
      final a = DuesEngine.report(today: today, terms: terms, payments: payments);
      final b = DuesEngine.report(
          today: today, terms: terms.reversed.toList(), payments: payments);
      expect(a.active.map((s) => s.studentId), b.active.map((s) => s.studentId));
    });
  });

  // ---------------------------------------------------------------------------
  group('report: grey group split', () {
    final today = d(2026, 11, 5);
    final saraPhy = physics(
        id: 'e-sara-phy', studentId: 's-sara', name: 'Sara', start: ym(2026, 11));
    // Removed from Chem B on 5 Nov -> LBM Oct (postpaid Oct due 1 Nov).
    final saraChemEnded = chem(
      id: 'e-sara-chem',
      studentId: 's-sara',
      name: 'Sara',
      start: ym(2026, 10),
      end: DuesEngine.defaultLastBillableMonth(today),
      ended: true,
    );

    test('student removed from one batch appears in both groups', () {
      final report = DuesEngine.report(
          today: today, terms: [saraPhy, saraChemEnded], payments: const []);
      final a = report.active.single;
      expect(a.enrollments.single.terms.batchName, 'Physics A');
      expect(a.totalOutstanding, 1000);
      expect(a.worst, DueLevel.followUp);
      expect(a.worstDay, 5);
      final g = report.inactive.single;
      expect(g.studentId, 's-sara');
      expect(g.enrollments.single.terms.batchName, 'Chem B');
      expect(g.enrollments.single.inactive, isTrue);
      expect(g.totalOutstanding, 800);
      expect(g.worst, isNull);
      expect(report.totalOutstandingActive, 1000);
      expect(report.totalOutstandingInactive, 800);
      expect(report.countByLevel[DueLevel.followUp], 1);
      expect(report.countByLevel[DueLevel.overdue], 0);
    });

    test('countByLevel has levels 1-6 only', () {
      final report =
          DuesEngine.report(today: today, terms: const [], payments: const []);
      expect(report.countByLevel.keys.toSet(), {
        DueLevel.justDue,
        DueLevel.remind,
        DueLevel.followUp,
        DueLevel.urgent,
        DueLevel.finalDays,
        DueLevel.overdue,
      });
      expect(report.active, isEmpty);
      expect(report.totalOutstandingActive, 0);
    });
  });

  // ---------------------------------------------------------------------------
  group('rejoin / unarchive gap (Product 3.2)', () {
    final today = d(2026, 11, 5);
    final id = 'e-rahim-phy';
    final history = [
      pay(id, ym(2026, 6), 1000),
      pay(id, ym(2026, 7), 1000),
      pay(id, ym(2026, 8), 1000),
    ];
    // Left on 5 Sep (LBM Aug), rejoined 5 Nov: LBM cleared, Active again.
    final rejoined = physics(start: ym(2026, 6));

    test('while left: nothing owed', () {
      final left = physics(
        start: ym(2026, 6),
        end: DuesEngine.defaultLastBillableMonth(d(2026, 9, 5)),
        left: true,
      );
      expect(duesOf(left, today, history).totalOutstanding, 0);
    });

    test('gap months waived (default Yes): only Nov owed', () {
      final p = [...history, waive(id, ym(2026, 9)), waive(id, ym(2026, 10))];
      final dues = duesOf(rejoined, today, p);
      expect(dues.openDue.map((m) => m.month), [ym(2026, 11)]);
      expect(dues.worst, DueLevel.followUp);
      expect(dues.totalOutstanding, 1000);
      expect(dues.inactive, isFalse);
    });

    test('gap not waived: gap months are billable and overdue', () {
      final dues = duesOf(rejoined, today, history);
      expect(dues.openDue.map((m) => m.month),
          [ym(2026, 9), ym(2026, 10), ym(2026, 11)]);
      expect(dues.worst, DueLevel.overdue);
      expect(dues.totalOutstanding, 3000);
    });
  });
}
