// Fees (dues) and collection screens of the dues feature: the 8-case screen
// matrix (light/dark x bn/en x phone/desktop, fails on any exception incl.
// overflow) plus the behaviour that matters: severity groups and order,
// filters, the grey group, the reminded-today marker, the reminder
// walk-through and the collection numbers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/dues_entry.dart';
import 'package:attendance_alamin/features/dues/ui/collection_screen.dart';
import 'package:attendance_alamin/features/dues/ui/fees_screen.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_empty.dart';
import 'package:attendance_alamin/features/dues/widgets/take_money_picker.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_overview.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_table.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

AppLocalizations _l10n(Lang lang) => lookupAppLocalizations(Locale(lang.code));

EnrollmentTerms _copy(EnrollmentTerms t, {bool? studentLeft, bool? batchArchived}) => EnrollmentTerms(
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
      batchArchived: batchArchived ?? t.batchArchived,
      studentLeft: studentLeft ?? t.studentLeft,
      enrollmentEnded: t.enrollmentEnded,
    );

/// Rahim left (his Physics A November fee is owed in the grey group).
SeededFakes _withLeftRahim() {
  final SeededFakes f = seedFakes();
  for (int i = 0; i < f.enrollments.terms.length; i++) {
    if (f.enrollments.terms[i].studentId == kStuRahim) {
      f.enrollments.terms[i] = _copy(f.enrollments.terms[i], studentLeft: true);
    }
  }
  return f;
}

/// The same fakes with Rahim (and others) already reminded today.
SeededFakes _withReminded(SeededFakes f, Set<String> ids) => SeededFakes(
      store: f.store,
      subjects: f.subjects,
      batches: f.batches,
      schedule: f.schedule,
      students: f.students,
      enrollments: f.enrollments,
      payments: f.payments,
      attendance: f.attendance,
      otherIncome: f.otherIncome,
      settings: f.settings,
      localMeta: FakeLocalMetaRepository(<String, String>{
        LocalMetaKeys.reminded(kToday): encodeReminded(ids),
      }),
    );

SeededFakes _nobodyOwes() {
  final SeededFakes f = seedFakes();
  f.enrollments.terms.clear();
  return f;
}

/// Students are enrolled but billing starts next month (nothing is owed yet).
SeededFakes _billingNotStarted() {
  final SeededFakes f = seedFakes(withPayments: false);
  for (int i = 0; i < f.enrollments.terms.length; i++) {
    final EnrollmentTerms t = f.enrollments.terms[i];
    f.enrollments.terms[i] = EnrollmentTerms(
      enrollmentId: t.enrollmentId,
      studentId: t.studentId,
      batchId: t.batchId,
      studentName: t.studentName,
      batchName: t.batchName,
      subjectName: t.subjectName,
      billing: t.billing,
      start: const YearMonth(2026, 12),
      end: t.end,
      batchFees: t.batchFees,
      overrides: t.overrides,
      batchArchived: t.batchArchived,
      studentLeft: t.studentLeft,
      enrollmentEnded: t.enrollmentEnded,
    );
  }
  return f;
}

SeededFakes _withOtherIncome() {
  final SeededFakes f = seedFakes();
  f.otherIncome.items.add(const OtherIncome(
    id: 'oi1',
    label: 'Exam fee',
    amount: 500,
    paidOn: LocalDate(2026, 11, 10),
    method: PaymentMethod.cash,
  ));
  return f;
}

Finder _row(String studentId) => find.byKey(ValueKey<String>('dues-row-$studentId'));

/// A phone window tall enough to build every row.
Future<void> _tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 2200);
  await tester.pump();
}

Future<void> _pumpFeesPhone(WidgetTester tester, SeededFakes f, {Lang lang = Lang.bn}) async {
  await pumpApp(tester, const FeesScreen(), lang: lang, overrides: f.overrides);
  await _tall(tester);
}

void main() {
  // ---- the 8-case matrix -----------------------------------------------------
  testScreenMatrix('fees', () => const FeesScreen(), overrides: () => seedFakes().overrides);

  testScreenMatrix(
    'fees, a student selected',
    () => const FeesScreen(selectedStudentId: kStuRahim),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'fees, nobody owes',
    () => const FeesScreen(),
    overrides: () => _nobodyOwes().overrides,
  );

  testScreenMatrix(
    'fees, left student in the grey group',
    () => const FeesScreen(),
    overrides: () => _withLeftRahim().overrides,
  );

  testScreenMatrix(
    'fees, reminded today',
    () => const FeesScreen(),
    overrides: () => _withReminded(seedFakes(), <String>{kStuRahim, kStuNila}).overrides,
  );

  testScreenMatrix('collection', () => const CollectionScreen(), overrides: () => seedFakes().overrides);

  testScreenMatrix(
    'collection with other income',
    () => const CollectionScreen(),
    overrides: () => _withOtherIncome().overrides,
  );

  testScreenMatrix(
    'collection, empty',
    () => const CollectionScreen(),
    overrides: () => _nobodyOwes().overrides,
  );

  testScreenMatrix(
    'batch fees tab',
    () => const Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: BatchFeesTab(batchId: kBatPhysA),
      ),
    ),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'batch fees tab, no students',
    () => const Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: BatchFeesTab(batchId: 'empty-batch'),
      ),
    ),
    overrides: () => seedFakes().overrides,
  );

  // ---- dues list behaviour (phone) ---------------------------------------------
  group('dues list', () {
    testWidgets('overdue group first, rows by open months, total, name', (WidgetTester tester) async {
      await _pumpFeesPhone(tester, seedFakes());
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.text(l10n.duesHeadline('৩', '৩')), findsWidgets, reason: '3 unpaid, 3 overdue');
      expect(find.byType(SeverityBadge), findsWidgets);
      // All three owe one overdue month: Rahim 1000 and Nila 1000 (name order),
      // then Sara's 800.
      final double nila = tester.getTopLeft(_row(kStuNila)).dy;
      final double rahim = tester.getTopLeft(_row(kStuRahim)).dy;
      final double sara = tester.getTopLeft(_row(kStuSara)).dy;
      expect(nila, lessThan(rahim));
      expect(rahim, lessThan(sara));
      expect(find.text('৳ ১,০০০'), findsWidgets);
      expect(find.text('৳ ৮০০'), findsWidgets);
    });

    testWidgets('this-month filter drops Sara (her open month is October)', (WidgetTester tester) async {
      await _pumpFeesPhone(tester, seedFakes());
      expect(_row(kStuSara), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('dues-filter-month')));
      await tester.pump();
      expect(_row(kStuRahim), findsOneWidget);
      expect(_row(kStuNila), findsOneWidget);
      expect(_row(kStuSara), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('dues-filter-all')));
      await tester.pump();
      expect(_row(kStuSara), findsOneWidget);
    });

    testWidgets('overdue filter keeps the overdue students', (WidgetTester tester) async {
      await _pumpFeesPhone(tester, seedFakes());
      await tester.tap(find.byKey(const ValueKey<String>('dues-filter-overdue')));
      await tester.pump();
      expect(_row(kStuRahim), findsOneWidget);
      expect(_row(kStuSara), findsOneWidget);
    });

    testWidgets('batch filter, and the empty result offers "show all"', (WidgetTester tester) async {
      await _pumpFeesPhone(tester, seedFakes(), lang: Lang.en);
      final ProviderContainer c = containerOf(tester);
      c.read(duesFilterProvider.notifier).setBatch(kBatChemB);
      await tester.pump();
      expect(_row(kStuSara), findsOneWidget);
      expect(_row(kStuRahim), findsNothing);
      c.read(duesFilterProvider.notifier).setBatch('no-such-batch');
      await tester.pump();
      final AppLocalizations l10n = _l10n(Lang.en);
      expect(find.text(l10n.duesNoMatch), findsOneWidget);
      await tester.tap(find.text(l10n.duesShowAll));
      await tester.pump();
      expect(_row(kStuRahim), findsOneWidget);
      expect(c.read(duesFilterProvider).isDefault, isTrue);
    });

    testWidgets('the month filter from the collection summary shows as a chip', (WidgetTester tester) async {
      await _pumpFeesPhone(tester, seedFakes(), lang: Lang.en);
      containerOf(tester).read(duesFilterProvider.notifier).setMonth(const YearMonth(2026, 10));
      await tester.pump();
      final AppLocalizations l10n = _l10n(Lang.en);
      expect(find.text(l10n.duesFilterMonth('October 2026')), findsOneWidget);
      // Only Sara's Chem B October fee is open.
      expect(_row(kStuSara), findsOneWidget);
      expect(_row(kStuRahim), findsNothing);
    });

    testWidgets('left students sit in a collapsed grey group without severity', (WidgetTester tester) async {
      await _pumpFeesPhone(tester, _withLeftRahim());
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.text(l10n.duesInactiveGroup), findsOneWidget);
      expect(_row(kStuRahim), findsNothing, reason: 'collapsed by default');
      // He is no longer counted as unpaid (2) / overdue (2).
      expect(find.text(l10n.duesHeadline('২', '২')), findsWidgets);
      await tester.tap(find.byTooltip(l10n.duesExpand));
      await tester.pump();
      expect(_row(kStuRahim), findsOneWidget);
      expect(
        find.descendant(of: _row(kStuRahim), matching: find.byType(SeverityBadge)),
        findsNothing,
      );
      expect(find.descendant(of: _row(kStuRahim), matching: find.text(l10n.duesReasonLeft)), findsOneWidget);
    });

    testWidgets('reminded-today marker replaces the Remind label', (WidgetTester tester) async {
      await _pumpFeesPhone(tester, _withReminded(seedFakes(), <String>{kStuRahim}));
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(
        find.descendant(of: _row(kStuRahim), matching: find.text(l10n.duesRemindedToday)),
        findsOneWidget,
      );
      expect(find.descendant(of: _row(kStuRahim), matching: find.text(l10n.duesRemind)), findsNothing);
      expect(
        find.descendant(of: _row(kStuNila), matching: find.text(l10n.duesRemind)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row(kStuNila), matching: find.text(l10n.duesRemindedToday)),
        findsNothing,
      );
    });

    testWidgets('no students at all: "no dues", never "everyone paid"', (WidgetTester tester) async {
      await _pumpFeesPhone(tester, _nobodyOwes(), lang: Lang.en);
      expect(find.text(_l10n(Lang.en).duesNoneYet), findsOneWidget);
      expect(find.text(_l10n(Lang.en).duesAllPaid), findsNothing);
    });

    testWidgets('billing has not started: says when it starts, never "everyone paid"',
        (WidgetTester tester) async {
      await _pumpFeesPhone(tester, _billingNotStarted());
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.text(l10n.duesNotStarted('ডিসেম্বর ২০২৬')), findsOneWidget);
      expect(find.text(l10n.duesAllPaid), findsNothing);
      expect(find.text(l10n.duesSeeStudents), findsOneWidget);
    });

    testWidgets('the everyone-paid message needs fees billed this month', (WidgetTester tester) async {
      await pumpApp(
        tester,
        Builder(
          builder: (BuildContext c) => Column(
            children: <Widget>[
              Text(duesEmptyMessage(c, const BillingStatus(hasEnrollments: true, billedThisMonth: true))),
              Text(duesEmptyMessage(c, const BillingStatus(hasEnrollments: true))),
            ],
          ),
        ),
        overrides: seedFakes().overrides,
      );
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.text(l10n.duesAllPaid), findsOneWidget);
      expect(find.text(l10n.duesNoneYet), findsOneWidget);
    });

    testWidgets('call and collect are on every row', (WidgetTester tester) async {
      await _pumpFeesPhone(tester, seedFakes());
      for (final String id in <String>[kStuRahim, kStuNila, kStuSara]) {
        expect(find.byKey(ValueKey<String>('dues-call-$id')), findsOneWidget);
        expect(find.byKey(ValueKey<String>('dues-remind-$id')), findsOneWidget);
        expect(find.byKey(ValueKey<String>('dues-collect-$id')), findsOneWidget);
      }
    });
  });

  group('reminder walk-through', () {
    testWidgets('steps through the students who are not reminded yet', (WidgetTester tester) async {
      await _pumpFeesPhone(tester, _withReminded(seedFakes(), <String>{kStuRahim}));
      final AppLocalizations l10n = _l10n(Lang.bn);
      await tester.tap(find.byKey(const ValueKey<String>('dues-remind-all')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.duesWalkTitle), findsOneWidget);
      // Rahim was reminded already: Nila and Sara are left.
      expect(find.text(l10n.duesWalkProgress('১', '২')), findsOneWidget);
      expect(find.textContaining('নীলা বেগম'), findsWidgets);
      await tester.tap(find.text(l10n.duesWalkSkip));
      await tester.pumpAndSettle();
      expect(find.text(l10n.duesWalkProgress('২', '২')), findsOneWidget);
      expect(find.textContaining('সারা আক্তার'), findsWidgets);
      await tester.tap(find.text(l10n.duesWalkSkip));
      await tester.pumpAndSettle();
      expect(find.text(l10n.duesWalkDone('০')), findsOneWidget);
      await tester.tap(find.text(l10n.commonDone));
      await tester.pumpAndSettle();
      expect(find.text(l10n.duesWalkTitle), findsNothing);
    });

    testWidgets('everybody already reminded: says so instead of opening', (WidgetTester tester) async {
      await _pumpFeesPhone(
        tester,
        _withReminded(seedFakes(), <String>{kStuRahim, kStuNila, kStuSara}),
      );
      final AppLocalizations l10n = _l10n(Lang.bn);
      await tester.tap(find.byKey(const ValueKey<String>('dues-remind-all')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l10n.duesWalkNobody), findsOneWidget);
      expect(find.text(l10n.duesWalkTitle), findsNothing);
      // Let the snackbar's own timer run out.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });

  // ---- desktop layout ----------------------------------------------------------
  group('take money', () {
    testWidgets('the Fees tab has a take-money button that opens the picker, then the collect sheet',
        (WidgetTester tester) async {
      await _pumpFeesPhone(tester, seedFakes());
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.byKey(const ValueKey<String>('fees-take-money')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('fees-take-money')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.duesPickerTitle), findsOneWidget);
      // Search by a Bangla-digit phone prefix.
      await tester.enterText(find.byKey(const ValueKey<String>('picker-search')), '০১৭১১২');
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey<String>('picker-$kStuRahim')), findsOneWidget);
      expect(find.byKey(ValueKey<String>('picker-$kStuNila')), findsNothing);
      await tester.tap(find.byKey(ValueKey<String>('picker-$kStuRahim')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('pay-amount')), findsOneWidget);
    });

    test('picker search matches name, roll and phone in either digit style', () {
      final Student rahim = kStudents.first;
      expect(pickerMatches(rahim, '০১৭১১'), isTrue);
      expect(pickerMatches(rahim, '01711'), isTrue);
      expect(pickerMatches(rahim, 'রহিম'), isTrue);
      expect(pickerMatches(rahim, '9'), isFalse);
    });

    testWidgets('the other-income action lives in a labelled menu', (WidgetTester tester) async {
      await pumpApp(tester, const CollectionScreen(), overrides: seedFakes().overrides);
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.byIcon(Icons.add_card_outlined), findsNothing);
      await tester.tap(find.byKey(const Key('coll-menu')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.collOtherIncomeMenu), findsOneWidget);
    });
  });

  group('desktop', () {
    testWidgets('large window: dues table beside the payment panel', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const FeesScreen(selectedStudentId: kStuRahim),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.byType(DuesTable), findsOneWidget);
      expect(find.byType(CollectPaymentPanel), findsOneWidget);
      expect(find.text(l10n.duesColName), findsOneWidget);
      expect(find.text(l10n.duesColStatus), findsOneWidget);
      expect(find.text(l10n.duesColActions), findsOneWidget);
      final Rect table = tester.getRect(find.byType(DuesTable));
      final Rect panel = tester.getRect(find.byType(CollectPaymentPanel));
      expect(table.right, lessThanOrEqualTo(panel.left + 1));
    });

    testWidgets('nothing selected: the overview fills the detail pane', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const FeesScreen(),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      expect(find.byType(DuesOverview), findsOneWidget);
      expect(find.byType(CollectPaymentPanel), findsNothing);
      expect(find.byType(EscalationBar), findsOneWidget);
    });
  });

  // ---- collection --------------------------------------------------------------
  group('collection', () {
    testWidgets('November: expected, received, outstanding and the batches', (WidgetTester tester) async {
      await pumpApp(tester, const CollectionScreen(), overrides: seedFakes().overrides);
      await _tall(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.text(l10n.collBillingBlock('নভেম্বর ২০২৬')), findsOneWidget);
      expect(find.text('৳ ৪,৬০০'), findsOneWidget, reason: 'expected');
      expect(find.text('৳ ৩,৬০০'), findsOneWidget, reason: 'outstanding');
      expect(find.text(l10n.collByBatch), findsOneWidget);
      expect(find.text(l10n.collCashBlock('নভেম্বর ২০২৬')), findsOneWidget);
      // One receipt in November: Sara paid ৳1,000 by bKash on 2 November.
      expect(find.byKey(const ValueKey<String>('coll-receipt-rcp-4')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('coll-other-income')), findsNothing);
    });

    testWidgets('tapping a payment row opens its receipt with edit and delete (QA-14)',
        (WidgetTester tester) async {
      await pumpApp(tester, const CollectionScreen(), overrides: seedFakes().overrides);
      await _tall(tester);
      await tester.tap(find.byKey(const ValueKey<String>('coll-receipt-open-rcp-4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey<String>('pay-receipt-text')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pay-receipt-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pay-receipt-delete')), findsOneWidget);
    });

    testWidgets('the other-income line appears only when there is some', (WidgetTester tester) async {
      await pumpApp(tester, const CollectionScreen(), overrides: _withOtherIncome().overrides);
      await _tall(tester);
      expect(find.byKey(const ValueKey<String>('coll-other-income')), findsOneWidget);
      expect(find.text('৳ ৫০০'), findsOneWidget);
      expect(find.text('৳ ১,৫০০'), findsOneWidget, reason: 'fees 1000 + other income 500');
    });

    testWidgets('stepping back shows October; the next arrow is off on the current month',
        (WidgetTester tester) async {
      await pumpApp(tester, const CollectionScreen(), overrides: seedFakes().overrides);
      await _tall(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      IconButton next() =>
          tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(next().onPressed, isNull);
      await tester.tap(find.byTooltip(l10n.collPrevMonth));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l10n.collBillingBlock('অক্টোবর ২০২৬')), findsOneWidget);
      expect(find.text('৳ ২,৮০০'), findsOneWidget, reason: 'October expected');
      expect(next().onPressed, isNotNull);
    });

    testWidgets('outstanding opens the dues list filtered to that month', (WidgetTester tester) async {
      await pumpApp(tester, const CollectionScreen(), overrides: seedFakes().overrides);
      await _tall(tester);
      await tester.tap(find.byKey(const ValueKey<String>('coll-outstanding')));
      await tester.pump();
      final DuesFilter filter = containerOf(tester).read(duesFilterProvider);
      expect(filter.month, const YearMonth(2026, 11));
    });
  });
}
