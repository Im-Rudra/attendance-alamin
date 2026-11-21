// M6-C tests: every screen in the matrix, create a batch with a new subject,
// the fee-change month question with its partial-month warning (scenario 11),
// archive with the last billable month (scenario 9) and unarchive with a clash
// (scenario 21).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/batches_repository.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/ui/archived_batches_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batch_detail_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batch_form_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batches_screen.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/batches/widgets/billing_cards.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fakes/fake_structure_repos.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations bn = lookupAppLocalizations(const Locale('bn'));
const AppFormat fmtBn = AppFormat(Lang.bn);

/// Stand-in for M6-A's slot editor: one tap reports a Thursday 18:00 slot.
Widget slotStub(
  BuildContext context, {
  required List<SlotDraft> initial,
  required ValueChanged<List<SlotDraft>> onChanged,
  String? batchId,
  ValueChanged<SlotCheckResult>? onCheck,
}) =>
    TextButton(
      key: const Key('slot-stub'),
      onPressed: () {
        onChanged(const <SlotDraft>[SlotDraft(weekday: 4, startMin: 1080, endMin: 1140)]);
        onCheck?.call(const SlotCheckResult());
      },
      child: const Text('slot'),
    );

/// Remembers the last billable month the archive dialog chose.
class SpyBatches extends FakeBatchesRepository {
  SpyBatches(FakeStructureStore super.store);

  YearMonth? lastBillable;
  bool? acceptedClashes;
  bool? waivedGap;

  @override
  Future<void> archive(String id, {required LocalDate on, required YearMonth lastBillableMonth}) {
    lastBillable = lastBillableMonth;
    return super.archive(id, on: on, lastBillableMonth: lastBillableMonth);
  }

  @override
  Future<int> unarchive(String id, {bool acceptClashes = false, bool waiveGap = true}) {
    acceptedClashes = acceptClashes;
    waivedGap = waiveGap;
    return super.unarchive(id, acceptClashes: acceptClashes, waiveGap: waiveGap);
  }
}

List<Override> withBatches(SeededFakes f, BatchesRepository batches, {bool stubSlots = true}) => <Override>[
      subjectsRepositoryProvider.overrideWithValue(f.subjects),
      batchesRepositoryProvider.overrideWithValue(batches),
      scheduleRepositoryProvider.overrideWithValue(f.schedule),
      studentsRepositoryProvider.overrideWithValue(f.students),
      enrollmentsRepositoryProvider.overrideWithValue(f.enrollments),
      paymentsRepositoryProvider.overrideWithValue(f.payments),
      attendanceRepositoryProvider.overrideWithValue(f.attendance),
      otherIncomeRepositoryProvider.overrideWithValue(f.otherIncome),
      settingsRepositoryProvider.overrideWithValue(f.settings),
      localMetaRepositoryProvider.overrideWithValue(f.localMeta),
      if (stubSlots) batchSlotEditorBuilderProvider.overrideWithValue(slotStub),
    ];

Batch archivedPhysics() => Batch(
      id: kBatPhysA,
      subjectId: kSubPhysics,
      name: kBatches[0].name,
      billingType: BillingType.prepaid,
      createdOn: const LocalDate(2026, 1, 1),
      sortOrder: 0,
      archivedOn: const LocalDate(2026, 11, 15),
    );

Future<void> tallWindow(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 1500);
  await tester.pump();
}

Future<void> settleSome(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  late SeededFakes fakes;
  List<Override> fresh() {
    fakes = seedFakes();
    return fakes.overrides;
  }

  group('screens in the matrix', () {
    testScreenMatrix('BatchesScreen', () => const BatchesScreen(), overrides: fresh,
        verify: (WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(kBatches[0].name), findsWidgets);
      expect(find.text(kSubjects[0].name), findsOneWidget);
    });
    testScreenMatrix('BatchesScreen selected', () => const BatchesScreen(selectedId: kBatPhysA),
        overrides: fresh);
    testScreenMatrix('BatchesScreen empty', () => const BatchesScreen(), overrides: () {
      fakes = seedFakes();
      fakes.store.batches.clear();
      fakes.store.slots.clear();
      return fakes.overrides;
    });
    testScreenMatrix('BatchDetailScreen', () => const BatchDetailScreen(batchId: kBatPhysA),
        overrides: fresh, verify: (WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TabBar), findsOneWidget);
    });
    testScreenMatrix('BatchDetailScreen archived', () => const BatchDetailScreen(batchId: kBatPhysA),
        overrides: () {
      fakes = seedFakes();
      fakes.store.replaceBatch(archivedPhysics());
      return fakes.overrides;
    });
    testScreenMatrix('BatchFormScreen new', () => const BatchFormScreen(), overrides: fresh);
    testScreenMatrix('BatchFormScreen edit', () => const BatchFormScreen(batchId: kBatPhysA),
        overrides: fresh);
    testScreenMatrix('ArchivedBatchesScreen', () => const ArchivedBatchesScreen(), overrides: () {
      fakes = seedFakes();
      fakes.store.replaceBatch(archivedPhysics());
      return fakes.overrides;
    });
    testScreenMatrix('ArchivedBatchesScreen empty', () => const ArchivedBatchesScreen(), overrides: fresh);
  });

  group('desktop panes', () {
    testWidgets('nothing selected shows the overview, not a blank pane', (WidgetTester tester) async {
      fakes = seedFakes();
      await pumpApp(tester, const BatchesScreen(),
          viewport: TestViewport.desktop, overrides: fakes.overrides);
      await settleSome(tester);
      expect(find.text(bn.batchOverviewPick), findsOneWidget);
      expect(find.text(bn.batchOverviewDuesByBatch), findsOneWidget);
    });

    testWidgets('a selected batch gets detail and context panes', (WidgetTester tester) async {
      fakes = seedFakes();
      await pumpApp(tester, const BatchesScreen(selectedId: kBatPhysA),
          viewport: TestViewport.desktop, overrides: fakes.overrides);
      await settleSome(tester);
      expect(find.text(bn.batchContextWeek), findsOneWidget);
      expect(find.text(bn.batchTabSchedule), findsOneWidget);
    });
  });

  group('create a batch', () {
    testWidgets('with a new subject creates the subject, the batch and its fee', (WidgetTester tester) async {
      fakes = seedFakes();
      await pumpApp(tester, const BatchFormScreen(), overrides: withBatches(fakes, fakes.batches));
      await tallWindow(tester);
      await settleSome(tester);

      final int subjectsBefore = fakes.store.subjects.length;
      final int batchesBefore = fakes.store.batches.length;

      await tester.enterText(find.byKey(const Key('batch-form-subject')), 'জীববিজ্ঞান');
      await tester.pump();
      expect(find.text(bn.batchSubjectNew('জীববিজ্ঞান')), findsOneWidget);
      // Save stays disabled with its reason until fee and time are given.
      expect(find.text(bn.batchReasonFee), findsOneWidget);

      await tester.enterText(find.byKey(const Key('batch-form-fee')), '৫০০');
      await tester.pump();
      expect(find.text(bn.batchReasonSlots), findsOneWidget);

      await tester.tap(find.byKey(const Key('slot-stub')));
      await tester.pump();
      expect(find.text(bn.batchReasonSlots), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, bn.commonSave));
      await settleSome(tester);

      expect(fakes.store.subjects.length, subjectsBefore + 1);
      expect(fakes.store.subjects.last.name, 'জীববিজ্ঞান');
      expect(fakes.store.batches.length, batchesBefore + 1);
      final Batch created = fakes.store.batches.last;
      expect(created.subjectId, fakes.store.subjects.last.id);
      expect(created.billingType, BillingType.prepaid);
      expect(created.name, bn.batchDefaultName(fmtBn.number(batchesBefore + 1)));
      expect(fakes.store.fees[created.id]!.single.amount, 500);
      expect(fakes.store.slots.where((Slot s) => s.batchId == created.id).single.weekday, 4);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('typing an existing subject reuses it', (WidgetTester tester) async {
      fakes = seedFakes();
      await pumpApp(tester, const BatchFormScreen(), overrides: withBatches(fakes, fakes.batches));
      await tallWindow(tester);
      await settleSome(tester);
      final int subjectsBefore = fakes.store.subjects.length;

      await tester.enterText(find.byKey(const Key('batch-form-subject')), '  রসায়ন ');
      await tester.enterText(find.byKey(const Key('batch-form-fee')), '700');
      await tester.pump();
      expect(find.text(bn.batchSubjectNew('রসায়ন')), findsNothing);
      await tester.tap(find.byKey(const Key('slot-stub')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, bn.commonSave));
      await settleSome(tester);

      expect(fakes.store.subjects.length, subjectsBefore);
      expect(fakes.store.batches.last.subjectId, kSubChemistry);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('billing defaults to the last used type', (WidgetTester tester) async {
      fakes = seedFakes(encodedSettings: <String, Object?>{
        SettingKeys.lastBillingType.id: 'postpaid',
      });
      await pumpApp(tester, const BatchFormScreen(), overrides: withBatches(fakes, fakes.batches));
      await tallWindow(tester);
      await settleSome(tester);
      final BillingCards cards = tester.widget<BillingCards>(find.byType(BillingCards));
      expect(cards.value, BillingType.postpaid);
      // Plain wording, never the words prepaid / postpaid.
      expect(find.text(bn.batchBillingPrepaid), findsOneWidget);
      expect(find.text(bn.batchBillingPostpaidExample), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('fee change (scenario 11)', () {
    testWidgets('asks which month and warns about partial months', (WidgetTester tester) async {
      fakes = seedFakes();
      fakes.store.partialMonths = 3;
      await pumpApp(tester, const BatchFormScreen(batchId: kBatPhysA),
          overrides: withBatches(fakes, fakes.batches));
      await tallWindow(tester);
      await settleSome(tester);

      await tester.enterText(find.byKey(const Key('batch-form-fee')), '1200');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, bn.commonSave));
      await settleSome(tester);

      expect(find.text(bn.batchFeeFromTitle), findsOneWidget);
      expect(find.text(bn.batchFeeFromBody(fmtBn.money(1000), fmtBn.money(1200))), findsOneWidget);
      expect(find.text(bn.batchFeePartialWarn(fmtBn.number(3))), findsOneWidget);

      // Choose December; earlier months keep the old fee.
      await tester.tap(find.text(fmtBn.monthYear(const YearMonth(2026, 12))));
      await settleSome(tester);
      await tester.tap(find.widgetWithText(FilledButton, bn.batchFeeConfirm));
      await settleSome(tester, 10);

      final List<FeePeriod> fees = fakes.store.fees[kBatPhysA]!;
      expect(fees, contains(const FeePeriod(effective: YearMonth(2026, 12), amount: 1200)));
      expect(fees, contains(const FeePeriod(effective: YearMonth(2026, 1), amount: 1000)));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('QA-01: offers months before the quick chips (back 24 months)',
        (WidgetTester tester) async {
      fakes = seedFakes();
      await pumpApp(tester, const BatchFormScreen(batchId: kBatPhysA),
          overrides: withBatches(fakes, fakes.batches));
      await tallWindow(tester);
      await settleSome(tester);
      await tester.enterText(find.byKey(const Key('batch-form-fee')), '1200');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, bn.commonSave));
      await settleSome(tester);

      expect(find.text(bn.batchFeeEarlierMonth), findsOneWidget);
      await tester.tap(find.byKey(const Key('fee-change-earlier')));
      await settleSome(tester);
      await tester.tap(find.text(fmtBn.monthYear(const YearMonth(2026, 8))).last);
      await settleSome(tester);
      await tester.tap(find.widgetWithText(FilledButton, bn.batchFeeConfirm));
      await settleSome(tester, 10);

      final List<FeePeriod> fees = fakes.store.fees[kBatPhysA]!;
      expect(fees, contains(const FeePeriod(effective: YearMonth(2026, 8), amount: 1200)));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('no warning when no paid month turns partial; dismissing saves nothing',
        (WidgetTester tester) async {
      fakes = seedFakes();
      fakes.store.partialMonths = 0;
      await pumpApp(tester, const BatchFormScreen(batchId: kBatPhysA),
          overrides: withBatches(fakes, fakes.batches));
      await tallWindow(tester);
      await settleSome(tester);
      await tester.enterText(find.byKey(const Key('batch-form-fee')), '900');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, bn.commonSave));
      await settleSome(tester);
      expect(find.text(bn.batchFeeNoPartial), findsOneWidget);
      // Dismiss the sheet by tapping the scrim.
      await tester.tapAt(const Offset(10, 10));
      await settleSome(tester, 10);
      expect(fakes.store.fees[kBatPhysA]!.length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an unchanged fee is saved without the month question', (WidgetTester tester) async {
      fakes = seedFakes();
      await pumpApp(tester, const BatchFormScreen(batchId: kBatPhysA),
          overrides: withBatches(fakes, fakes.batches));
      await tallWindow(tester);
      await settleSome(tester);
      await tester.enterText(find.byKey(const Key('batch-form-name')), 'ফিজিক্স সি');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, bn.commonSave));
      await settleSome(tester);
      expect(find.text(bn.batchFeeFromTitle), findsNothing);
      expect(fakes.store.batches.firstWhere((Batch b) => b.id == kBatPhysA).name, 'ফিজিক্স সি');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('archive and unarchive', () {
    Future<void> openMenu(WidgetTester tester, String item) async {
      await tester.tap(find.byTooltip(bn.commonMore));
      await settleSome(tester, 8);
      await tester.tap(find.text(item));
      await settleSome(tester, 6);
    }

    testWidgets('archive asks the last billable month and archives (scenario 9)',
        (WidgetTester tester) async {
      fakes = seedFakes();
      final SpyBatches spy = SpyBatches(fakes.store);
      await pumpApp(tester, const BatchDetailScreen(batchId: kBatPhysA),
          overrides: withBatches(fakes, spy));
      await settleSome(tester);

      await openMenu(tester, bn.batchMenuArchive);
      expect(find.text(bn.batchArchiveTitle(kBatches[0].name)), findsOneWidget);
      // Archive day 21 >= 11: November is the default last billable month.
      expect(
        find.text(bn.batchArchiveLbmHelp(fmtBn.monthYear(const YearMonth(2026, 11)))),
        findsOneWidget,
      );
      await tester.tap(find.text(fmtBn.monthYear(const YearMonth(2026, 10))));
      await settleSome(tester, 3);
      expect(
        find.text(bn.batchArchiveLbmHelp(fmtBn.monthYear(const YearMonth(2026, 10)))),
        findsOneWidget,
      );
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(bn.batchArchiveConfirm),
      ));
      await settleSome(tester, 8);

      expect(spy.lastBillable, const YearMonth(2026, 10));
      expect(fakes.store.batches.firstWhere((Batch b) => b.id == kBatPhysA).archivedOn, kToday);
      // The detail now says so and offers the way back.
      expect(find.text(bn.batchArchivedBanner(fmtBn.date(kToday))), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('cancelling the archive dialog changes nothing', (WidgetTester tester) async {
      fakes = seedFakes();
      await pumpApp(tester, const BatchDetailScreen(batchId: kBatPhysA),
          overrides: withBatches(fakes, fakes.batches));
      await settleSome(tester);
      await openMenu(tester, bn.batchMenuArchive);
      await tester.tap(find.text(bn.commonCancel));
      await settleSome(tester, 6);
      expect(fakes.store.batches.firstWhere((Batch b) => b.id == kBatPhysA).archived, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('unarchive without clashes confirms and restores the batch', (WidgetTester tester) async {
      fakes = seedFakes();
      fakes.store.replaceBatch(archivedPhysics());
      final SpyBatches spy = SpyBatches(fakes.store);
      await pumpApp(tester, const BatchDetailScreen(batchId: kBatPhysA),
          overrides: withBatches(fakes, spy));
      await settleSome(tester);

      await tester.tap(find.text(bn.batchMenuUnarchive));
      await settleSome(tester, 8);
      expect(find.text(bn.batchUnarchiveTitle(kBatches[0].name)), findsOneWidget);
      expect(find.text(bn.batchUnarchiveClash), findsNothing);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(bn.batchUnarchiveConfirm),
      ));
      await settleSome(tester, 8);

      expect(spy.acceptedClashes, isFalse);
      expect(fakes.store.batches.firstWhere((Batch b) => b.id == kBatPhysA).archived, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('unarchive lists the clash and only proceeds via fix-the-schedule (scenario 21)',
        (WidgetTester tester) async {
      fakes = seedFakes();
      fakes.store.replaceBatch(archivedPhysics());
      fakes.store.clash = const SlotCheckResult(groups: <ClashGroup>[
        ClashGroup(
          batchId: kBatChemB,
          startMin: kChemStart,
          endMin: kChemEnd,
          everyWeek: true,
          weekday: 7,
          existingKind: OccurrenceKind.regular,
          count: 4,
        ),
      ]);
      final SpyBatches spy = SpyBatches(fakes.store);
      await pumpApp(tester, const BatchDetailScreen(batchId: kBatPhysA),
          overrides: withBatches(fakes, spy));
      await settleSome(tester);

      await tester.tap(find.text(bn.batchMenuUnarchive));
      await settleSome(tester, 8);

      final String line = bn.batchClashLine(
        kSubjects[1].name,
        kBatches[1].name,
        bn.batchClashEvery(fmtBn.weekdayName(7)),
        fmtBn.timeRange(kChemStart, kChemEnd),
      );
      expect(find.text(bn.batchUnarchiveClash), findsOneWidget);
      expect(find.text(line), findsOneWidget);
      // The plain confirm is replaced by the fix-the-schedule one.
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text(bn.batchUnarchiveConfirm)),
        findsNothing,
      );
      await tester.tap(find.text(bn.batchUnarchiveFix));
      await settleSome(tester, 8);

      expect(spy.acceptedClashes, isTrue);
      expect(fakes.store.batches.firstWhere((Batch b) => b.id == kBatPhysA).archived, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('delete sits behind the menu and shows the impact numbers', (WidgetTester tester) async {
      fakes = seedFakes();
      await pumpApp(tester, const BatchDetailScreen(batchId: kBatPhysA),
          overrides: withBatches(fakes, fakes.batches));
      await settleSome(tester);
      // Not on the surface of the screen.
      expect(find.text(bn.batchMenuDelete), findsNothing);
      await openMenu(tester, bn.batchMenuDelete);
      expect(find.text(bn.batchDeleteTitle(kBatches[0].name)), findsOneWidget);
      expect(
        find.textContaining(bn.batchDeleteHint),
        findsOneWidget,
      );
      await tester.tap(find.text(bn.commonCancel));
      await settleSome(tester, 5);
      expect(fakes.store.batches.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('pure helpers', () {
    test('feeIn picks the period in force', () {
      const List<FeePeriod> fees = <FeePeriod>[
        FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
        FeePeriod(effective: YearMonth(2026, 12), amount: 1200),
      ];
      expect(feeIn(fees, const YearMonth(2026, 11)), 1000);
      expect(feeIn(fees, const YearMonth(2026, 12)), 1200);
      expect(feeIn(fees, const YearMonth(2025, 6)), 1000);
      expect(feeIn(const <FeePeriod>[], const YearMonth(2026, 1)), isNull);
    });

    test('gapMonthsOnUnarchive counts the months between LBM and this month', () {
      const Enrollment ended = Enrollment(
        id: 'e1',
        studentId: 's1',
        batchId: 'b1',
        joinDate: LocalDate(2026, 1, 5),
        startMonth: YearMonth(2026, 1),
        endMonth: YearMonth(2026, 9),
      );
      const Enrollment leftEarlier = Enrollment(
        id: 'e2',
        studentId: 's2',
        batchId: 'b1',
        joinDate: LocalDate(2026, 1, 5),
        startMonth: YearMonth(2026, 1),
        endMonth: YearMonth(2026, 5),
        endDate: LocalDate(2026, 5, 20),
      );
      // Oct and Nov lie between Sep and Dec; a student who left stays out.
      expect(gapMonthsOnUnarchive(<Enrollment>[ended, leftEarlier], const YearMonth(2026, 12)), 2);
      expect(gapMonthsOnUnarchive(<Enrollment>[ended], const YearMonth(2026, 10)), 0);
      expect(gapMonthsOnUnarchive(const <Enrollment>[], const YearMonth(2026, 10)), 0);
    });

    test('scheduleSummary shares one time across days and lists mixed times', () {
      const List<Slot> same = <Slot>[
        Slot(id: 'a', batchId: 'b', weekday: 1, startMin: 960, endMin: 1020),
        Slot(id: 'b', batchId: 'b', weekday: 6, startMin: 960, endMin: 1020),
      ];
      expect(scheduleSummary(fmtBn, same),
          '${fmtBn.weekdayShort(6)}, ${fmtBn.weekdayShort(1)} · ${fmtBn.timeRange(960, 1020)}');
      const List<Slot> mixed = <Slot>[
        Slot(id: 'a', batchId: 'b', weekday: 1, startMin: 960, endMin: 1020),
        Slot(id: 'b', batchId: 'b', weekday: 6, startMin: 480, endMin: 540),
      ];
      expect(scheduleSummary(fmtBn, mixed).contains(' · '), isTrue);
      expect(scheduleSummary(fmtBn, const <Slot>[]), isEmpty);
    });
  });
}
