// Add from CSV on the bulk-add screen: pick -> preview (bad rows flagged) ->
// "add all" saves and enrols the good rows, then the list and snackbar update.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/extras/controllers/csv_import_service.dart';
import 'package:attendance_alamin/features/extras/ui/bulk_add_screen.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

const String _csv = 'নাম,ফোন,রোল\n'
    'আয়েশা খাতুন,০১৭৭৭৭৭৭৭৭৭,\n'
    'রহিম উদ্দিন,01999999999\n'
    ',01712345678\n'
    'বিলাল,12345\n'
    'চন্দ্রা,01655555555,9\n';

const ValueKey<String> _button = ValueKey<String>('csv-import-button');

List<Override> _overrides(SeededFakes f) => <Override>[
      ...f.overrides,
      csvFilePickerProvider.overrideWithValue(() async => Uint8List.fromList(utf8.encode(_csv))),
    ];

Future<void> _openPreview(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(_button));
  await tester.tap(find.byKey(_button));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final AppLocalizations bn = lookupAppLocalizations(const Locale('bn'));

  testWidgets('preview flags bad rows, add all saves the rest', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, const BulkAddScreen(batchId: kBatPhysA), overrides: _overrides(f));
    final int before = f.students.students.length;

    await _openPreview(tester);

    expect(find.text(bn.extraImportFound('৫')), findsOneWidget);
    expect(find.text(bn.extraImportSkipped('৩')), findsOneWidget);
    expect(find.text(bn.extraImportAddAll('২')), findsOneWidget);
    expect(find.text(bn.extraImportProblemName), findsOneWidget);
    expect(find.text(bn.extraImportProblemPhone), findsOneWidget);
    expect(find.text(bn.extraImportProblemDuplicate), findsOneWidget);
    expect(f.students.students.length, before, reason: 'nothing saved before confirming');

    await tester.tap(find.byKey(const ValueKey<String>('csv-add-all')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(f.students.students.length, before + 2);
    final Student a = f.students.students.firstWhere((Student s) => s.name == 'আয়েশা খাতুন');
    expect(a.guardianPhone, '01777777777');
    expect(a.roll, '05', reason: 'auto-filled after the four seed students');
    final Student c = f.students.students.firstWhere((Student s) => s.name == 'চন্দ্রা');
    expect(c.roll, '09');
    for (final Student s in <Student>[a, c]) {
      final Enrollment e = f.enrollments.enrollments.firstWhere((Enrollment e) => e.studentId == s.id);
      expect(e.batchId, kBatPhysA);
      expect(e.endDate, isNull);
    }
    expect(find.byKey(ValueKey<String>('bulk-added-${a.id}')), findsOneWidget);
    expect(find.text(bn.extraImportDone('২')), findsOneWidget);
  });

  testWidgets('cancelling the preview saves nothing', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await pumpApp(tester, const BulkAddScreen(batchId: kBatPhysA), overrides: _overrides(f));
    final int before = f.students.students.length;
    await _openPreview(tester);
    await tester.tap(find.byKey(const ValueKey<String>('csv-cancel')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(f.students.students.length, before);
  });
}
