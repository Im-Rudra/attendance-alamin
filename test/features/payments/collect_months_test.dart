// Ticking months in the collect form (teacher feedback item 7): any months,
// gaps allowed, the amount is the sum of what they still owe, typing an
// amount clears the ticks, paid months cannot be ticked, and the month grid
// reaches past the six chips. Controller and pure-rule tests.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/features/payments/controllers/collect_payment_controller.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/widgets/month_grid_picker.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

const YearMonth _sep = YearMonth(2026, 9);
const YearMonth _oct = YearMonth(2026, 10);
const YearMonth _nov = YearMonth(2026, 11);
const YearMonth _dec = YearMonth(2026, 12);
const YearMonth _jan = YearMonth(2027, 1);
const YearMonth _feb = YearMonth(2027, 2);

const PayArgs _args = (studentId: kStuRahim, enrollmentId: kEnrRahimPhys, receiptId: null);

Map<YearMonth, int> _map(CollectPlan p) => <YearMonth, int>{
      for (final Allocation a in p.allocations) a.month: a.amount,
    };

/// A container with Rahim's dues loaded (Sep and Oct paid unless
/// [withPayments] is false) and the form controller alive.
Future<ProviderContainer> _setup({bool withPayments = true, int? partialNov}) async {
  final SeededFakes f = seedFakes(withPayments: withPayments);
  if (partialNov != null) {
    await f.payments.record(PaymentDraft(
      studentId: kStuRahim,
      enrollmentId: kEnrRahimPhys,
      allocations: <Allocation>[Allocation(month: _nov, amount: partialNov)],
      paidOn: kToday,
      method: PaymentMethod.cash,
    ));
  }
  final ProviderContainer c = makeContainer(overrides: f.overrides);
  await readData(c, payChoicesProvider(kStuRahim));
  await readData(c, payDuesProvider((enrollmentId: kEnrRahimPhys, receiptId: null)));
  c.listen(collectPaymentControllerProvider(_args), (_, __) {});
  await settle();
  return c;
}

EnrollmentDues _dues(ProviderContainer c) =>
    c.read(payDuesProvider((enrollmentId: kEnrRahimPhys, receiptId: null))).requireValue!;

CollectPaymentController _ctl(ProviderContainer c) => c.read(collectPaymentControllerProvider(_args).notifier);

CollectInput _input(ProviderContainer c) => c.read(collectPaymentControllerProvider(_args));

CollectPlan _plan(ProviderContainer c) {
  final CollectInput i = _input(c);
  return buildPlan(dues: _dues(c), today: kToday, amount: i.amount, split: i.split, selected: i.selected);
}

void main() {
  group('controller: ticking months', () {
    test('starts on the oldest open month, nothing ticked by hand', () async {
      final ProviderContainer c = await _setup();
      expect(_input(c).selected, isNull);
      expect(_map(_plan(c)), <YearMonth, int>{_nov: 1000});
    });

    test('months with a gap: November and January, not December', () async {
      final ProviderContainer c = await _setup();
      _ctl(c).toggleMonth(_jan);
      expect(_input(c).selected, <YearMonth>{_nov, _jan});
      final CollectPlan p = _plan(c);
      expect(p.ok, isTrue);
      expect(_map(p), <YearMonth, int>{_nov: 1000, _jan: 1000});
      expect(p.total, 2000);
    });

    test('the amount is the sum of what the ticked months still owe', () async {
      final ProviderContainer c = await _setup(partialNov: 600);
      // November owes 400 after the 600 already paid.
      _ctl(c).toggleMonth(_dec);
      _ctl(c).toggleMonth(_jan);
      final CollectPlan p = _plan(c);
      expect(_map(p), <YearMonth, int>{_nov: 400, _dec: 1000, _jan: 1000});
      expect(p.total, 2400);
      expect(p.partialMonths, isEmpty);
    });

    test('unticking every month leaves nothing to save', () async {
      final ProviderContainer c = await _setup();
      _ctl(c).toggleMonth(_nov);
      expect(_input(c).selected, isEmpty);
      final CollectPlan p = _plan(c);
      expect(p.ok, isFalse);
      expect(p.problem, PlanProblem.noAmount);
      expect(p.total, 0);
    });

    test('typing an amount clears the ticks and spreads from the oldest month', () async {
      final ProviderContainer c = await _setup();
      _ctl(c).toggleMonth(_jan);
      _ctl(c).setAmount('2500');
      expect(_input(c).selected, isNull);
      expect(_map(_plan(c)), <YearMonth, int>{_nov: 1000, _dec: 1000, _jan: 500});
    });

    test('paid months cannot be ticked', () async {
      final ProviderContainer c = await _setup();
      _ctl(c).toggleMonth(_oct);
      _ctl(c).toggleMonth(_sep);
      expect(_input(c).selected, isNull);
      expect(_map(_plan(c)), <YearMonth, int>{_nov: 1000});
      // Nor a month beyond the 12-month horizon.
      _ctl(c).toggleMonth(const YearMonth(2027, 12));
      expect(_input(c).selected, isNull);
    });

    test('more than six months through the grid', () async {
      final ProviderContainer c = await _setup();
      for (YearMonth m = _dec; !m.isAfter(const YearMonth(2027, 7)); m = m.addMonths(1)) {
        _ctl(c).toggleMonth(m);
      }
      final CollectPlan p = _plan(c);
      expect(p.months.length, 9); // November .. July
      expect(p.total, 9000);
      final List<YearMonth> chips = <YearMonth>[
        for (final MonthDue md in chipMonths(_dues(c), kToday, _input(c).selected!)) md.month,
      ];
      expect(chips.first, _sep);
      expect(chips, contains(const YearMonth(2027, 7)));
    });

    test('ticking a month drops a manual split; editing the split drops the ticks', () async {
      final ProviderContainer c = await _setup();
      _ctl(c).setSplit(_nov, 300, <YearMonth, int>{_nov: 1000});
      expect(_input(c).split, isNotNull);
      _ctl(c).toggleMonth(_dec);
      expect(_input(c).split, isNull);
      expect(_input(c).selected, <YearMonth>{_nov, _dec});
      _ctl(c).setSplit(_dec, 500, <YearMonth, int>{_nov: 1000, _dec: 1000});
      expect(_input(c).selected, isNull);
      expect(_map(_plan(c)), <YearMonth, int>{_nov: 1000, _dec: 500});
    });

    test('a manual split ticks from what it pays', () async {
      final ProviderContainer c = await _setup();
      _ctl(c).setSplit(_nov, 300, <YearMonth, int>{_nov: 1000});
      _ctl(c).toggleMonth(_feb);
      expect(_input(c).selected, <YearMonth>{_nov, _feb});
    });
  });

  group('pure rules', () {
    EnrollmentDues dues({bool paid = true}) {
      final EnrollmentTerms terms =
          termsFor(kEnrollments).firstWhere((EnrollmentTerms t) => t.enrollmentId == kEnrRahimPhys);
      return DuesEngine.forEnrollment(
        terms: terms,
        payments: <PaymentFact>[
          if (paid) ...<PaymentFact>[
            const PaymentFact(enrollmentId: kEnrRahimPhys, month: _sep, amount: 1000),
            const PaymentFact(enrollmentId: kEnrRahimPhys, month: _oct, amount: 1000),
          ],
        ],
        today: kToday,
      );
    }

    test('ticked paid months are ignored by the plan', () {
      final CollectPlan p = buildPlan(dues: dues(), today: kToday, selected: <YearMonth>{_oct, _dec});
      expect(_map(p), <YearMonth, int>{_dec: 1000});
      expect(p.pureAdvance, isTrue);
    });

    test('the chips: two paid months before the first open one, six in all', () {
      expect(
        <YearMonth>[for (final MonthDue md in chipMonths(dues(), kToday, const <YearMonth>{})) md.month],
        <YearMonth>[_sep, _oct, _nov, _dec, _jan, _feb],
      );
      expect(
        <YearMonth>[for (final MonthDue md in chipMonths(dues(paid: false), kToday, const <YearMonth>{})) md.month],
        <YearMonth>[_sep, _oct, _nov, _dec, _jan, _feb],
      );
    });

    test('month status words', () {
      final Map<YearMonth, MonthDue> by = <YearMonth, MonthDue>{
        for (final MonthDue md in dues().months) md.month: md,
      };
      expect(payMonthStatus(by[_oct]), PayMonthStatus.paid);
      expect(payMonthStatus(by[_nov]), PayMonthStatus.due);
      expect(payMonthStatus(by[_dec]), PayMonthStatus.notDue);
      expect(payMonthStatus(null), PayMonthStatus.none);
    });
  });
}
