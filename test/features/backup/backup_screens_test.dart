// Backup screens: the 8-case matrix for every screen and state, plus the
// behaviours that matter (export saves and records lastExportAt only after a
// real save, safety copies, review content).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/data/backup/backup_repository.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_state.dart';
import 'package:attendance_alamin/features/backup/ui/backup_review_screen.dart';
import 'package:attendance_alamin/features/backup/ui/backup_screen.dart';
import 'package:attendance_alamin/features/backup/widgets/export_sheet.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';
import 'backup_test_support.dart';

AppLocalizations get _bn => lookupAppLocalizations(const Locale('bn'));
const AppFormat _f = AppFormat(Lang.bn);

final int _nowMs = kTestNowUtc.millisecondsSinceEpoch;

FakeBackupRepository _repo({bool copies = true}) {
  final FakeBackupRepository r = FakeBackupRepository()
    ..nextSnapshot = snap(<String, List<RowMap>>{}, createdAtMs: _nowMs);
  if (copies) {
    r.safetyCopies = <SafetyCopyInfo>[
      SafetyCopyInfo(id: 's3', createdAtMs: _nowMs - 3600000, reason: SafetyCopyReason.beforeRestore),
      SafetyCopyInfo(id: 's2', createdAtMs: _nowMs - 86400000, reason: SafetyCopyReason.beforeImport),
      SafetyCopyInfo(id: 's1', createdAtMs: _nowMs - 3 * 86400000, reason: SafetyCopyReason.beforeImport),
    ];
  }
  return r;
}

List<Override> _overrides(SeededFakes fakes, FakeBackupRepository repo, FakeBackupFiles files,
        [List<Override> extra = const <Override>[]]) =>
    <Override>[...fakes.overrides, ...backupOverrides(repo: repo, files: files), ...extra];

Widget _scaled(Widget child) => Builder(
      builder: (BuildContext c) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child,
      ),
    );

void main() {
  group('matrix', () {
    testScreenMatrix(
      'BackupScreen with safety copies, stale backup',
      () => const BackupScreen(),
      overrides: () => _overrides(
        seedFakes(encodedSettings: <String, Object?>{
          'last_export_at': DateTime.utc(2026, 11, 9, 4).millisecondsSinceEpoch,
        }),
        _repo(),
        FakeBackupFiles(),
      ),
    );
    testScreenMatrix(
      'BackupScreen never backed up, no copies',
      () => const BackupScreen(),
      overrides: () => _overrides(seedFakes(), _repo(copies: false), FakeBackupFiles()),
    );
    testScreenMatrix(
      'BackupScreen 1.3x text',
      () => _scaled(const BackupScreen()),
      overrides: () => _overrides(seedFakes(), _repo(), FakeBackupFiles()),
    );
    testScreenMatrix(
      'BackupReviewScreen ready (rich)',
      () => const BackupReviewScreen(),
      overrides: () => _overrides(seedFakes(), _repo(), FakeBackupFiles(), <Override>[fixedImport(richState())]),
    );
    testScreenMatrix(
      'BackupReviewScreen ready 1.3x text',
      () => _scaled(const BackupReviewScreen()),
      overrides: () => _overrides(seedFakes(), _repo(), FakeBackupFiles(), <Override>[fixedImport(richState())]),
    );
    testScreenMatrix(
      'BackupReviewScreen apply failed',
      () => const BackupReviewScreen(),
      overrides: () => _overrides(seedFakes(), _repo(), FakeBackupFiles(),
          <Override>[fixedImport(richState(errorCode: 'storageFailed'))]),
    );
    testScreenMatrix(
      'BackupReviewScreen 0 changes',
      () => const BackupReviewScreen(),
      overrides: () => _overrides(seedFakes(), _repo(), FakeBackupFiles(), <Override>[
        fixedImport(ImportState(
          phase: ImportPhase.ready,
          snapshot: snap(<String, List<RowMap>>{}),
          summary: const ChangeSummary(),
        )),
      ]),
    );
    testScreenMatrix(
      'BackupReviewScreen applying',
      () => const BackupReviewScreen(),
      overrides: () => _overrides(seedFakes(), _repo(), FakeBackupFiles(), <Override>[
        fixedImport(richState().copyWith(phase: ImportPhase.applying)),
      ]),
      verify: (WidgetTester tester) async {
        expect(find.byKey(const Key('review-apply')), findsOneWidget);
      },
    );
    testScreenMatrix(
      'BackupReviewScreen invalid file',
      () => const BackupReviewScreen(),
      overrides: () => _overrides(seedFakes(), _repo(), FakeBackupFiles(),
          <Override>[fixedImport(const ImportState(phase: ImportPhase.failed, errorCode: 'importNotBackup'))]),
    );
    testScreenMatrix(
      'BackupReviewScreen result',
      () => const BackupReviewScreen(),
      overrides: () => _overrides(seedFakes(), _repo(), FakeBackupFiles(), <Override>[
        fixedImport(const ImportState(
          phase: ImportPhase.applied,
          changes: 47,
          safetyCopyId: 's1',
          overfilled: 2,
        )),
      ]),
    );
    testScreenMatrix(
      'BackupReviewScreen opened without a file',
      () => const BackupReviewScreen(),
      overrides: () => _overrides(seedFakes(), _repo(), FakeBackupFiles()),
    );
    testScreenMatrix(
      'ExportSheet',
      () => const ExportSheet(),
      overrides: () => _overrides(seedFakes(), _repo(), FakeBackupFiles()),
      verify: (WidgetTester tester) async {
        expect(find.byKey(const Key('backup-export-save')), findsOneWidget);
        expect(find.byKey(const Key('backup-export-privacy')), findsOneWidget);
      },
    );
  });

  group('Backup screen', () {
    testWidgets('shows how old the last backup is, with an info chip when stale', (WidgetTester tester) async {
      final SeededFakes fakes = seedFakes(encodedSettings: <String, Object?>{
        'last_export_at': DateTime.utc(2026, 11, 9, 4).millisecondsSinceEpoch,
      });
      await pumpApp(tester, const BackupScreen(), overrides: _overrides(fakes, _repo(), FakeBackupFiles()));
      expect(find.text(_bn.backupLastLine(_bn.backupLastAgo(_f.number(12)))), findsOneWidget);
      expect(find.byKey(const Key('backup-stale-chip')), findsOneWidget);
    });

    testWidgets('a backup from today has no chip; never backed up says so', (WidgetTester tester) async {
      final SeededFakes fresh = seedFakes(encodedSettings: <String, Object?>{'last_export_at': _nowMs});
      await pumpApp(tester, const BackupScreen(), overrides: _overrides(fresh, _repo(), FakeBackupFiles()));
      expect(find.text(_bn.backupLastLine(_bn.backupLastToday)), findsOneWidget);
      expect(find.byKey(const Key('backup-stale-chip')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(tester, const BackupScreen(), overrides: _overrides(seedFakes(), _repo(), FakeBackupFiles()));
      expect(find.text(_bn.backupLastNever), findsOneWidget);
      expect(find.byKey(const Key('backup-stale-chip')), findsOneWidget);
    });

    testWidgets('lists the safety copies and restores one after a confirmation', (WidgetTester tester) async {
      final FakeBackupRepository repo = _repo();
      await pumpApp(tester, const BackupScreen(),
          overrides: _overrides(seedFakes(), repo, FakeBackupFiles()));
      tester.view.physicalSize = const Size(400, 2400);
      await tester.pump();
      expect(find.byKey(const Key('backup-restore-s1')), findsOneWidget);
      expect(find.byKey(const Key('backup-restore-s2')), findsOneWidget);
      expect(find.byKey(const Key('backup-restore-s3')), findsOneWidget);
      expect(find.text(_bn.backupSafetyReasonRestore), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('backup-restore-s2')));
      await tester.tap(find.byKey(const Key('backup-restore-s2')));
      await tester.pumpAndSettle();
      expect(find.text(_bn.backupRestoreTitle), findsOneWidget);
      expect(repo.restored, isEmpty, reason: 'nothing before the confirmation');

      await tester.tap(find.descendant(of: find.byType(BhorDialog), matching: find.text(_bn.backupRestoreConfirm)));
      await tester.pumpAndSettle();
      expect(repo.restored, <String>['s2']);
      expect(find.text(_bn.backupRestoreDone), findsOneWidget);
    });

    testWidgets('no safety copies yet says so', (WidgetTester tester) async {
      await pumpApp(tester, const BackupScreen(),
          overrides: _overrides(seedFakes(), _repo(copies: false), FakeBackupFiles()));
      tester.view.physicalSize = const Size(400, 2400);
      await tester.pump();
      expect(find.byKey(const Key('backup-safety-empty')), findsOneWidget, reason: allTexts(tester));
    });

    testWidgets('desktop: the three cards sit side by side and fill the height', (WidgetTester tester) async {
      await pumpApp(tester, const BackupScreen(),
          viewport: TestViewport.desktop, overrides: _overrides(seedFakes(), _repo(), FakeBackupFiles()));
      final Rect export = tester.getRect(find.byKey(const Key('backup-export-card')));
      final Rect import = tester.getRect(find.byKey(const Key('backup-import-card')));
      final Rect safety = tester.getRect(find.byKey(const Key('backup-safety-card')));
      expect(export.top, import.top);
      expect(export.bottom, import.bottom);
      expect(safety.top, export.top);
      expect(safety.bottom, export.bottom);
      expect(export.right, lessThan(import.left));
      expect(import.right, lessThan(safety.left));
      // The cards reach the bottom of the window (no blank band under them).
      expect(export.bottom, greaterThan(700));
    });
  });

  group('Export', () {
    FakeBackupRepository exportRepo() => FakeBackupRepository()
      ..nextSnapshot = snap(<String, List<RowMap>>{}, createdAtMs: _nowMs);

    testWidgets('one tap builds the file, names it, warns it is private, saves and records lastExportAt',
        (WidgetTester tester) async {
      final SeededFakes fakes = seedFakes();
      final FakeBackupFiles files = FakeBackupFiles();
      await pumpApp(tester, const BackupScreen(),
          overrides: _overrides(fakes, exportRepo(), files));

      await tester.tap(find.byKey(const Key('backup-export-button')));
      await tester.pumpAndSettle();

      expect(find.text('coaching-backup-2026-11-21-1000.ambackup'), findsOneWidget);
      expect(find.text(_bn.backupExportPrivacy), findsOneWidget);
      expect(fakes.settings.encodedValues['last_export_at'], isNull, reason: 'nothing recorded before saving');

      await tester.tap(find.byKey(const Key('backup-export-save')));
      await tester.pumpAndSettle();

      expect(files.saved.single.$1, 'coaching-backup-2026-11-21-1000.ambackup');
      expect(files.saved.single.$2, isNotEmpty);
      expect(fakes.settings.encodedValues['last_export_at'], _nowMs);
      expect(find.byKey(const Key('backup-export-save')), findsNothing, reason: 'sheet closed');
      expect(find.text(_bn.backupExportSaved), findsOneWidget);
    });

    testWidgets('a cancelled save is not a backup: lastExportAt stays empty and the sheet stays',
        (WidgetTester tester) async {
      final SeededFakes fakes = seedFakes();
      final FakeBackupFiles files = FakeBackupFiles()..saveResult = false;
      await pumpApp(tester, const BackupScreen(), overrides: _overrides(fakes, exportRepo(), files));

      await tester.tap(find.byKey(const Key('backup-export-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-export-save')));
      await tester.pumpAndSettle();

      expect(files.saved, isEmpty);
      expect(fakes.settings.encodedValues['last_export_at'], isNull);
      expect(find.byKey(const Key('backup-export-save')), findsOneWidget);
    });

    testWidgets('share hands the same file to the share sheet and records the export', (WidgetTester tester) async {
      final SeededFakes fakes = seedFakes();
      final FakeBackupFiles files = FakeBackupFiles();
      await pumpApp(tester, const BackupScreen(), overrides: _overrides(fakes, exportRepo(), files));

      await tester.tap(find.byKey(const Key('backup-export-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-export-share')));
      await tester.pumpAndSettle();

      expect(files.shared.single.$1, 'coaching-backup-2026-11-21-1000.ambackup');
      expect(fakes.settings.encodedValues['last_export_at'], _nowMs);
      expect(find.text(_bn.backupExportShared), findsOneWidget);
    });

    testWidgets('a failure to build the file shows a plain message and a retry', (WidgetTester tester) async {
      final FakeBackupRepository repo = FakeBackupRepository(); // no snapshot: throws
      await pumpApp(tester, const BackupScreen(), overrides: _overrides(seedFakes(), repo, FakeBackupFiles()));
      await tester.tap(find.byKey(const Key('backup-export-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backup-export-retry')), findsOneWidget);
      expect(find.byKey(const Key('backup-export-save')), findsNothing);
    });
  });

  group('Review content', () {
    testWidgets('headline, table, deletions first and red, samples, older banner, clash card, kept line',
        (WidgetTester tester) async {
      await pumpApp(tester, const BackupReviewScreen(),
          overrides: _overrides(seedFakes(), _repo(), FakeBackupFiles(), <Override>[fixedImport(richState())]));
      // Tall enough that the whole list is built (no scrolling needed).
      tester.view.physicalSize = const Size(400, 3200);
      await tester.pump();

      // 1 batch + (5 added + 4 removed students) + 38 + 2 + 1 = 51 changes
      expect(find.text(_bn.backupHeadline(_f.number(51))), findsOneWidget, reason: allTexts(tester));
      expect(find.text(_bn.backupApplyN(_f.number(51))), findsOneWidget);
      expect(find.text(_bn.backupKeptTotal(_f.number(2))), findsOneWidget);
      expect(find.text(_bn.backupOlderBanner), findsOneWidget);
      expect(find.byKey(const Key('review-clashes')), findsOneWidget);

      // Deletions: named, in the red card, before the table.
      final Finder deletions = find.byKey(const Key('review-deletions'));
      expect(deletions, findsOneWidget);
      expect(
        find.descendant(
          of: deletions,
          matching: find.text(_bn.backupDeletionLine(_bn.backupEntityStudents, 'তানিয়া আক্তার')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: deletions,
          matching: find.text(_bn.backupDeletionLine(_bn.backupEntityStudents, _bn.backupMore(_f.number(1)))),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(deletions).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('review-table'))).dy),
        reason: 'deletions are listed before the table',
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(deletions);
      expect((box.decoration as BoxDecoration).color, tester.element(deletions).bhor.colors.dangerBg);

      // Samples: at most 3 per bucket plus "+N more", payments as name · money · date.
      expect(find.text('তানভীর হাসান'), findsOneWidget);
      expect(find.text(_bn.backupMore(_f.number(2))), findsOneWidget);
      expect(
        find.text(_bn.backupSamplePayment('রহিম উদ্দিন', _f.money(1000), _f.dateShort(const LocalDate(2026, 11, 5)))),
        findsOneWidget,
      );
    });

    testWidgets('0 changes: the sentence, a disabled apply with its reason, and an OK button',
        (WidgetTester tester) async {
      await pumpApp(tester, const BackupReviewScreen(), overrides: _overrides(
        seedFakes(),
        _repo(),
        FakeBackupFiles(),
        <Override>[
          fixedImport(ImportState(
            phase: ImportPhase.ready,
            snapshot: snap(<String, List<RowMap>>{}),
            summary: const ChangeSummary(),
          )),
        ],
      ));
      expect(find.text(_bn.backupHeadlineNone), findsOneWidget, reason: allTexts(tester));
      final BhorButton apply = tester.widget<BhorButton>(find.byKey(const Key('review-apply')));
      expect(apply.onPressed, isNull);
      expect(find.text(_bn.backupApplyDisabledNone), findsOneWidget);
      expect(find.byKey(const Key('review-deletions')), findsNothing);
    });

    testWidgets('QA-08: 0 changes but newer local records: says nothing changes and N are kept',
        (WidgetTester tester) async {
      await pumpApp(tester, const BackupReviewScreen(), overrides: _overrides(
        seedFakes(),
        _repo(),
        FakeBackupFiles(),
        <Override>[
          fixedImport(ImportState(
            phase: ImportPhase.ready,
            snapshot: snap(<String, List<RowMap>>{}),
            summary: const ChangeSummary(entities: <SummaryEntity, EntityChange>{
              SummaryEntity.students: EntityChange(keptLocal: 1),
            }),
          )),
        ],
      ));
      expect(find.text(_bn.backupHeadlineKeptOnly(_f.number(1))), findsOneWidget, reason: allTexts(tester));
      expect(find.text(_bn.backupHeadlineNone), findsNothing);
      expect(tester.widget<BhorButton>(find.byKey(const Key('review-apply'))).onPressed, isNull);
    });

    testWidgets('desktop: numbers on one side, named details on the other, no clipped area',
        (WidgetTester tester) async {
      await pumpApp(tester, const BackupReviewScreen(),
          viewport: TestViewport.desktop,
          overrides: _overrides(seedFakes(), _repo(), FakeBackupFiles(), <Override>[fixedImport(richState())]));
      final Rect table = tester.getRect(find.byKey(const Key('review-table')));
      final Rect deletions = tester.getRect(find.byKey(const Key('review-deletions')));
      final Rect explain = tester.getRect(find.byKey(const Key('review-explain')));
      expect(table.right, lessThan(deletions.left));
      expect(deletions.left, explain.left);
      // The last card of each column reaches the bottom of the pane.
      expect(explain.bottom, greaterThan(600));
      expect(table.bottom, greaterThan(600));
    });
  });
}
