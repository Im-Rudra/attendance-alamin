// Regression tests for the UI findings of the QA report (07-qa-report.md):
// QA-02 money glyph, QA-03 students FAB, QA-06 share feedback, QA-09 overview
// panes, QA-12 week start of the date picker, QA-18 duplicate pill / button.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/services/share_service.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_table.dart';
import 'package:attendance_alamin/features/home/widgets/dues_card.dart';
import 'package:attendance_alamin/features/students/ui/student_profile_screen.dart';
import 'package:attendance_alamin/features/students/ui/students_screen.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump_app.dart';

Widget _button(String key, Future<void> Function(BuildContext) onTap) => Scaffold(
      body: Center(
        child: Builder(
          builder: (BuildContext context) => ElevatedButton(
            key: ValueKey<String>(key),
            onPressed: () => onTap(context),
            child: const Text('go'),
          ),
        ),
      ),
    );

void main() {
  final AppLocalizations bn = lookupAppLocalizations(const Locale('bn'));
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  group('QA-02 taka sign', () {
    test('money puts a thin space between the sign and the figure', () {
      expect(const AppFormat(Lang.bn).money(600), '৳ ৬০০');
      expect(const AppFormat(Lang.en).money(1500), '৳ 1,500');
      expect(const AppFormat(Lang.bn).money(-100), '-৳ ১০০');
    });

    testWidgets('MoneyText renders the sign as a smaller, lighter span', (WidgetTester tester) async {
      await pumpApp(tester, const Center(child: MoneyText('৳ ৬০০', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700))));
      final Finder f = find.text('৳ ৬০০');
      expect(f, findsOneWidget);
      final TextSpan root = tester.widget<Text>(f).textSpan! as TextSpan;
      final TextSpan sign = root.children!.first as TextSpan;
      expect(sign.text, '৳');
      expect(sign.style!.fontSize, closeTo(28, 0.01));
      expect(sign.style!.fontWeight, FontWeight.w400);
    });

    testWidgets('a figure without the sign stays a plain Text', (WidgetTester tester) async {
      await pumpApp(tester, const Center(child: MoneyText('৪২')));
      expect(tester.widget<Text>(find.text('৪২')).textSpan, isNull);
    });
  });

  group('QA-03 students FAB on the phone', () {
    testWidgets('the new-student button is there and sits above the nav pill', (WidgetTester tester) async {
      await pumpApp(tester, const StudentsScreen(), overrides: seedFakes().overrides);
      final Finder fab = find.byKey(const ValueKey<String>('stu-fab-new'));
      expect(fab, findsOneWidget);
      expect(tester.getBottomLeft(fab).dy, lessThan(640 - 84));
    });
  });

  group('QA-06 share always gives feedback', () {
    testWidgets('the text is copied and a snackbar says so', (WidgetTester tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpApp(tester, _button('share', (BuildContext c) => ShareService.shareText(c, 'hello')));
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.tap(find.byKey(const ValueKey<String>('share')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(copied, 'hello');
      expect(find.text(bn.shellTextCopied), findsOneWidget);
      expect(bn.shellTextCopied, 'লেখা কপি হয়েছে — যেকোনো জায়গায় পেস্ট করুন');
      expect(en.shellTextCopied, contains('paste'));
    });
  });

  group('QA-12 date picker week start', () {
    List<String> headers(WidgetTester tester) => <String>[
          for (int i = 0; i < 7; i++) tester.widget<Text>(find.byKey(ValueKey<String>('dp-head-$i'))).data!,
        ];

    testWidgets('starts on Saturday by default', (WidgetTester tester) async {
      await pumpApp(
        tester,
        _button('pick', (BuildContext c) async {
          await showAppDatePicker(
            context: c,
            initialDate: DateTime(2026, 11, 21),
            firstDate: DateTime(2026, 1, 1),
            lastDate: DateTime(2027, 1, 1),
          );
        }),
        overrides: seedFakes().overrides,
      );
      await tester.tap(find.byKey(const ValueKey<String>('pick')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      const AppFormat fmt = AppFormat(Lang.bn);
      expect(headers(tester), <String>[
        for (final int iso in const <int>[6, 7, 1, 2, 3, 4, 5]) fmt.weekdayShort(iso),
      ]);
      // 21 Nov 2026 is a Saturday: it is selected and in the first column.
      final Finder day21 = find.byKey(const ValueKey<String>('dp-day-21'));
      expect(day21, findsOneWidget);
      // Picking returns a date-only value.
      await tester.tap(find.byKey(const ValueKey<String>('dp-day-5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('dp-ok')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey<String>('dp-ok')), findsNothing);
    });

    testWidgets('follows the Settings week start (Monday)', (WidgetTester tester) async {
      await pumpApp(
        tester,
        AppDatePickerDialog(
          initialDate: DateTime(2026, 11, 21),
          firstDate: DateTime(2026, 1, 1),
          lastDate: DateTime(2027, 1, 1),
          weekStart: 1,
        ),
      );
      const AppFormat fmt = AppFormat(Lang.bn);
      expect(headers(tester).first, fmt.weekdayShort(1));
      expect(headers(tester).last, fmt.weekdayShort(7));
    });
  });

  group('QA-09 overview panes are balanced', () {
    testWidgets('the students overview shows the batch distribution and recent students', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const StudentsScreen(),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      expect(find.text(bn.stuOverviewByBatch), findsOneWidget);
      expect(find.text(bn.stuOverviewRecent), findsOneWidget);
      expect(find.byType(BatchBarList), findsOneWidget);
    });
  });

  group('QA-18 duplicates', () {
    testWidgets('the Today dues card shows the overdue count once', (WidgetTester tester) async {
      await pumpApp(tester, const SingleChildScrollView(child: DuesCard()), overrides: seedFakes().overrides);
      for (final EscalationBar bar in tester.widgetList<EscalationBar>(find.byType(EscalationBar))) {
        expect(bar.overdueCount, 0);
      }
    });

    testWidgets('a one-batch student profile on the phone has a single Collect fee button',
        (WidgetTester tester) async {
      await pumpApp(tester, const StudentProfileScreen(studentId: kStuRahim), overrides: seedFakes().overrides);
      expect(find.text(bn.stuCollect), findsOneWidget);
    });
  });
}
