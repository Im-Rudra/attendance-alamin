// CSV export (F23): exact bytes (UTF-8 BOM, CRLF, quoting), Bangla content,
// the three files of a month built from the seed fixtures, and the export sheet
// handing the bytes to BackupFiles.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/backup/backup_files.dart';
import 'package:attendance_alamin/data/backup/backup_providers.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/features/extras/controllers/csv_builder.dart';
import 'package:attendance_alamin/features/extras/controllers/csv_export.dart';
import 'package:attendance_alamin/features/extras/widgets/csv_export_sheet.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

const YearMonth _nov = YearMonth(2026, 11);

String _text(Uint8List bytes) => utf8.decode(bytes.sublist(3));

Future<CsvFile> _load(SeededFakes f, CsvKind kind, AppLocalizations l10n) => loadCsvFile(
      kind: kind,
      month: _nov,
      l10n: l10n,
      students: f.students,
      enrollments: f.enrollments,
      batches: f.batches,
      payments: f.payments,
      otherIncome: f.otherIncome,
      attendance: f.attendance,
      methodLabel: (PaymentMethod m) => paymentMethodLabel(l10n, m),
    );

Future<void> _pumpMany(WidgetTester tester) async {
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _FakeFiles implements BackupFiles {
  final List<(String, Uint8List, bool)> calls = <(String, Uint8List, bool)>[];

  @override
  Future<bool> save(Uint8List bytes, {required String fileName}) async {
    calls.add((fileName, bytes, false));
    return true;
  }

  @override
  Future<void> share(Uint8List bytes, {required String fileName}) async {
    calls.add((fileName, bytes, true));
  }

  @override
  Future<Uint8List?> pick() async => null;
}

void main() {
  final AppLocalizations bn = lookupAppLocalizations(const Locale('bn'));
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  group('csv builder', () {
    test('bytes start with the UTF-8 BOM and keep Bangla intact', () {
      final Uint8List bytes = csvBytes(buildCsv(<String>['নাম'], <List<String>>[
        <String>['রহিম উদ্দিন'],
      ]));
      expect(bytes.sublist(0, 3), kUtf8Bom);
      expect(bytes.sublist(0, 3), <int>[0xEF, 0xBB, 0xBF]);
      expect(_text(bytes), 'নাম\r\nরহিম উদ্দিন\r\n');
    });

    test('quotes commas, quotes and line breaks', () {
      expect(csvCell('a,b'), '"a,b"');
      expect(csvCell('say "hi"'), '"say ""hi"""');
      expect(csvCell('two\nlines'), '"two\nlines"');
      expect(csvCell('plain'), 'plain');
    });

    test('formula-looking cells are neutralised, negative numbers are not', () {
      expect(csvCell('=SUM(A1)'), "'=SUM(A1)");
      expect(csvCell('@cmd'), "'@cmd");
      expect(csvCell('-x'), "'-x");
      expect(csvCell('-500'), '-500');
      expect(csvCell('+8801711223344'), '+8801711223344');
    });

    test('a phone with a leading zero survives Excel as text', () {
      final String csv = buildCsv(<String>['p'], <List<String>>[
        <String>[csvPhone('01711223344')],
        <String>[csvPhone(null)],
        <String>['="evil"'],
      ]);
      expect(csv, 'p\r\n="01711223344"\r\n\r\n"\'=""evil"""\r\n');
    });
  });

  group('csv files from the seed', () {
    test('students: every student, Bangla text, phones as text', () async {
      final CsvFile file = await _load(seedFakes(), CsvKind.students, bn);
      expect(file.fileName, 'students-2026-11.csv');
      expect(file.bytes.sublist(0, 3), kUtf8Bom);
      final String csv = _text(file.bytes);
      final List<String> lines = csv.trimRight().split('\r\n');
      expect(lines.first, 'রোল,নাম,ফোন,অভিভাবক,অভিভাবকের ফোন,অবস্থা,ভর্তির তারিখ,ব্যাচ');
      expect(file.rowCount, 4);
      expect(lines.length, 5);
      expect(csv, contains('রহিম উদ্দিন'));
      expect(csv, contains('="01711223344"'));
      expect(csv, contains('2026-09-05'));
      // Sara is in both batches.
      expect(csv, contains('ফিজিক্স এ / কেমিস্ট্রি বি'));
    });

    test('students: English headers in English', () async {
      final CsvFile file = await _load(seedFakes(), CsvKind.students, en);
      expect(_text(file.bytes).split('\r\n').first, 'Roll,Name,Phone,Guardian,Guardian phone,Status,Admission date,Batches');
    });

    test('payments: only this month, with other income, oldest first', () async {
      final SeededFakes f = seedFakes();
      await f.otherIncome.add(const OtherIncome(
        id: '',
        label: 'ভর্তি ফি, নতুন',
        amount: 500,
        paidOn: LocalDate(2026, 11, 20),
        method: PaymentMethod.cash,
        studentId: kStuKarim,
      ));
      await f.otherIncome.add(const OtherIncome(
        id: '',
        label: 'Old exam fee',
        amount: 100,
        paidOn: LocalDate(2026, 10, 1),
        method: PaymentMethod.cash,
      ));
      final CsvFile file = await _load(f, CsvKind.payments, bn);
      expect(file.fileName, 'payments-2026-11.csv');
      final List<String> lines = _text(file.bytes).trimRight().split('\r\n');
      expect(lines.first, 'তারিখ,রসিদ,শিক্ষার্থী,ব্যাচ,যে মাসের,টাকা,পদ্ধতি,ধরন,নোট');
      expect(file.rowCount, 2, reason: 'Sara\'s Nov 2 payment + the Nov 20 other income');
      expect(lines[1], startsWith('2026-11-02,'));
      expect(lines[1], contains('সারা আক্তার'));
      expect(lines[1], contains('2026-11,1000'));
      expect(lines[1], contains('বেতন'));
      expect(lines[2], startsWith('2026-11-20,'));
      expect(lines[2], contains('"ভর্তি ফি, নতুন"'));
      expect(lines[2], contains('করিম হোসেন'));
      expect(lines[2], contains('অন্যান্য'));
      expect(_text(file.bytes), isNot(contains('Old exam fee')));
    });

    test('attendance: one row per student per class of the month', () async {
      final CsvFile file = await _load(seedFakes(), CsvKind.attendance, bn);
      expect(file.fileName, 'attendance-2026-11.csv');
      final List<String> lines = _text(file.bytes).trimRight().split('\r\n');
      expect(lines.first, 'তারিখ,ব্যাচ,রোল,শিক্ষার্থী,অবস্থা');
      // Rahim 6 + Sara 6 + Nila 4 marks in the seed.
      expect(file.rowCount, 16);
      expect(lines[1], startsWith('2026-11-07,ফিজিক্স এ,'));
      final String csv = _text(file.bytes);
      expect(csv, contains('উপস্থিত'));
      expect(csv, contains('অনুপস্থিত'));
      expect(csv, contains('দেরি'));
      expect(csv, contains('ছুটি'));
    });

    test('another month has no attendance rows but keeps the header', () async {
      final SeededFakes f = seedFakes();
      final CsvFile file = await loadCsvFile(
        kind: CsvKind.attendance,
        month: const YearMonth(2026, 3),
        l10n: en,
        students: f.students,
        enrollments: f.enrollments,
        batches: f.batches,
        payments: f.payments,
        otherIncome: f.otherIncome,
        attendance: f.attendance,
        methodLabel: (PaymentMethod m) => paymentMethodLabel(en, m),
      );
      expect(file.rowCount, 0);
      expect(_text(file.bytes), 'Date,Batch,Roll,Student,Status\r\n');
      expect(file.fileName, 'attendance-2026-03.csv');
    });
  });

  group('export sheet', () {
    testScreenMatrix(
      'csv sheet: lists the three files',
      () => const Scaffold(body: CsvExportSheet(initialMonth: _nov)),
      overrides: () => seedFakes().overrides,
      verify: (WidgetTester tester) async {
        expect(find.byKey(const ValueKey<String>('csv-save-students')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('csv-save-payments')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('csv-share-attendance')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('csv-month')), findsOneWidget);
      },
    );

    testWidgets('save hands the BOM bytes to BackupFiles, share uses share', (WidgetTester tester) async {
      final _FakeFiles files = _FakeFiles();
      await pumpApp(
        tester,
        const Scaffold(body: CsvExportSheet(initialMonth: _nov)),
        overrides: <Override>[...seedFakes().overrides, backupFilesProvider.overrideWithValue(files)],
      );
      await tester.tap(find.byKey(const ValueKey<String>('csv-save-students')));
      await _pumpMany(tester);
      expect(find.text(bn.extraCsvFailed), findsNothing, reason: 'building the file failed');
      expect(files.calls, hasLength(1));
      expect(files.calls.first.$1, 'students-2026-11.csv');
      expect(files.calls.first.$2.sublist(0, 3), <int>[0xEF, 0xBB, 0xBF]);
      expect(files.calls.first.$3, isFalse);
      expect(_text(files.calls.first.$2), contains('রহিম উদ্দিন'));

      await tester.tap(find.byKey(const ValueKey<String>('csv-next-month')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey<String>('csv-share-payments')));
      await tester.tap(find.byKey(const ValueKey<String>('csv-share-payments')));
      await _pumpMany(tester);
      expect(files.calls, hasLength(2));
      expect(files.calls.last.$1, 'payments-2026-12.csv');
      expect(files.calls.last.$3, isTrue);
    });
  });
}
