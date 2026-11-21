// BulkAddScreen (F20): matrix, the Save & next loop (student created, enrolled
// in the batch, form cleared), the duplicate-phone ask and removing the last.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/extras/ui/bulk_add_screen.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

const ValueKey<String> _name = ValueKey<String>('bulk-name');
const ValueKey<String> _phone = ValueKey<String>('bulk-phone');

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _saveWithEnter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _settle(tester);
}

void main() {
  final AppLocalizations bn = lookupAppLocalizations(const Locale('bn'));

  testScreenMatrix(
    'bulk add: empty form',
    () => const BulkAddScreen(batchId: kBatPhysA),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      expect(find.byKey(_name), findsOneWidget);
      expect(find.byKey(_phone), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('bulk-finish')), findsOneWidget);
    },
  );

  testScreenMatrix(
    'bulk add: after a few students',
    () => const BulkAddScreen(batchId: kBatPhysA),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      for (final String n in <String>['আয়েশা', 'বিলাল', 'চন্দ্রা']) {
        await tester.enterText(find.byKey(_name), n);
        await tester.pump();
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        await tester.enterText(find.byKey(_phone), '01712345678');
        await tester.pump();
        await _saveWithEnter(tester);
        // The shared guardian number asks once; confirm with a second Enter.
        await _saveWithEnter(tester);
      }
      expect(find.textContaining('আয়েশা'), findsOneWidget);
    },
  );

  testWidgets('Save & next creates and enrols, then clears the form', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, const BulkAddScreen(batchId: kBatPhysA), overrides: f.overrides);
    final int before = f.students.students.length;

    await tester.enterText(find.byKey(_name), '  আয়েশা খাতুন ');
    await tester.enterText(find.byKey(_phone), '০১৭৭৭৭৭৭৭৭৭');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('bulk-save')));
    await _settle(tester);

    expect(f.students.students.length, before + 1);
    final Student added = f.students.students.firstWhere((Student s) => s.name == 'আয়েশা খাতুন');
    expect(added.guardianPhone, '01777777777');
    expect(added.roll, '05', reason: 'next roll after the four seed students');
    final Enrollment enrolled = f.enrollments.enrollments.firstWhere((Enrollment e) => e.studentId == added.id);
    expect(enrolled.batchId, kBatPhysA);
    expect(enrolled.endDate, isNull);

    // Form cleared, counter and list updated.
    expect(tester.widget<BhorTextField>(find.byKey(_name)).controller!.text, isEmpty);
    expect(tester.widget<BhorTextField>(find.byKey(_phone)).controller!.text, isEmpty);
    expect(find.text(bn.extraBulkAddedCount('১')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('bulk-added-${added.id}')), findsOneWidget);
  });

  testWidgets('the button is disabled until there is a name', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, const BulkAddScreen(batchId: kBatPhysA), overrides: f.overrides);
    expect(tester.widget<BhorButton>(find.byKey(const ValueKey<String>('bulk-save'))).onPressed, isNull);
    expect(find.text(bn.extraBulkDisabledName), findsOneWidget);
    await tester.enterText(find.byKey(_name), 'আয়েশা');
    await tester.pump();
    expect(tester.widget<BhorButton>(find.byKey(const ValueKey<String>('bulk-save'))).onPressed, isNotNull);
  });

  testWidgets('a phone that belongs to someone asks once, then adds', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, const BulkAddScreen(batchId: kBatPhysA), overrides: f.overrides);
    final int before = f.students.students.length;

    await tester.enterText(find.byKey(_name), 'ছোট ভাই');
    // Rahim's guardian number.
    await tester.enterText(find.byKey(_phone), '01811223344');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('bulk-save')));
    await _settle(tester);

    expect(f.students.students.length, before, reason: 'nothing saved yet');
    expect(find.byKey(const ValueKey<String>('bulk-duplicate')), findsOneWidget);
    expect(find.text(bn.extraBulkDuplicate('রহিম উদ্দিন')), findsOneWidget);
    expect(find.text(bn.extraBulkSaveAnyway), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('bulk-save')));
    await _settle(tester);
    expect(f.students.students.length, before + 1);
    expect(find.byKey(const ValueKey<String>('bulk-duplicate')), findsNothing);
  });

  testWidgets('an invalid phone shows a message and saves nothing', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, const BulkAddScreen(batchId: kBatPhysA), overrides: f.overrides);
    final int before = f.students.students.length;
    await tester.enterText(find.byKey(_name), 'আয়েশা');
    await tester.enterText(find.byKey(_phone), '12345');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('bulk-save')));
    await _settle(tester);
    expect(f.students.students.length, before);
    expect(find.byKey(const ValueKey<String>('bulk-error')), findsOneWidget);
  });

  testWidgets('"remove the last one" takes back the newest student', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, const BulkAddScreen(batchId: kBatPhysA), overrides: f.overrides);
    final int before = f.students.students.length;
    await tester.enterText(find.byKey(_name), 'ভুল নাম');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('bulk-save')));
    await _settle(tester);
    expect(f.students.students.length, before + 1);

    await tester.tap(find.byKey(const ValueKey<String>('bulk-undo-last')));
    await _settle(tester);
    expect(f.students.students.length, before);
    expect(find.text(bn.extraBulkRemoved('ভুল নাম')), findsOneWidget);
    expect(find.text(bn.extraBulkAddedCount('০')), findsOneWidget);
  });

  testWidgets('an unknown batch says so', (WidgetTester tester) async {
    await pumpApp(tester, const BulkAddScreen(batchId: 'nope'), overrides: seedFakes().overrides);
    expect(find.text(bn.extraBulkBatchMissing), findsOneWidget);
  });

  testWidgets('bulk-added students are existing: billing starts this month', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, const BulkAddScreen(batchId: kBatPhysA), overrides: f.overrides);
    expect(find.byKey(const ValueKey<String>('bulk-billing-note')), findsOneWidget);
    expect(
      find.text(bn.onbBillingStartNote(const AppFormat(Lang.bn).monthYear(const YearMonth(2026, 11)))),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(_name), 'আয়েশা খাতুন');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('bulk-save')));
    await _settle(tester);
    final Student added = f.students.students.firstWhere((Student s) => s.name == 'আয়েশা খাতুন');
    final Enrollment e = f.enrollments.enrollments.firstWhere((Enrollment e) => e.studentId == added.id);
    // The 21st is past the 15th cutoff, yet the first month is November.
    expect(e.startMonth, const YearMonth(2026, 11));
  });

  testWidgets('text typed while a save is running survives', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    final Completer<void> gate = Completer<void>();
    f.students.createGate = gate.future;
    await pumpApp(tester, const BulkAddScreen(batchId: kBatPhysA), overrides: f.overrides);
    final int before = f.students.students.length;

    await tester.enterText(find.byKey(_name), 'আয়েশা');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('bulk-save')));
    await tester.pump();
    expect(f.students.students.length, before, reason: 'the save is still running');
    expect(tester.widget<BhorTextField>(find.byKey(_name)).controller!.text, isEmpty);

    await tester.enterText(find.byKey(_name), 'বিলাল');
    gate.complete();
    await _settle(tester);
    expect(f.students.students.length, before + 1);
    expect(tester.widget<BhorTextField>(find.byKey(_name)).controller!.text, 'বিলাল');
  });
}
