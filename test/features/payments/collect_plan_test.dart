// The allocation rule, the month wording and the receipt text of the payments
// feature (Product 3.4, plan 1 #35, scenarios 4, 5, 7). Pure tests.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/templates/default_templates.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/features/payments/controllers/collect_payment_controller.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/receipt_text.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

List<PaymentFact> _facts(List<Payment> payments) => <PaymentFact>[
      for (final Payment p in payments)
        PaymentFact(
            enrollmentId: p.enrollmentId,
            month: p.billingMonth,
            amount: p.amount,
            waived: p.waived),
    ];

EnrollmentDues _dues(String enrollmentId, List<Payment> payments) {
  final EnrollmentTerms terms =
      termsFor(kEnrollments).firstWhere((EnrollmentTerms t) => t.enrollmentId == enrollmentId);
  return DuesEngine.forEnrollment(
      terms: terms, payments: _facts(payments), today: kToday, aheadMonths: 12);
}

const YearMonth _sep = YearMonth(2026, 9);
const YearMonth _oct = YearMonth(2026, 10);
const YearMonth _nov = YearMonth(2026, 11);
const YearMonth _dec = YearMonth(2026, 12);
const YearMonth _jan = YearMonth(2027, 1);

Map<YearMonth, int> _map(CollectPlan p) => <YearMonth, int>{
      for (final Allocation a in p.allocations) a.month: a.amount,
    };

void main() {
  group('buildPlan', () {
    // Rahim (Physics A, 1000, prepaid, from Sep) paid Sep and Oct: Nov is the
    // oldest open month and it is already due on 2026-11-21.
    final EnrollmentDues rahim = _dues(kEnrRahimPhys, kPayments);
    // Nothing paid: Sep, Oct and Nov are all open.
    final EnrollmentDues rahimNone = _dues(kEnrRahimPhys, const <Payment>[]);

    test('prefill is the remaining of the oldest open month', () {
      final CollectPlan p = buildPlan(dues: rahim, today: kToday);
      expect(p.prefill, 1000);
      expect(p.ok, isTrue);
      expect(_map(p), <YearMonth, int>{_nov: 1000});
      expect(p.partialMonths, isEmpty);
      expect(p.advanceMonths, isEmpty);
      expect(p.pureAdvance, isFalse);
    });

    test('scenario 4: 600 for November leaves 400 and is partial', () {
      final CollectPlan p = buildPlan(dues: rahim, today: kToday, amount: 600);
      expect(_map(p), <YearMonth, int>{_nov: 600});
      expect(p.partialMonths, <YearMonth>[_nov]);
      expect(p.partialLeft, 400);
    });

    test('scenario 4: after 600, the next prefill is the 400 that remains', () {
      final Payment part = Payment(
        id: 'p',
        receiptId: 'r',
        studentId: kStuRahim,
        enrollmentId: kEnrRahimPhys,
        batchId: kBatPhysA,
        billingMonth: _nov,
        amount: 600,
        paidOn: kToday,
        method: PaymentMethod.cash,
      );
      final EnrollmentDues after = _dues(kEnrRahimPhys, <Payment>[...kPayments, part]);
      final CollectPlan p = buildPlan(dues: after, today: kToday);
      expect(p.prefill, 400);
      expect(_map(p), <YearMonth, int>{_nov: 400});
      expect(p.partialMonths, isEmpty);
    });

    test('scenario 5: 2500 over Sep, Oct, Nov leaves November partial by 500', () {
      final CollectPlan p = buildPlan(dues: rahimNone, today: kToday, amount: 2500);
      expect(_map(p), <YearMonth, int>{_sep: 1000, _oct: 1000, _nov: 500});
      expect(p.total, 2500);
      expect(p.partialMonths, <YearMonth>[_nov]);
      expect(p.partialLeft, 500);
    });

    test('more than the due months goes forward as advance', () {
      final CollectPlan p = buildPlan(dues: rahim, today: kToday, amount: 2500);
      expect(_map(p), <YearMonth, int>{_nov: 1000, _dec: 1000, _jan: 500});
      expect(p.advanceMonths, <YearMonth>[_dec, _jan]);
      expect(p.advanceTotal, 1500);
      expect(p.pureAdvance, isFalse);
    });

    test('only not-yet-due months is a pure advance', () {
      // Karim (Chem B, postpaid, from Nov): November is due on 1 December.
      final EnrollmentDues karim = _dues(kEnrKarimChem, const <Payment>[]);
      final CollectPlan p = buildPlan(dues: karim, today: kToday);
      expect(p.prefill, 800);
      expect(p.pureAdvance, isTrue);
    });

    test('exactly the 12-month horizon is accepted, one taka more is not', () {
      // Open months Nov 2026 .. Nov 2027 = 13 months of 1000.
      final CollectPlan fits = buildPlan(dues: rahim, today: kToday, amount: 13000);
      expect(fits.ok, isTrue);
      expect(fits.maxPlaceable, 13000);
      final CollectPlan over = buildPlan(dues: rahim, today: kToday, amount: 13001);
      expect(over.ok, isFalse);
      expect(over.problem, PlanProblem.overflow);
      expect(over.maxPlaceable, 13000);
      expect(over.allocations, isEmpty);
    });

    test('empty or zero amount has no plan', () {
      expect(buildPlan(dues: rahim, today: kToday, amount: 0).problem, PlanProblem.noAmount);
    });

    test('nothing open: every month paid up to the end of the enrollment', () {
      final EnrollmentTerms base =
          termsFor(kEnrollments).firstWhere((EnrollmentTerms t) => t.enrollmentId == kEnrKarimChem);
      final EnrollmentTerms ended = EnrollmentTerms(
        enrollmentId: base.enrollmentId,
        studentId: base.studentId,
        batchId: base.batchId,
        studentName: base.studentName,
        batchName: base.batchName,
        subjectName: base.subjectName,
        billing: base.billing,
        start: _nov,
        end: _nov,
        batchFees: <FeePeriod>[const FeePeriod(effective: YearMonth(2026, 1), amount: 800)],
      );
      final EnrollmentDues dues = DuesEngine.forEnrollment(
        terms: ended,
        payments: const <PaymentFact>[
          PaymentFact(enrollmentId: kEnrKarimChem, month: _nov, amount: 800),
        ],
        today: kToday,
      );
      final CollectPlan p = buildPlan(dues: dues, today: kToday, amount: 100);
      expect(p.problem, PlanProblem.nothingOpen);
    });

    group('manual split', () {
      test('a month cannot get more than it still owes', () {
        final CollectPlan p = buildPlan(
            dues: rahim, today: kToday, split: <YearMonth, int>{_nov: 1500});
        expect(p.problem, PlanProblem.splitExceeds);
        expect(p.ok, isFalse);
      });

      test('a valid split sets the total', () {
        final CollectPlan p = buildPlan(
            dues: rahim, today: kToday, split: <YearMonth, int>{_nov: 400, _dec: 1000});
        expect(p.ok, isTrue);
        expect(p.total, 1400);
        expect(p.partialMonths, <YearMonth>[_nov]);
        expect(p.partialLeft, 600);
      });

      test('a paid month takes nothing', () {
        final CollectPlan p =
            buildPlan(dues: rahim, today: kToday, split: <YearMonth, int>{_oct: 100});
        expect(p.problem, PlanProblem.splitExceeds);
      });

      test('an empty split is no amount', () {
        final CollectPlan p =
            buildPlan(dues: rahim, today: kToday, split: <YearMonth, int>{_nov: 0});
        expect(p.problem, PlanProblem.noAmount);
      });

      test('a month beyond 12 months is the overflow message', () {
        final CollectPlan p = buildPlan(
            dues: rahim,
            today: kToday,
            split: <YearMonth, int>{const YearMonth(2027, 12): 100});
        expect(p.problem, PlanProblem.overflow);
      });
    });
  });

  group('payment method default', () {
    test('cash when it is shown, else the first shown', () {
      expect(defaultMethod(PaymentMethod.builtIns), PaymentMethod.cash);
      expect(defaultMethod(<PaymentMethod>[PaymentMethod.bkash, PaymentMethod.nagad]),
          PaymentMethod.bkash);
    });
  });

  group('sortChoices', () {
    test('the enrollment owing the oldest month comes first', () {
      final EnrollmentDues rahim = _dues(kEnrRahimPhys, kPayments);
      final EnrollmentDues sara = _dues(kEnrSaraChem, const <Payment>[]);
      final List<EnrollmentDues> sorted = sortChoices(<EnrollmentDues>[rahim, sara]);
      expect(sorted.first.terms.enrollmentId, kEnrSaraChem);
    });
  });

  group('month wording', () {
    const AppFormat bn = AppFormat(Lang.bn);
    const AppFormat en = AppFormat(Lang.en);

    test('consecutive months become a range, others a list', () {
      expect(monthsSpan(bn, <YearMonth>[_oct], currentYear: 2026), 'অক্টোবর');
      expect(monthsSpan(bn, <YearMonth>[_sep, _oct, _nov], currentYear: 2026), 'সেপ্টেম্বর–নভেম্বর');
      expect(monthsSpan(en, <YearMonth>[_oct, _dec], currentYear: 2026), 'October, December');
      expect(monthsSpan(en, <YearMonth>[_dec, _jan], currentYear: 2026), 'December–January 2027');
    });

    test('Bangla possessive endings', () {
      expect(possessive('অক্টোবর', bangla: true), 'অক্টোবরের');
      expect(possessive('জানুয়ারি', bangla: true), 'জানুয়ারির');
      expect(possessive('জুলাই', bangla: true), 'জুলাইয়ের');
      expect(possessive('মে', bangla: true), 'মের');
      expect(possessive('ডিসেম্বর ২০২৭', bangla: true), 'ডিসেম্বর ২০২৭-এর');
      expect(possessive('October', bangla: false), 'October');
    });
  });

  group('receipt text', () {
    final List<Payment> rows = <Payment>[
      for (final (YearMonth m, int a) in <(YearMonth, int)>[(_sep, 1000), (_oct, 1000), (_nov, 500)])
        Payment(
          id: 'p-${m.toInt()}',
          receiptId: 'rcp',
          studentId: kStuRahim,
          enrollmentId: kEnrRahimPhys,
          batchId: kBatPhysA,
          billingMonth: m,
          amount: a,
          paidOn: kToday,
          method: PaymentMethod.cash,
        ),
    ];
    final ReceiptFacts facts = ReceiptFacts(
      studentName: 'রহিম উদ্দিন',
      roll: '12',
      batchName: 'ফিজিক্স এ',
      rows: rows,
      partialMonths: <YearMonth>{_nov},
      remaining: 500,
    );

    String render(Lang lang, {String center = 'আপনার কোচিং', ReceiptFacts? f}) {
      final AppLocalizations l10n = lookupAppLocalizations(Locale(lang.code));
      return renderReceiptText(
        facts: f ?? facts,
        template: DefaultTemplates.receipt(lang),
        center: center,
        fmt: AppFormat(lang),
        l10n: l10n,
        today: kToday,
        methodLabel: lang == Lang.bn ? 'ক্যাশ' : 'Cash',
        paidOn: kToday,
      );
    }

    test('scenario 5, Bangla: months with (আংশিক), Bangla digits, remaining line', () {
      final String t = render(Lang.bn);
      expect(t, contains('রসিদ — আপনার কোচিং'));
      expect(t, contains('শিক্ষার্থী: রহিম উদ্দিন (১২)'));
      expect(t, contains('মাস: সেপ্টেম্বর, অক্টোবর, নভেম্বর (আংশিক)'));
      expect(t, contains('জমা: ৳২,৫০০ (ক্যাশ), তারিখ ২১ নভেম্বর ২০২৬'));
      expect(t, contains('বাকি: ৳ ৫০০'));
      expect(RegExp(r'[0-9]').hasMatch(t), isFalse);
    });

    test('English uses Latin digits and the English words', () {
      final String t = render(Lang.en);
      expect(t, contains('Receipt — আপনার কোচিং'));
      expect(t, contains('Months: September, October, November (partial)'));
      expect(t, contains('Paid: ৳2,500 (Cash), date 21 Nov 2026'));
      expect(t, contains('Remaining: ৳ 500'));
      expect(RegExp(r'[০-৯]').hasMatch(t), isFalse);
    });

    test('nothing due gives the all-paid line', () {
      final ReceiptFacts paid = ReceiptFacts(
        studentName: facts.studentName,
        roll: facts.roll,
        batchName: facts.batchName,
        rows: rows,
        partialMonths: const <YearMonth>{},
        remaining: 0,
      );
      expect(render(Lang.bn, f: paid), contains('সব বেতন পরিশোধিত ✓'));
      expect(render(Lang.en, f: paid), contains('All fees paid ✓'));
    });

    test('a missing center or roll leaves no empty brackets', () {
      final ReceiptFacts noRoll = ReceiptFacts(
        studentName: facts.studentName,
        batchName: facts.batchName,
        rows: rows,
        partialMonths: facts.partialMonths,
        remaining: 500,
      );
      final String t = render(Lang.bn, center: '', f: noRoll);
      expect(t, contains('রসিদ\n'));
      expect(t, contains('শিক্ষার্থী: রহিম উদ্দিন\n'));
      expect(t, isNot(contains('()')));
    });

    test('a custom template is used as written', () {
      final String t = renderReceiptText(
        facts: facts,
        template: '{student}: {amount} / {months} / {remaining_line}',
        center: '',
        fmt: const AppFormat(Lang.en),
        l10n: lookupAppLocalizations(const Locale('en')),
        today: kToday,
        methodLabel: 'Cash',
        paidOn: kToday,
      );
      expect(t, 'রহিম উদ্দিন: 2,500 / September, October, November (partial) / Remaining: ৳ 500');
    });
  });

  group('slip number', () {
    test('{receipt_no} is the slip number in the app digits; none leaves no brackets', () {
      final List<Payment> base = <Payment>[
        Payment(
          id: 'p1',
          receiptId: 'r1',
          studentId: kStuRahim,
          enrollmentId: kEnrRahimPhys,
          batchId: kBatPhysA,
          billingMonth: _nov,
          amount: 1000,
          paidOn: kToday,
          method: PaymentMethod.cash,
        ),
      ];
      ReceiptFacts withNo(String? no) => ReceiptFacts(
            studentName: 'রহিম উদ্দিন',
            batchName: 'Physics A',
            rows: <Payment>[
              for (final Payment p in base)
                Payment(
                  id: p.id,
                  receiptId: p.receiptId,
                  studentId: p.studentId,
                  enrollmentId: p.enrollmentId,
                  batchId: p.batchId,
                  billingMonth: p.billingMonth,
                  amount: p.amount,
                  paidOn: p.paidOn,
                  method: p.method,
                  receiptNo: no,
                ),
            ],
            partialMonths: const <YearMonth>{},
            remaining: 0,
          );
      String slip(Lang lang, ReceiptFacts f) => renderReceiptText(
            facts: f,
            template: 'Slip ({receipt_no}) for {student}',
            center: '',
            fmt: AppFormat(lang),
            l10n: lookupAppLocalizations(Locale(lang == Lang.bn ? 'bn' : 'en')),
            today: kToday,
            methodLabel: 'Cash',
            paidOn: kToday,
          );
      expect(withNo('2026-0007').receiptNo, '2026-0007');
      expect(withNo(null).receiptNo, '');
      expect(slip(Lang.en, withNo('2026-0007')), 'Slip (2026-0007) for রহিম উদ্দিন');
      expect(slip(Lang.bn, withNo('2026-0007')), 'Slip (২০২৬-০০০৭) for রহিম উদ্দিন');
      expect(slip(Lang.en, withNo(null)), 'Slip for রহিম উদ্দিন');
    });
  });

  group('edit dues exclude the receipt\'s own rows', () {
    test('November is paid with the receipt and open again without it', () async {
      final SeededFakes fakes = seedFakes();
      final String receiptId = await fakes.payments.record(PaymentDraft(
        studentId: kStuRahim,
        enrollmentId: kEnrRahimPhys,
        allocations: const <Allocation>[Allocation(month: _nov, amount: 1000)],
        paidOn: kToday,
        method: PaymentMethod.cash,
      ));
      final container = makeContainer(overrides: fakes.overrides);
      final EnrollmentDues? withReceipt = await readData(
          container, payDuesProvider((enrollmentId: kEnrRahimPhys, receiptId: null)));
      final EnrollmentDues? without = await readData(
          container, payDuesProvider((enrollmentId: kEnrRahimPhys, receiptId: receiptId)));
      MonthDue month(EnrollmentDues d) => d.months.firstWhere((MonthDue m) => m.month == _nov);
      expect(month(withReceipt!).state, MonthState.paid);
      expect(month(without!).state, MonthState.unpaid);
      expect(month(without).remaining, 1000);
    });
  });
}
