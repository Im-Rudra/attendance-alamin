// M6-B: class actions sheet (cancel + undo), reschedule and extra sheets with
// the live clash card (Product scenarios 17, 19, 25), day strip and week grid.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';
import 'package:attendance_alamin/features/classes/classes_entry.dart';
import 'package:attendance_alamin/features/classes/controllers/class_controller.dart';
import 'package:attendance_alamin/features/classes/widgets/clash_panel.dart';
import 'package:attendance_alamin/features/classes/widgets/class_actions_sheet.dart';
import 'package:attendance_alamin/features/classes/widgets/extra_class_sheet.dart';
import 'package:attendance_alamin/features/classes/widgets/reschedule_sheet.dart';

import '../../helpers/fakes/fake_structure_repos.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

/// A Bhor icon button by its accessible name (it doubles as the tooltip).
Finder _byLabel(String label) => find.byWidgetPredicate(
      (Widget w) => w is BhorIconButton && w.semanticLabel == label,
      description: 'BhorIconButton "$label"',
    );

/// The fake schedule repository with the REAL clash engine behind its checks
/// and writes, and a `resolve` that sees cancelled / moved / extra classes.
class EngineScheduleRepository extends FakeScheduleRepository {
  EngineScheduleRepository(super.store);

  SlotCheckResult _check(String batchId, LocalDate date, int start, int end, String? replacing) {
    return ScheduleEngine.checkSingle(
      candidate: Occurrence(
        occ: 'candidate',
        batchId: batchId,
        date: date,
        startMin: start,
        endMin: end,
        kind: OccurrenceKind.extra,
      ),
      all: store.schedules(),
      excludeOcc: replacing,
    );
  }

  @override
  Future<SlotCheckResult> checkSingle({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    String? replacingOcc,
  }) async =>
      _check(batchId, date, startMin, endMin, replacingOcc);

  @override
  Future<String> addExtra({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    String? note,
  }) async {
    final SlotCheckResult r = _check(batchId, date, startMin, endMin, null);
    if (!r.ok) throw ScheduleClashException(r);
    return super.addExtra(batchId: batchId, date: date, startMin: startMin, endMin: endMin, note: note);
  }

  @override
  Future<void> reschedule(String occ,
      {required LocalDate newDate, required int startMin, required int endMin}) async {
    final OccurrenceInfo? info = await resolve(occ);
    final Occurrence? o = info?.occurrence;
    if (o != null) {
      final SlotCheckResult r = _check(o.batchId, newDate, startMin, endMin, occ);
      if (!r.ok) throw ScheduleClashException(r);
    }
    return super.reschedule(occ, newDate: newDate, startMin: startMin, endMin: endMin);
  }

  @override
  Future<OccurrenceInfo?> resolve(String occ) async {
    final OccRef ref;
    try {
      ref = OccId.parse(occ);
    } on FormatException {
      return null;
    }
    final List<BatchSchedule> schedules = store.schedules();
    LocalDate from;
    LocalDate to;
    if (ref is RegularOccRef) {
      from = ref.originalDate;
      to = from.addDays(60);
    } else if (ref is ExtraOccRef) {
      ScheduleException? ex;
      for (final ScheduleException e in store.exceptions) {
        if (e.id == ref.exceptionId) ex = e;
      }
      if (ex == null || ex.newDate == null) return null;
      from = ex.newDate!;
      to = from;
    } else {
      return null;
    }
    final ExpandResult res = ScheduleEngine.expand(range: DateRange(from, to), batches: schedules);
    BatchSchedule of(String batchId) => schedules.firstWhere((BatchSchedule s) => s.batch.id == batchId);
    for (final Occurrence o in res.occurrences) {
      if (o.occ != occ) continue;
      final BatchSchedule bs = of(o.batchId);
      return OccurrenceInfo(batch: bs.batch, subjectName: bs.subjectName, occurrence: o);
    }
    for (final CancelledOccurrence c in res.cancelled) {
      if (c.occ != occ) continue;
      final BatchSchedule bs = of(c.batchId);
      return OccurrenceInfo(
        batch: bs.batch,
        subjectName: bs.subjectName,
        cancelled: true,
        occurrence: Occurrence(
          occ: occ,
          batchId: c.batchId,
          date: c.date,
          startMin: c.startMin,
          endMin: c.endMin,
          kind: OccurrenceKind.regular,
          slotId: (ref as RegularOccRef).slotId,
        ),
      );
    }
    return null;
  }
}

/// Every fake wired in (as `SeededFakes.overrides`), but with the engine-backed
/// schedule repository.
List<Override> engineOverrides(SeededFakes f) => <Override>[
      subjectsRepositoryProvider.overrideWithValue(f.subjects),
      batchesRepositoryProvider.overrideWithValue(f.batches),
      scheduleRepositoryProvider.overrideWithValue(EngineScheduleRepository(f.store)),
      studentsRepositoryProvider.overrideWithValue(f.students),
      enrollmentsRepositoryProvider.overrideWithValue(f.enrollments),
      paymentsRepositoryProvider.overrideWithValue(f.payments),
      attendanceRepositoryProvider.overrideWithValue(f.attendance),
      otherIncomeRepositoryProvider.overrideWithValue(f.otherIncome),
      settingsRepositoryProvider.overrideWithValue(f.settings),
      localMetaRepositoryProvider.overrideWithValue(f.localMeta),
    ];

ScheduleException cancelOf(String slotId, String batchId, LocalDate date) => ScheduleException(
      id: Ids.exceptionForOcc(OccId.regular(slotId, date)),
      batchId: batchId,
      kind: ExceptionKind.cancel,
      slotId: slotId,
      originalDate: date,
    );

ScheduleException extraOf(String id, String batchId, LocalDate date, int start, int end) => ScheduleException(
      id: id,
      batchId: batchId,
      kind: ExceptionKind.extra,
      newDate: date,
      newStartMin: start,
      newEndMin: end,
    );

/// A button that runs [onOpen] with its own (long-lived) context.
class _Host extends StatelessWidget {
  const _Host(this.onOpen);

  final void Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: () => onOpen(context), child: const Text('open')),
        ),
      );
}

Future<void> openHost(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Overrides for the matrix: the seed week with a cancelled Monday, an extra
/// Chem B Thursday, a second Physics A class on Saturday morning and Wednesday
/// moved to Friday 11:00.
List<Override> weekOverrides() {
  final SeededFakes f = seedFakes();
  f.store.exceptions
    ..add(cancelOf(kSlotPhysMon, kBatPhysA, const LocalDate(2026, 11, 23)))
    ..add(extraOf('x-thu', kBatChemB, const LocalDate(2026, 11, 26), 1020, 1080))
    ..add(extraOf('x-morning', kBatPhysA, kToday, 480, 540))
    ..add(ScheduleException(
      id: 'move-wed',
      batchId: kBatPhysA,
      kind: ExceptionKind.reschedule,
      slotId: kSlotPhysWed,
      originalDate: const LocalDate(2026, 11, 25),
      newDate: const LocalDate(2026, 11, 27),
      newStartMin: 660,
      newEndMin: 720,
    ));
  return engineOverrides(f);
}

void main() {
  final String satOcc = physOcc('2026-11-21');

  group('screen matrix', () {
    testScreenMatrix(
      'ClassActionsSheet',
      () => ClassActionsSheet(occ: satOcc),
      overrides: () => engineOverrides(seedFakes()),
    );

    testScreenMatrix(
      'ClassActionsSheet cancelled',
      () => ClassActionsSheet(occ: satOcc),
      overrides: () {
        final SeededFakes f = seedFakes();
        f.store.exceptions.add(cancelOf(kSlotPhysSat, kBatPhysA, kToday));
        return engineOverrides(f);
      },
    );

    testScreenMatrix(
      'RescheduleSheet',
      () => RescheduleSheet(occ: satOcc),
      overrides: () => engineOverrides(seedFakes()),
    );

    testScreenMatrix(
      'ExtraClassSheet',
      () => const ExtraClassSheet(),
      overrides: () => engineOverrides(seedFakes()),
    );

    testScreenMatrix(
      'ExtraClassSheet with a clash',
      () => const ExtraClassSheet(batchId: kBatPhysA, date: LocalDate(2026, 11, 22), startMin: 630),
      overrides: () => engineOverrides(seedFakes()),
      verify: (WidgetTester tester) async {
        // Physics A on Sunday 10:30 overlaps Chem B's 10:00-11:00.
        await tester.pump();
        expect(find.byType(ClashPanel), findsOneWidget);
      },
    );

    testScreenMatrix(
      'DayStrip',
      () => DayStrip(selected: kToday, onSelected: (LocalDate _) {}),
      overrides: weekOverrides,
    );

    testScreenMatrix(
      'WeekGrid',
      () => const WeekGrid(weekStart: kToday),
      overrides: weekOverrides,
    );

    testScreenMatrix(
      'WeekGrid empty week',
      () => const WeekGrid(weekStart: LocalDate(2027, 3, 6)),
      overrides: () {
        // Weekly slots repeat forever, so an empty week needs no slots at all.
        final SeededFakes f = seedFakes();
        f.store.slots.clear();
        return engineOverrides(f);
      },
      verify: (WidgetTester tester) async {
        expect(find.byType(BhorEmptyState), findsOneWidget);
      },
    );
  });

  group('cancel with undo', () {
    testWidgets('cancel removes the class, offers guardians and Undo brings it back', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        _Host((BuildContext c) => showClassActionsSheet(c, occ: satOcc)),
        overrides: engineOverrides(f),
      );
      await openHost(tester);

      await tester.tap(find.text('এই দিনের ক্লাস বাতিল'));
      await tester.pumpAndSettle();

      expect(f.store.exceptions, hasLength(1));
      expect(f.store.exceptions.single.kind, ExceptionKind.cancel);
      expect(find.text('ক্লাস বাতিল হয়েছে'), findsOneWidget);
      expect(find.text('অভিভাবকদের জানান'), findsOneWidget);

      await tester.tap(find.text('ফিরিয়ে নিন'));
      await tester.pumpAndSettle();

      expect(f.store.exceptions, isEmpty);
      expect(find.text('ক্লাস আগের অবস্থায় ফিরেছে'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a cancelled class offers "undo cancellation" and no roll call', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      f.store.exceptions.add(cancelOf(kSlotPhysSat, kBatPhysA, kToday));
      await pumpApp(
        tester,
        _Host((BuildContext c) => showClassActionsSheet(c, occ: satOcc)),
        overrides: engineOverrides(f),
      );
      await openHost(tester);

      expect(find.text('হাজিরা নিন'), findsNothing);
      expect(find.text('এই দিনের ক্লাস বাতিল'), findsNothing);
      await tester.tap(find.text('বাতিল তুলে নিন'));
      await tester.pumpAndSettle();
      expect(f.store.exceptions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('the guardians message names the class, time and the next class', () {
      const AppFormat fmt = AppFormat(Lang.bn);
      final SeededFakes f = seedFakes();
      final List<BatchSchedule> schedules = f.store.schedules();
      final BatchSchedule phys = schedules.firstWhere((BatchSchedule s) => s.batch.id == kBatPhysA);
      final Occurrence o = Occurrence(
        occ: satOcc,
        batchId: kBatPhysA,
        date: kToday,
        startMin: kPhysStart,
        endMin: kPhysEnd,
        kind: OccurrenceKind.regular,
        slotId: kSlotPhysSat,
      );
      final Occurrence? next = nextClassAfter(o, schedules);
      expect(next, isNotNull);
      expect(next!.date, const LocalDate(2026, 11, 23));
      expect(next.batchId, kBatPhysA);

      final String text = buildCancelMessage(
        l10n: lookupAppLocalizations(const Locale('bn')),
        fmt: fmt,
        info: OccurrenceInfo(batch: phys.batch, subjectName: phys.subjectName, occurrence: o),
        today: kToday,
        schedules: schedules,
        center: 'আমার কোচিং',
      );
      expect(text, contains('আজ'));
      expect(text, contains(phys.subjectName));
      expect(text, contains(phys.batch.name));
      expect(text, contains(fmt.timeRange(kPhysStart, kPhysEnd)));
      expect(text, contains('পরবর্তী ক্লাস'));
      expect(text, contains(fmt.weekdayDate(next.date)));
      expect(text, endsWith('— আমার কোচিং'));
    });
  });

  group('two classes of one batch in a day (scenario 25)', () {
    testWidgets('an extra class the same day saves and gets its own titled sheet', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      String? created;
      await pumpApp(
        tester,
        _Host((BuildContext c) async {
          created = await showExtraClassSheet(c, batchId: kBatPhysA, date: kToday, startMin: 480);
        }),
        overrides: engineOverrides(f),
      );
      await openHost(tester);

      // The batch already has the 4 pm class that day: noted for awareness.
      expect(find.textContaining('বিকাল ৪:০০–৫:০০'), findsOneWidget);
      await tester.tap(find.text('যোগ করুন'));
      await tester.pumpAndSettle();

      expect(created, isNotNull);
      expect(created, startsWith('x.'));
      expect(f.store.exceptions.single.kind, ExceptionKind.extra);

      final ProviderContainer container = containerOf(tester);
      container.listen(dayPlanProvider(kToday), (_, _) {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final DayPlan plan = container.read(dayPlanProvider(kToday)).requireValue;
      final List<DayClass> phys = plan.classes.where((DayClass c) => c.batch.id == kBatPhysA).toList();
      expect(phys, hasLength(2));
      expect(phys.map((DayClass c) => c.startMin).toList(), <int>[480, kPhysStart]);
      expect(phys.first.occ, isNot(phys.last.occ));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the sheet title names the time when the batch has two classes that day', (WidgetTester tester) async {
      const AppFormat fmt = AppFormat(Lang.bn);
      final SeededFakes f = seedFakes();
      f.store.exceptions.add(extraOf('x-morning', kBatPhysA, kToday, 480, 540));
      await pumpApp(
        tester,
        _Host((BuildContext c) => showClassActionsSheet(c, occ: satOcc)),
        overrides: engineOverrides(f),
      );
      await openHost(tester);
      expect(find.text('শুধু ${fmt.weekdayDate(kToday)} · ${fmt.time(kPhysStart)}'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an extra class overlapping the batch\'s own class is refused with suggestions', (WidgetTester tester) async {
      await pumpApp(
        tester,
        _Host((BuildContext c) => showExtraClassSheet(c, batchId: kBatPhysA, date: kToday, startMin: 990)),
        lang: Lang.en,
        viewport: TestViewport.desktop,
        overrides: engineOverrides(seedFakes()),
      );
      await openHost(tester);

      expect(find.text('Time clash'), findsOneWidget);
      expect(find.text('Another class is at this time — change the time'), findsOneWidget);
      final Finder add = find.widgetWithText(BhorButton, 'Add class');
      expect(tester.widget<BhorButton>(add).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('reschedule clash (scenario 19)', () {
    testWidgets('refused with free suggestions; taking one saves and moves the class', (WidgetTester tester) async {
      const AppFormat fmt = AppFormat(Lang.en);
      final SeededFakes f = seedFakes();
      final String monOcc = physOcc('2026-11-23');
      bool? saved;
      await pumpApp(
        tester,
        _Host((BuildContext c) async {
          saved = await showRescheduleSheet(c, occ: monOcc);
        }),
        lang: Lang.en,
        viewport: TestViewport.desktop,
        overrides: engineOverrides(f),
      );
      await openHost(tester);

      // Nothing changed yet: Save is disabled and says why.
      expect(tester.widget<BhorButton>(find.widgetWithText(BhorButton, 'Save')).onPressed, isNull);
      expect(find.text('Change the date or time to save'), findsOneWidget);

      // Move to Tuesday 24 Nov, 10:30 (Chem B has 10:00-11:00 there).
      await tester.tap(find.text(fmt.weekdayDate(const LocalDate(2026, 11, 23))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('24'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 22; i++) {
        await tester.tap(_byLabel('15 min earlier'));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('Time clash'), findsOneWidget);
      expect(find.textContaining('রসায়ন'), findsOneWidget);
      expect(tester.widget<BhorButton>(find.widgetWithText(BhorButton, 'Save')).onPressed, isNull);
      expect(find.text('Another class is at this time — change the time'), findsOneWidget);
      // Nearest free times either side: 11:00 AM-12:00 PM (later) and 9:00-10:00 AM.
      final Finder later = find.text('Use ${fmt.timeRange(660, 720)}');
      expect(later, findsOneWidget);
      expect(find.text('Earlier: ${fmt.timeRange(540, 600)}'), findsOneWidget);
      expect(f.store.exceptions, isEmpty);

      await tester.tap(later);
      await tester.pumpAndSettle();
      expect(find.text('Time clash'), findsNothing);
      await tester.tap(find.widgetWithText(BhorButton, 'Save'));
      await tester.pumpAndSettle();

      expect(saved, isTrue);
      final ScheduleException moved = f.store.exceptions.single;
      expect(moved.kind, ExceptionKind.reschedule);
      expect(moved.newDate, const LocalDate(2026, 11, 24));
      expect(moved.newStartMin, 660);
      expect(moved.newEndMin, 720);

      final ProviderContainer container = containerOf(tester);
      container.listen(dayPlanProvider(const LocalDate(2026, 11, 24)), (_, _) {});
      container.listen(dayPlanProvider(const LocalDate(2026, 11, 23)), (_, _) {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final DayPlan tue = container.read(dayPlanProvider(const LocalDate(2026, 11, 24))).requireValue;
      expect(tue.classes.where((DayClass c) => c.state == ClassState.moved), hasLength(1));
      final DayPlan mon = container.read(dayPlanProvider(const LocalDate(2026, 11, 23))).requireValue;
      expect(mon.movedAway, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('held classes and future dates (QA-04, QA-15)', () {
    testWidgets('a future class offers no roll call and says why', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        _Host((BuildContext c) => showClassActionsSheet(c, occ: physOcc('2026-11-23'))),
        overrides: engineOverrides(f),
      );
      await openHost(tester);

      expect(find.text('হাজিরা নিন'), findsOneWidget);
      expect(find.text('আগামী দিনের হাজিরা নেওয়া যাবে না'), findsOneWidget);
      await tester.tap(find.text('হাজিরা নিন'));
      await tester.pumpAndSettle();
      // Nothing happened: the sheet is still open on the same class.
      expect(find.text('আগামী দিনের হাজিরা নেওয়া যাবে না'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets("today's class still offers the roll call", (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        _Host((BuildContext c) => showClassActionsSheet(c, occ: satOcc)),
        overrides: engineOverrides(f),
      );
      await openHost(tester);
      expect(find.text('হাজিরা নিন'), findsOneWidget);
      expect(find.text('আগামী দিনের হাজিরা নেওয়া যাবে না'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a held class cannot be moved to a future date', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      final String wedOcc = physOcc('2026-11-18');
      if (await f.attendance.getSession(wedOcc) == null) {
        f.attendance.sessions.add(AttendanceSession(
          id: Ids.sessionForOcc(wedOcc),
          occ: wedOcc,
          batchId: kBatPhysA,
          slotId: kSlotPhysWed,
          date: const LocalDate(2026, 11, 18),
          startMin: kPhysStart,
          endMin: kPhysEnd,
        ));
      }
      const AppFormat fmt = AppFormat(Lang.en);
      await pumpApp(
        tester,
        _Host((BuildContext c) => showRescheduleSheet(c, occ: wedOcc)),
        lang: Lang.en,
        viewport: TestViewport.desktop,
        overrides: engineOverrides(f),
      );
      await openHost(tester);

      const String held = "Attendance for this class is already taken \u2014 it can't move to a future date";
      await tester.tap(find.text(fmt.weekdayDate(const LocalDate(2026, 11, 18))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('dp-day-22')));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(held), findsOneWidget);
      expect(tester.widget<BhorButton>(find.widgetWithText(BhorButton, 'Save')).onPressed, isNull);

      // An earlier day is fine: the roll call moves with the class.
      await tester.tap(find.text(fmt.weekdayDate(const LocalDate(2026, 11, 22))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('dp-day-17')));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(held), findsNothing);
      expect(f.store.exceptions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('extra class clash with a weekly class (scenario 17)', () {
    testWidgets('Physics A extra on Sunday 10:30 is refused; the later suggestion saves', (WidgetTester tester) async {
      const AppFormat fmt = AppFormat(Lang.en);
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        _Host((BuildContext c) => showExtraClassSheet(c, batchId: kBatPhysA, date: const LocalDate(2026, 11, 22), startMin: 630)),
        lang: Lang.en,
        viewport: TestViewport.desktop,
        overrides: engineOverrides(f),
      );
      await openHost(tester);

      expect(find.text('Time clash'), findsOneWidget);
      expect(find.text('Use ${fmt.timeRange(660, 720)}'), findsOneWidget);
      expect(find.text('Earlier: ${fmt.timeRange(540, 600)}'), findsOneWidget);
      expect(tester.widget<BhorButton>(find.widgetWithText(BhorButton, 'Add class')).onPressed, isNull);

      await tester.tap(find.text('Use ${fmt.timeRange(660, 720)}'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(BhorButton, 'Add class'));
      await tester.pumpAndSettle();
      expect(f.store.exceptions.single.newStartMin, 660);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('week grid', () {
    testWidgets('two classes of one batch are two blocks, each with its time; cancelled and ghost shown', (WidgetTester tester) async {
      const AppFormat fmt = AppFormat(Lang.bn);
      await pumpApp(
        tester,
        const WeekGrid(weekStart: kToday),
        viewport: TestViewport.desktop,
        overrides: weekOverrides(),
      );
      await tester.pump();

      // QA-17: state marks are icons, never font glyphs the font lacks.
      // Two extras this week: Physics A Saturday morning and Chem B Thursday.
      expect(find.byKey(const Key('week-block-extra')), findsNWidgets(2));
      expect(find.text(fmt.timeRange(480, 540)), findsOneWidget);
      // The cancelled Monday class is struck through.
      final Iterable<Text> struck = tester.widgetList<Text>(find.byType(Text)).where(
          (Text t) => t.style?.decoration == TextDecoration.lineThrough);
      expect(struck, isNotEmpty);
      // The moved Wednesday class leaves a ghost pointing to Friday 11:00.
      expect(find.byKey(const Key('week-ghost-arrow')), findsOneWidget);
      expect(find.textContaining(fmt.time(660)), findsWidgets);
      expect(find.byKey(const Key('week-block-moved')), findsOneWidget);
      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        final String plain = t.data ?? t.textSpan?.toPlainText() ?? '';
        expect(plain.contains(RegExp('[→↻✓＋]')), isFalse, reason: plain);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('keyboard: arrows select, Enter opens, N adds an extra class, ] changes the week', (WidgetTester tester) async {
      const AppFormat fmt = AppFormat(Lang.en);
      final List<String> opened = <String>[];
      await pumpApp(
        tester,
        WeekGrid(weekStart: kToday, onSelectOcc: opened.add),
        lang: Lang.en,
        viewport: TestViewport.desktop,
        overrides: weekOverrides(),
      );
      await tester.pump();

      // Focus the grid by tapping its header text.
      await tester.tap(find.text('${fmt.dateShort(kToday)} – ${fmt.dateShort(kToday.addDays(6))}'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, hasLength(1));
      expect(opened.single, 'x.x-morning');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened.last, satOcc);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pumpAndSettle();
      expect(find.byType(ExtraClassSheet), findsOneWidget);
      await tester.tap(_byLabel('Close sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${fmt.dateShort(kToday)} – ${fmt.dateShort(kToday.addDays(6))}'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(find.text('${fmt.dateShort(kToday.addDays(7))} – ${fmt.dateShort(kToday.addDays(13))}'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pump();
      expect(find.text('${fmt.dateShort(kToday)} – ${fmt.dateShort(kToday.addDays(6))}'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('day strip', () {
    testWidgets('shows seven days, a today chip back button and reports taps', (WidgetTester tester) async {
      final List<LocalDate> picked = <LocalDate>[];
      await pumpApp(
        tester,
        DayStrip(selected: kToday.addDays(10), onSelected: picked.add),
        overrides: weekOverrides(),
      );
      await tester.pump();

      expect(find.byType(BhorPressable), findsWidgets);
      await tester.tap(find.text('আজ'));
      expect(picked.last, kToday);
      await tester.tap(_byLabel('পরের সপ্তাহ'));
      expect(picked.last, kToday.addDays(17));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('weekStartOf snaps to the configured first weekday', () {
      expect(weekStartOf(const LocalDate(2026, 11, 25), 6), const LocalDate(2026, 11, 21));
      expect(weekStartOf(const LocalDate(2026, 11, 21), 6), const LocalDate(2026, 11, 21));
      expect(weekStartOf(const LocalDate(2026, 11, 25), 1), const LocalDate(2026, 11, 23));
    });
  });
}
