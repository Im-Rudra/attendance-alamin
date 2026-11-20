// Import end to end with fakes: Product scenario 15 (phone P's backup merged
// into PC W), importing again, undo, 0 changes, and the bad-file messages.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_state.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';
import 'backup_test_support.dart';

AppLocalizations get _bn => lookupAppLocalizations(const Locale('bn'));
const AppFormat _f = AppFormat(Lang.bn);

/// W (the PC) before the import; P (the phone) added Nila, edited Rahim's
/// phone and deleted Tuhin; W added a payment for Sara and edited Rahim's
/// guardian later than P's edit.
final RowMap _rahimW = stu('rahim', 'Rahim', u: 300, dev: 'W', rev: 2, phone: '01711000000', guardian: 'Abdul Karim');
final RowMap _saraPay = row('pay1', u: 230, dev: 'W', data: <String, Object?>{
  'receipt_id': 'rcpt1',
  'student_id': 'sara',
  'billing_month': 202611,
  'amount': 1000,
  'paid_on': '2026-11-05',
});

Tables _w() => <String, List<RowMap>>{
      'students': <RowMap>[_rahimW, stu('tuhin', 'Tuhin'), stu('sara', 'Sara')],
      'payments': <RowMap>[_saraPay],
    };

Snapshot _pBackup() => snap(
      <String, List<RowMap>>{
        'students': <RowMap>[
          stu('nila', 'Nila', u: 200),
          stu('rahim', 'Rahim', u: 210, rev: 2, phone: '01811000000', guardian: 'Karim'),
          stu('tuhin', 'Tuhin', u: 220, rev: 2, del: 220),
          stu('sara', 'Sara'),
        ],
        'payments': <RowMap>[],
      },
      createdAtMs: DateTime.utc(2026, 11, 18, 15, 15).millisecondsSinceEpoch,
      device: 'Phone',
    );

Future<void> _pumpHost(
  WidgetTester tester, {
  required MergingBackupRepository repo,
  required FakeBackupFiles files,
  SeededFakes? fakes,
  TestViewport viewport = TestViewport.phone,
}) async {
  final GoRouter router = hostRouter();
  addTearDown(router.dispose);
  await pumpApp(
    tester,
    Router<Object>.withConfig(config: router),
    viewport: viewport,
    overrides: <Override>[
      ...(fakes ?? seedFakes()).overrides,
      ...backupOverrides(repo: repo, files: files),
    ],
  );
}

Future<void> _importFile(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('host-import')));
  // Lets the controller's 3 s guard on the schedules read run out if the
  // fake stream were silent.
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('scenario 15: review shows Nila added, Tuhin removed in red, Rahim kept; apply merges; again = nothing to do',
      (WidgetTester tester) async {
    final MergingBackupRepository repo = MergingBackupRepository(_w());
    final FakeBackupFiles files = FakeBackupFiles()..pickResult = encoded(_pBackup());
    await _pumpHost(tester, repo: repo, files: files);

    await _importFile(tester);

    // Review: full screen, nothing changed yet.
    expect(find.text(_bn.shellTitleBackupReview), findsOneWidget, reason: allTexts(tester));
    expect(find.text(_bn.backupHeadline(_f.number(2))), findsOneWidget);
    expect(find.text(_bn.backupReviewDevice('Phone')), findsOneWidget);
    final Finder deletions = find.byKey(const Key('review-deletions'));
    expect(
      find.descendant(of: deletions, matching: find.text(_bn.backupDeletionLine(_bn.backupEntityStudents, 'Tuhin'))),
      findsOneWidget,
    );
    expect(find.text(_bn.backupKeptTotal(_f.number(1))), findsOneWidget, reason: "Rahim's newer data is kept");
    expect(find.text('Nila'), findsOneWidget);
    expect(find.byKey(const Key('review-clashes')), findsNothing);
    expect(repo.byId('students', 'nila'), isNull, reason: 'nothing changes before Apply');
    expect(repo.byId('students', 'tuhin')!['deleted_at'], isNull);
    // students row: 1 new, 0 changed, 1 removed.
    final Finder studentsRow = find.byKey(const Key('review-row-students'));
    expect(find.descendant(of: studentsRow, matching: find.text(_f.number(1))), findsNWidgets(2));
    expect(find.descendant(of: studentsRow, matching: find.text(_f.number(0))), findsOneWidget);

    // Apply.
    await tester.tap(find.byKey(const Key('review-apply')));
    await tester.pumpAndSettle();

    expect(find.text(_bn.backupDoneTitle(_f.number(2))), findsOneWidget);
    expect(repo.byId('students', 'nila')!['deleted_at'], isNull);
    expect(repo.byId('students', 'tuhin')!['deleted_at'], 220);
    expect(repo.byId('students', 'rahim'), _rahimW, reason: "W's newer whole record wins");
    expect(repo.byId('payments', 'pay1'), _saraPay, reason: "Sara's payment is intact");

    // Done goes back to the host; importing the same file again changes nothing.
    await tester.tap(find.byKey(const Key('review-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-import')), findsOneWidget);

    await _importFile(tester);
    expect(find.text(_bn.backupHeadlineNone), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('review-apply'))).onPressed, isNull);
    expect(find.text(_bn.backupApplyDisabledNone), findsOneWidget);
    expect(repo.byId('students', 'tuhin')!['deleted_at'], 220);
  });

  testWidgets('scenario 15: "আগের অবস্থায় ফেরান" restores W exactly as it was before the import',
      (WidgetTester tester) async {
    final Tables before = _w();
    final MergingBackupRepository repo = MergingBackupRepository(before);
    final FakeBackupFiles files = FakeBackupFiles()..pickResult = encoded(_pBackup());
    await _pumpHost(tester, repo: repo, files: files);

    await _importFile(tester);
    await tester.tap(find.byKey(const Key('review-apply')));
    await tester.pumpAndSettle();
    expect(repo.byId('students', 'nila'), isNotNull);

    await tester.tap(find.byKey(const Key('review-undo')));
    await tester.pumpAndSettle();

    expect(repo.byId('students', 'nila'), isNull);
    expect(repo.byId('students', 'tuhin')!['deleted_at'], isNull);
    expect(repo.byId('students', 'rahim'), _rahimW);
    expect(find.text(_bn.backupUndone), findsOneWidget);
    expect(find.byKey(const Key('host-import')), findsOneWidget, reason: 'back on the screen we came from');
  });

  testWidgets('cancelling the review leaves the data alone and forgets the file', (WidgetTester tester) async {
    final MergingBackupRepository repo = MergingBackupRepository(_w());
    final FakeBackupFiles files = FakeBackupFiles()..pickResult = encoded(_pBackup());
    await _pumpHost(tester, repo: repo, files: files);

    await _importFile(tester);
    await tester.tap(find.byKey(const Key('review-secondary')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-import')), findsOneWidget);
    expect(repo.byId('students', 'nila'), isNull);
    expect(containerOf(tester).read(importControllerProvider).phase, ImportPhase.idle);
  });

  testWidgets('a cancelled file picker does nothing', (WidgetTester tester) async {
    final MergingBackupRepository repo = MergingBackupRepository(_w());
    final FakeBackupFiles files = FakeBackupFiles(); // pickResult null
    await _pumpHost(tester, repo: repo, files: files);

    await _importFile(tester);

    expect(find.byKey(const Key('host-import')), findsOneWidget);
    expect(find.text(_bn.shellTitleBackupReview), findsNothing);
  });

  group('bad files', () {
    Future<void> expectMessage(WidgetTester tester, FakeBackupFiles files, String message) async {
      final MergingBackupRepository repo = MergingBackupRepository(_w());
      await _pumpHost(tester, repo: repo, files: files);
      await _importFile(tester);
      expect(find.text(_bn.backupFailedTitle), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.byKey(const Key('review-apply')), findsNothing, reason: 'nothing to apply');
      expect(repo.byId('students', 'nila'), isNull);
    }

    testWidgets('not a backup: the plain-language message and a way to choose another file',
        (WidgetTester tester) async {
      final FakeBackupFiles files = FakeBackupFiles()..pickResult = _notABackup();
      await expectMessage(tester, files, _bn.errImportNotBackup);
      expect(find.byKey(const Key('review-pick-other')), findsOneWidget);

      // Choosing another (good) file replaces the message with the review.
      files.pickResult = encoded(_pBackup());
      await tester.tap(find.byKey(const Key('review-pick-other')));
      await tester.pumpAndSettle();
      expect(find.text(_bn.backupHeadline(_f.number(2))), findsOneWidget);
      expect(find.text(_bn.backupFailedTitle), findsNothing);
    });

    testWidgets('damaged file (checksum)', (WidgetTester tester) async {
      final Snapshot good = _pBackup();
      final Snapshot tampered = Snapshot(
        formatVersion: good.formatVersion,
        schemaVersion: good.schemaVersion,
        appVersion: good.appVersion,
        snapshotId: good.snapshotId,
        deviceId: good.deviceId,
        deviceName: good.deviceName,
        createdAtMs: good.createdAtMs,
        counts: good.counts,
        sha256: 'f' * 64,
        tables: good.tables,
      );
      await expectMessage(
        tester,
        FakeBackupFiles()..pickResult = encoded(tampered),
        _bn.errImportChecksum,
      );
    });

    testWidgets('a backup from a newer app version asks for an update', (WidgetTester tester) async {
      final Snapshot good = _pBackup();
      final Snapshot newer = Snapshot(
        formatVersion: good.formatVersion,
        schemaVersion: 99,
        appVersion: good.appVersion,
        snapshotId: good.snapshotId,
        deviceId: good.deviceId,
        deviceName: good.deviceName,
        createdAtMs: good.createdAtMs,
        counts: good.counts,
        sha256: good.sha256,
        tables: good.tables,
      );
      await expectMessage(
        tester,
        FakeBackupFiles()..pickResult = encoded(newer),
        _bn.errImportNewerSchema,
      );
    });

    testWidgets('a backup the database rejects (missing parent) says so', (WidgetTester tester) async {
      final FakeBackupRepository repo = FakeBackupRepository()
        ..previewError = const ImportException(ErrorCodes.importMissingParent);
      final FakeBackupFiles files = FakeBackupFiles()..pickResult = encoded(_pBackup());
      final GoRouter router = hostRouter();
      addTearDown(router.dispose);
      await pumpApp(
        tester,
        Router<Object>.withConfig(config: router),
        overrides: <Override>[
          ...seedFakes().overrides,
          ...backupOverrides(repo: repo, files: files),
        ],
      );
      await _importFile(tester);
      expect(find.text(_bn.errImportMissingParent), findsOneWidget);
      expect(repo.applied, isEmpty);
    });
  });

  testWidgets('a failing apply keeps the review open with a message and the data untouched',
      (WidgetTester tester) async {
    final FakeBackupRepository repo = FakeBackupRepository()
      ..nextSummary = richSummary()
      ..applyError = const StorageException(ErrorCodes.storageFailed);
    final FakeBackupFiles files = FakeBackupFiles()..pickResult = encoded(_pBackup());
    final GoRouter router = hostRouter();
    addTearDown(router.dispose);
    await pumpApp(
      tester,
      Router<Object>.withConfig(config: router),
      overrides: <Override>[
        ...seedFakes().overrides,
        ...backupOverrides(repo: repo, files: files),
      ],
    );
    await _importFile(tester);
    await tester.tap(find.byKey(const Key('review-apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review-error')), findsOneWidget);
    expect(find.text(_bn.errStorageFailed), findsOneWidget);
    expect(find.byKey(const Key('review-apply')), findsOneWidget, reason: 'the teacher can retry');
    expect(repo.applied, isEmpty);
  });

  testWidgets('desktop: the same import fills the window with the review', (WidgetTester tester) async {
    final MergingBackupRepository repo = MergingBackupRepository(_w());
    final FakeBackupFiles files = FakeBackupFiles()..pickResult = encoded(_pBackup());
    await _pumpHost(tester, repo: repo, files: files, viewport: TestViewport.desktop);
    await _importFile(tester);
    expect(find.text(_bn.backupHeadline(_f.number(2))), findsOneWidget);
    expect(find.byKey(const Key('review-explain')), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-apply')));
    await tester.pumpAndSettle();
    expect(find.text(_bn.backupDoneTitle(_f.number(2))), findsOneWidget);
  });

  test('ImportController: applying with nothing to change is a no-op', () async {
    final FakeBackupRepository repo = FakeBackupRepository()..nextSummary = const ChangeSummary();
    final FakeBackupFiles files = FakeBackupFiles()..pickResult = encoded(_pBackup());
    final container = makeContainer(overrides: <Override>[
      ...seedFakes().overrides,
      ...backupOverrides(repo: repo, files: files),
    ]);
    final ImportController c = container.read(importControllerProvider.notifier);
    expect(await c.pickAndPreview(), isTrue);
    expect(container.read(importControllerProvider).phase, ImportPhase.ready);
    await c.apply();
    expect(repo.applied, isEmpty);
    expect(container.read(importControllerProvider).phase, ImportPhase.ready);
  });
}

/// Valid UTF-8 text, not gzip.
Uint8List _notABackup() => Uint8List.fromList(utf8.encode('just some text'));
