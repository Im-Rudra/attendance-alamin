// Other income (F22): the sheet in the 8-case matrix, saving a labelled
// one-off payment (record only, no dues), the snackbar with undo, and the
// receipt text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/features/extras/controllers/other_income_text.dart';
import 'package:attendance_alamin/features/extras/extras_entry.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

const ValueKey<String> _label = ValueKey<String>('income-label');
const ValueKey<String> _amount = ValueKey<String>('income-amount');
const ValueKey<String> _save = ValueKey<String>('income-save');

bool? _result;

/// A page with one button that opens the sheet, like a real caller.
Widget _host({String? studentId}) => Scaffold(
      body: Center(
        child: Builder(
          builder: (BuildContext context) => ElevatedButton(
            key: const ValueKey<String>('open-income'),
            onPressed: () async {
              _result = await showOtherIncomeSheet(context, studentId: studentId);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('open-income')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final AppLocalizations bn = lookupAppLocalizations(const Locale('bn'));

  setUp(() => _result = null);

  testScreenMatrix(
    'other income sheet: opens with the quick labels',
    () => _host(studentId: kStuRahim),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await _open(tester);
      expect(find.byKey(_label), findsOneWidget);
      expect(find.byKey(_amount), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('income-method-cash')), findsOneWidget);
      expect(find.byType(ActionChip), findsNWidgets(3));
      // Student line is filled once the student loads.
      expect(find.textContaining('রহিম উদ্দিন'), findsOneWidget);
    },
  );

  testWidgets('save is disabled until label and amount are there', (WidgetTester tester) async {
    await pumpApp(tester, _host(), overrides: seedFakes().overrides);
    await _open(tester);
    await tester.ensureVisible(find.byKey(_save));
    expect(tester.widget<FilledButton>(find.byKey(_save)).onPressed, isNull);
    expect(find.text(bn.extraIncomeDisabledLabel), findsOneWidget);

    await tester.enterText(find.byKey(_label), 'পরীক্ষার ফি');
    await tester.pump();
    expect(find.text(bn.payDisabledAmount), findsOneWidget);

    await tester.enterText(find.byKey(_amount), '০');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(_save)).onPressed, isNull, reason: 'zero is not income');

    await tester.enterText(find.byKey(_amount), '৫০০');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(_save)).onPressed, isNotNull);
  });

  testWidgets('an amount above the maximum shows an inline message (QA-13)', (WidgetTester tester) async {
    await pumpApp(tester, _host(), overrides: seedFakes().overrides);
    await _open(tester);
    await tester.enterText(find.byKey(_label), 'পরীক্ষার ফি');
    await tester.enterText(find.byKey(_amount), '9999999999');
    await tester.pump();
    expect(find.text(bn.errAmountTooLarge), findsOneWidget);
    await tester.ensureVisible(find.byKey(_save));
    expect(tester.widget<FilledButton>(find.byKey(_save)).onPressed, isNull);

    await tester.enterText(find.byKey(_amount), '2000000');
    await tester.pump();
    expect(find.text(bn.errAmountTooLarge), findsOneWidget);

    await tester.enterText(find.byKey(_amount), '500');
    await tester.pump();
    expect(find.text(bn.errAmountTooLarge), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(_save)).onPressed, isNotNull);
  });

  testWidgets('saving records a labelled one-off payment with no dues, undo removes it',
      (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, _host(studentId: kStuKarim), overrides: f.overrides);
    await _open(tester);

    await tester.enterText(find.byKey(_label), 'ভর্তি ফি');
    await tester.enterText(find.byKey(_amount), '৫০০');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('income-method-bkash')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(_save));
    await tester.tap(find.byKey(_save));
    await _settle(tester);

    expect(_result, isTrue);
    expect(f.otherIncome.items, hasLength(1));
    final OtherIncome saved = f.otherIncome.items.single;
    expect(saved.label, 'ভর্তি ফি');
    expect(saved.amount, 500);
    expect(saved.method, PaymentMethod.bkash);
    expect(saved.studentId, kStuKarim);
    expect(saved.paidOn, kToday);

    // Snackbar names the amount and label; it never touches payments.
    expect(find.text(bn.extraIncomeSaved('৳ ৫০০', 'ভর্তি ফি')), findsOneWidget);
    expect(f.payments.payments.length, kPayments.length);

    await tester.tap(find.text(bn.commonUndo));
    await _settle(tester);
    expect(f.otherIncome.items, isEmpty);
  });

  testWidgets('closing the sheet saves nothing', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, _host(), overrides: f.overrides);
    await _open(tester);
    await tester.enterText(find.byKey(_label), 'নোট');
    await tester.tap(find.byTooltip(bn.commonClose));
    await _settle(tester);
    expect(_result, isFalse);
    expect(f.otherIncome.items, isEmpty);
  });

  group('receipt text', () {
    const OtherIncome income = OtherIncome(
      id: 'o1',
      label: 'পরীক্ষার ফি',
      amount: 1200,
      paidOn: LocalDate(2026, 11, 20),
      method: PaymentMethod.cash,
      studentId: kStuSara,
    );

    test('Bangla receipt lists label, amount, date, method and student', () {
      final String text = otherIncomeReceiptText(
        l10n: bn,
        fmt: const AppFormat(Lang.bn),
        income: income,
        methodLabel: 'নগদ টাকা',
        centerName: 'আলো কোচিং',
        studentName: 'সারা আক্তার',
      );
      final List<String> lines = text.split('\n');
      expect(lines.first, 'আলো কোচিং');
      expect(lines[1], 'রসিদ — পরীক্ষার ফি');
      expect(lines[2], 'টাকা: ৳ ১,২০০');
      expect(lines[3], 'তারিখ: ২০ নভেম্বর ২০২৬');
      expect(lines[4], 'পদ্ধতি: নগদ টাকা');
      expect(lines[5], 'শিক্ষার্থী: সারা আক্তার');
      expect(lines.last, 'ধন্যবাদ');
    });

    test('no centre name and no student leaves those lines out', () {
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
      final String text = otherIncomeReceiptText(
        l10n: en,
        fmt: const AppFormat(Lang.en),
        income: income,
        methodLabel: 'Cash',
      );
      expect(text.split('\n'), <String>[
        'Receipt — পরীক্ষার ফি',
        'Amount: ৳ 1,200',
        'Date: 20 Nov 2026',
        'Method: Cash',
        'Thank you',
      ]);
    });
  });
}
