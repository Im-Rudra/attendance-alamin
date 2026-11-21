// Today screen: the 8-case matrix (light/dark x bn/en x phone/desktop, fails on
// any exception incl. overflow) for every state, the desktop bento at the
// expanded / large / extra-large widths (every row sums to 12 columns, equal
// heights, aligned edges), and the behaviour that matters: hero, dues card,
// timeline states, day strip, absence alerts, backup nudge, banners.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/widgets/bento_grid.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/features/classes/classes_entry.dart';
import 'package:attendance_alamin/features/home/controllers/bento_layout.dart';
import 'package:attendance_alamin/features/home/ui/today_screen.dart';
import 'package:attendance_alamin/features/home/widgets/absence_alerts_tile.dart';
import 'package:attendance_alamin/features/home/widgets/attendance_today_tile.dart';
import 'package:attendance_alamin/features/home/widgets/backup_nudge_tile.dart';
import 'package:attendance_alamin/features/home/widgets/collection_tile.dart';
import 'package:attendance_alamin/features/home/widgets/dues_card.dart';
import 'package:attendance_alamin/features/home/widgets/hero_class_card.dart';
import 'package:attendance_alamin/features/home/widgets/quick_actions.dart';
import 'package:attendance_alamin/features/home/widgets/recent_payments_tile.dart';
import 'package:attendance_alamin/features/home/widgets/timeline.dart';
import 'package:attendance_alamin/features/home/widgets/week_glance_tile.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

/// Text inside the hero card (the page header repeats the date).
Finder _inHero(String text) =>
    find.descendant(of: find.byType(HeroClassCard), matching: find.text(text));

/// A Bhor icon button by its accessible name (it doubles as the tooltip).
Finder _byLabel(String label) => find.byWidgetPredicate(
      (Widget w) => w is BhorIconButton && w.semanticLabel == label,
      description: 'BhorIconButton "$label"',
    );

AppLocalizations _l10n(Lang lang) => lookupAppLocalizations(Locale(lang.code));

const LocalDate _mon = LocalDate(2026, 11, 23);
const LocalDate _tue = LocalDate(2026, 11, 24);

// ---- fixtures for the states -------------------------------------------------

/// The Monday Physics A class moved to Tuesday 11:00-12:00 (scenario 19).
ScheduleException _moveMonToTue() => ScheduleException(
      id: 'ex-move',
      batchId: kBatPhysA,
      kind: ExceptionKind.reschedule,
      slotId: kSlotPhysMon,
      originalDate: _mon,
      newDate: _tue,
      newStartMin: 660,
      newEndMin: 720,
    );

/// Tuesday: Chem B cancelled, Physics A moved in, an extra Physics A class.
SeededFakes _busyTuesday() {
  final SeededFakes f = seedFakes();
  f.store.exceptions.addAll(<ScheduleException>[
    _moveMonToTue(),
    ScheduleException(
      id: 'ex-cancel',
      batchId: kBatChemB,
      kind: ExceptionKind.cancel,
      slotId: kSlotChemTue,
      originalDate: _tue,
    ),
    ScheduleException(
      id: 'ex-extra',
      batchId: kBatPhysA,
      kind: ExceptionKind.extra,
      newDate: _tue,
      newStartMin: 1020,
      newEndMin: 1080,
    ),
  ]);
  return f;
}

SeededFakes _movedAwayMonday() {
  final SeededFakes f = seedFakes();
  f.store.exceptions.add(_moveMonToTue());
  return f;
}

/// Today's Physics A class has its roll call and nobody is absent in a row.
SeededFakes _allDone() {
  final SeededFakes f = seedFakes();
  final String occ = physOcc(kToday.toIso());
  final String sid = Ids.sessionForOcc(occ);
  f.attendance.sessions.add(AttendanceSession(
    id: sid,
    occ: occ,
    batchId: kBatPhysA,
    slotId: kSlotPhysSat,
    date: kToday,
    startMin: kPhysStart,
    endMin: kPhysEnd,
  ));
  for (final String student in <String>[kStuRahim, kStuSara, kStuNila]) {
    f.attendance.records.add(AttendanceRecord(
      id: Ids.record(occ, student),
      sessionId: sid,
      batchId: kBatPhysA,
      studentId: student,
      date: kToday,
      status: student == kStuNila ? AttendanceStatus.late : AttendanceStatus.present,
    ));
  }
  return f;
}

SeededFakes _noBatches() {
  final SeededFakes f = seedFakes();
  f.store.batches.clear();
  f.store.slots.clear();
  f.enrollments.terms.clear();
  return f;
}

/// No enrollment owes anything and no money was received yet (billing has not
/// started).
SeededFakes _noDuesNoPayments() {
  final SeededFakes f = seedFakes(withPayments: false);
  f.enrollments.terms.clear();
  return f;
}

/// Nothing owed while this month's payments are in (the seed has Sara's
/// November payment).
SeededFakes _nobodyOwes() {
  final SeededFakes f = seedFakes();
  f.enrollments.terms.clear();
  return f;
}

int get _nowMs => kTestNowUtc.millisecondsSinceEpoch;

/// Backup 10 days old, reminders planned for 1.5 more days, and a Chem B slot
/// that overlaps Physics A on Saturdays.
SeededFakes _bannersAndNudges() {
  final SeededFakes f = seedFakes(encodedSettings: <String, Object?>{
    SettingKeys.lastExportAt.id: SettingKeys.lastExportAt.encode(_nowMs - 10 * 86400000 - 1000),
    SettingKeys.remindersPlannedUntil.id:
        SettingKeys.remindersPlannedUntil.encode(_nowMs + 36 * 3600000),
  });
  f.store.slots.add(const Slot(
    id: 'slot-clash',
    batchId: kBatChemB,
    weekday: 6,
    startMin: 990,
    endMin: 1050,
  ));
  return f;
}

/// The language chip reads the saved preferences.
Override _prefs(Lang lang) => initialPrefsProvider.overrideWithValue(AppPrefs(
      lang: lang,
      themeMode: ThemeMode.light,
      reducedEffects: true,
      onboardingDone: true,
    ));

/// Today's date and minute of day for a test (the clock itself is fixed by
/// the harness and cannot be overridden twice).
List<Override> _clockAt(String date, String time) {
  final List<String> hm = time.split(':');
  return <Override>[
    todayProvider.overrideWithValue(LocalDate.parse(date)),
    nowMinutesProvider.overrideWithValue(int.parse(hm[0]) * 60 + int.parse(hm[1])),
  ];
}

// ---- helpers -----------------------------------------------------------------

/// The 8 matrix cases for one state: the screen is pumped with the clock of
/// [date] / [time] (center time) and the fakes built by [fakes].
void testStateMatrix(
  String name, {
  String date = '2026-11-21',
  String time = '10:00',
  SeededFakes Function()? fakes,
}) {
  for (final MatrixCase c in matrixCases()) {
    testWidgets('today, $name [${c.label}]', (WidgetTester tester) async {
      final SeededFakes f = (fakes ?? () => seedFakes())();
      await pumpApp(
        tester,
        const TodayScreen(),
        themeMode: c.themeMode,
        lang: c.lang,
        viewport: c.viewport,
        overrides: <Override>[
          ...f.overrides,
          _prefs(c.lang),
          ..._clockAt(date, time),
        ],
      );
      await _settle(tester);
      expectNoException(tester, 'while pumping (${c.label})');
      await tester.pumpWidget(const SizedBox.shrink());
      expectNoException(tester, 'while unmounting (${c.label})');
    });
  }
}

/// Lets the fake repositories' streams deliver and the providers rebuild.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<SeededFakes> _pumpPhone(
  WidgetTester tester, {
  SeededFakes? fakes,
  String date = '2026-11-21',
  String time = '10:00',
  Lang lang = Lang.bn,
  double height = 2400,
}) async {
  final SeededFakes f = fakes ?? seedFakes();
  await pumpApp(
    tester,
    const TodayScreen(),
    lang: lang,
    overrides: <Override>[...f.overrides, _prefs(lang), ..._clockAt(date, time)],
  );
  // Tall enough to build every card of the phone page.
  tester.view.physicalSize = Size(360, height);
  await _settle(tester);
  return f;
}

Future<SeededFakes> _pumpDesktop(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  SeededFakes? fakes,
  String date = '2026-11-21',
  String time = '10:00',
  Lang lang = Lang.bn,
}) async {
  final SeededFakes f = fakes ?? seedFakes();
  await pumpApp(
    tester,
    const TodayScreen(),
    lang: lang,
    viewport: TestViewport.desktop,
    overrides: <Override>[...f.overrides, _prefs(lang), ..._clockAt(date, time)],
  );
  tester.view.physicalSize = size;
  await _settle(tester);
  return f;
}

void main() {
  // ---- the 8-case matrix for every state ------------------------------------
  testStateMatrix('next class (10:00)');
  testStateMatrix('class running (16:30)', time: '16:30');
  testStateMatrix('class over without roll call (18:00)', time: '18:00');
  testStateMatrix('all classes done, nobody absent in a row', time: '18:00', fakes: _allDone);
  testStateMatrix('no class today (Friday)', date: '2026-11-20');
  testStateMatrix('no batches yet', fakes: _noBatches);
  testStateMatrix('nobody owes anything', fakes: _nobodyOwes);
  testStateMatrix('cancelled, moved-in and extra classes (Tuesday)',
      date: '2026-11-24', fakes: _busyTuesday);
  testStateMatrix('a class moved away (Monday)', date: '2026-11-23', fakes: _movedAwayMonday);
  testStateMatrix('a taken roll call (Wednesday)', date: '2026-11-18', time: '18:00');
  testStateMatrix('clash banner, reminder hint and backup nudge', fakes: _bannersAndNudges);

  // ---- hero -------------------------------------------------------------------
  group('hero', () {
    testWidgets('next class: countdown, class, time and the pill', (WidgetTester tester) async {
      await _pumpPhone(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      expect(find.text(l10n.todayHeroNext(l10n.todayInHours(fmt.number(6)))), findsOneWidget);
      expect(find.text(l10n.clsClassLabel('পদার্থবিজ্ঞান', 'ফিজিক্স এ')), findsWidgets);
      expect(find.text(fmt.timeRange(kPhysStart, kPhysEnd)), findsWidgets);
      // The date shows once: in the header, not again in the hero.
      expect(_inHero(fmt.weekdayDate(kToday)), findsNothing);
      expect(find.text(fmt.weekdayDate(kToday)), findsOneWidget);
      expect(find.text(l10n.todayTakeAttendance), findsWidgets);
    });

    testWidgets('a running class shows the time left', (WidgetTester tester) async {
      await _pumpPhone(tester, time: '16:30');
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      expect(find.text(l10n.todayHeroNow(l10n.todayLeftMinutes(fmt.number(30)))), findsOneWidget);
      expect(find.text(l10n.uiClassNow), findsOneWidget);
    });

    testWidgets('a finished class without roll call asks for it', (WidgetTester tester) async {
      await _pumpPhone(tester, time: '18:00');
      expect(find.text(_l10n(Lang.bn).todayHeroPending), findsOneWidget);
    });

    testWidgets('all done: the count of roll calls taken', (WidgetTester tester) async {
      await _pumpPhone(tester, time: '18:00', fakes: _allDone());
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      expect(find.text(l10n.todayHeroDone), findsOneWidget);
      expect(find.text(l10n.todayHeroDoneSub(fmt.number(1), fmt.number(1))), findsWidgets);
    });

    testWidgets('a roll call saved before the class starts counts (hero and row)',
        (WidgetTester tester) async {
      // 10:00, the Physics class starts at 16:00 and already has its session.
      await _pumpPhone(tester, fakes: _allDone());
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      expect(find.text(l10n.todayHeroDone), findsOneWidget);
      expect(find.text(l10n.todayHeroDoneSub(fmt.number(1), fmt.number(1))), findsWidgets);
      expect(find.text(l10n.todayRollPending), findsNothing);
    });

    testWidgets('no class today: rest message and the two actions', (WidgetTester tester) async {
      await _pumpPhone(tester, date: '2026-11-20');
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.text(l10n.todayHeroRest), findsOneWidget);
      expect(find.text(l10n.todayAddExtraLong), findsOneWidget);
      expect(find.text(l10n.todayOtherBatchAttendance), findsOneWidget);

      await tester.tap(find.text(l10n.todayOtherBatchAttendance));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.todayPickBatchTitle), findsOneWidget);
      expect(find.widgetWithText(BhorListRow, 'ফিজিক্স এ'), findsOneWidget);
      expect(find.widgetWithText(BhorListRow, 'কেমিস্ট্রি বি'), findsOneWidget);
    });

    testWidgets('no batches: the setup card', (WidgetTester tester) async {
      await _pumpPhone(tester, fakes: _noBatches());
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.text(l10n.todaySetupTitle), findsOneWidget);
      expect(find.text(l10n.todaySetupButton), findsOneWidget);
    });

    testWidgets('English: next class and the weekday-date line', (WidgetTester tester) async {
      await _pumpPhone(tester, lang: Lang.en);
      final AppLocalizations l10n = _l10n(Lang.en);
      expect(find.text(l10n.todayHeroNext(l10n.todayInHours('6'))), findsOneWidget);
      // The weekday-date line is the header's, shown once (not in the hero).
      expect(find.text('Saturday, 21 Nov'), findsOneWidget);
      expect(_inHero('Saturday, 21 Nov'), findsNothing);
    });
  });

  // ---- dues card --------------------------------------------------------------
  group('dues card', () {
    testWidgets('total, headline and the escalation bar', (WidgetTester tester) async {
      await _pumpPhone(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      final DuesReport r = containerOf(tester).read(duesReportProvider).requireValue;
      expect(r.studentsWithDues, greaterThan(0));
      expect(find.text(l10n.todayDuesTitle), findsOneWidget);
      expect(find.text(fmt.money(r.totalOutstandingActive)), findsWidgets);
      expect(
        find.text(l10n.todayDuesHeadline(fmt.number(r.studentsWithDues), fmt.number(r.overdueStudents))),
        findsOneWidget,
      );
      expect(find.byType(BhorEscalationBar), findsOneWidget);
      expect(find.byType(BhorTag), findsWidgets);
    });

    testWidgets('nobody owes and nothing collected yet: "no dues", no bar', (WidgetTester tester) async {
      await _pumpPhone(tester, fakes: _noDuesNoPayments());
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(l10n.todayDuesNone, 'কোনো বকেয়া নেই');
      expect(find.text(l10n.todayDuesNone), findsOneWidget);
      expect(find.text(l10n.todayDuesAllPaid), findsNothing);
      expect(find.byType(BhorEscalationBar), findsNothing);
    });

    testWidgets('nobody owes after payments this month: "everyone paid"', (WidgetTester tester) async {
      await _pumpPhone(tester, fakes: _nobodyOwes());
      expect(find.text(_l10n(Lang.bn).todayDuesAllPaid), findsOneWidget);
      expect(find.byType(BhorEscalationBar), findsNothing);
    });
  });

  // ---- timeline ---------------------------------------------------------------
  group('timeline', () {
    testWidgets('cancelled struck through, moved-in "was …", extra tag', (WidgetTester tester) async {
      await _pumpPhone(tester, date: '2026-11-24', fakes: _busyTuesday());
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);

      expect(find.text(l10n.uiClassCancelled), findsOneWidget);
      expect(find.text(l10n.uiClassMoved), findsOneWidget);
      expect(find.text(l10n.uiClassExtra), findsOneWidget);
      expect(find.text(l10n.todayMovedFrom(fmt.time(kPhysStart))), findsOneWidget);

      final Finder cancelled = find.text(l10n.clsClassLabel('রসায়ন', 'কেমিস্ট্রি বি'));
      expect(cancelled, findsOneWidget);
      expect(tester.widget<Text>(cancelled).style?.decoration, TextDecoration.lineThrough);

      // The moved-in class is the next one: hero counts down to 11:00.
      expect(find.text(l10n.todayHeroNext(l10n.todayInHours(fmt.number(1)))), findsOneWidget);
      // One row per class, in start-time order: cancelled 10:00, moved 11:00, extra 17:00.
      final List<String> keys = <String>[
        'today-class-${OccId.regular(kSlotChemTue, _tue)}',
        'today-class-${OccId.regular(kSlotPhysMon, _mon)}',
        'today-class-${OccId.extra('ex-extra')}',
      ];
      double last = -1;
      for (final String k in keys) {
        final Finder row = find.byKey(ValueKey<String>(k));
        expect(row, findsOneWidget, reason: k);
        final double top = tester.getTopLeft(row).dy;
        expect(top, greaterThan(last), reason: k);
        last = top;
      }
    });

    testWidgets('the date a class left shows "→ new time" (scenario 19)', (WidgetTester tester) async {
      await _pumpPhone(tester, date: '2026-11-23', fakes: _movedAwayMonday());
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      final String label = l10n.clsClassLabel('পদার্থবিজ্ঞান', 'ফিজিক্স এ');
      final String when = '${fmt.dateShort(_tue)} ${fmt.time(660)}';
      expect(find.text(l10n.todayMovedAway(label, when)), findsOneWidget);
      // Nothing else on Monday: the hero rests.
      expect(find.text(l10n.todayHeroRest), findsOneWidget);
    });

    testWidgets('a taken roll call shows ✓ x/y (attended of held)', (WidgetTester tester) async {
      await _pumpPhone(tester, date: '2026-11-18', time: '18:00');
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      // Rahim absent, Sara and Nila present on 18 Nov.
      expect(find.text(l10n.todayRollTaken(fmt.number(2), fmt.number(3))), findsOneWidget);
      expect(find.text(l10n.todayHeroDone), findsOneWidget);
    });

    testWidgets('a past class without roll call says so and offers the button', (WidgetTester tester) async {
      await _pumpPhone(tester, time: '18:00');
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.text(l10n.todayRollPending), findsOneWidget);
      // The timeline row's button; the hero card carries its own full-width one.
      expect(
        find.descendant(
          of: find.byType(TodayTimeline),
          matching: find.widgetWithText(BhorButton, l10n.todayTakeAttendance),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(HeroClassCard),
          matching: find.widgetWithText(BhorButton, l10n.todayTakeAttendance),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a day without a class offers "+ extra class" right in the empty state',
        (WidgetTester tester) async {
      await _pumpPhone(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      // Friday: no class in the fixtures (strip shows 20 or 27 depending on the week start).
      final Finder fri27 = find.text(fmt.digits('27'));
      await tester.tap(fri27.evaluate().isNotEmpty ? fri27.first : find.text(fmt.digits('20')).first);
      await _settle(tester);
      expect(find.text(l10n.todayNoClassesDay), findsOneWidget);
      final Finder add = find.byKey(const ValueKey<String>('today-empty-add-extra'));
      await tester.ensureVisible(add);
      expect(add, findsOneWidget);
      expect(find.text(l10n.todayAddExtra), findsOneWidget);
    });

    testWidgets('the day strip switches the day; the dues card hides until today', (WidgetTester tester) async {
      await _pumpPhone(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      expect(find.byType(DuesCard), findsOneWidget);

      // Sunday 22 Nov: Chem B at 10:00.
      await tester.tap(find.text(fmt.digits('22')));
      await _settle(tester);
      expect(find.text(l10n.todayRoutineOther(fmt.dateShort(const LocalDate(2026, 11, 22)))), findsOneWidget);
      expect(
        find.text(l10n.todayHeroOtherDay(fmt.weekdayDate(const LocalDate(2026, 11, 22)), fmt.number(1))),
        findsOneWidget,
      );
      expect(find.byType(DuesCard), findsNothing);

      // Back to today with the chip.
      await tester.tap(find.widgetWithText(BhorButton, l10n.commonToday));
      await _settle(tester);
      expect(find.text(l10n.todayRoutineToday), findsOneWidget);
      expect(find.byType(DuesCard), findsOneWidget);
    });
  });

  // ---- absence alerts (F16, scenario 13) ----------------------------------------
  group('absence alerts', () {
    testWidgets('Rahim, absent three times in a row: call and dismiss', (WidgetTester tester) async {
      // Windows has no dialer: "call" copies the guardian's number.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final SeededFakes f = await _pumpPhone(tester);
        final AppLocalizations l10n = _l10n(Lang.bn);
        final AppFormat fmt = AppFormat(Lang.bn);
        final Finder row = find.byKey(ValueKey<String>('today-alert-$kEnrRahimPhys'));
        expect(row, findsOneWidget);
        expect(find.text(l10n.todayAlertLine('রহিম উদ্দিন')), findsOneWidget);

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform, (MethodCall call) async => null);
        addTearDown(() => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null));
        await tester.tap(find.descendant(of: row, matching: _byLabel(l10n.commonCopyNumber)));
        await _settle(tester);
        expect(find.text(l10n.shellNumberCopied(fmt.digits('01811223344'))), findsOneWidget);

        await tester.tap(find.descendant(of: row, matching: _byLabel(l10n.todayAlertDismiss)));
        await _settle(tester);
        expect(
          f.localMeta.values[LocalMetaKeys.absenceDismissed(kEnrRahimPhys)],
          Ids.sessionForOcc(physOcc('2026-11-18')),
        );
        expect(row, findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('everyone attends: the phone page has no alert card, the tile says so', (WidgetTester tester) async {
      await _pumpPhone(tester, fakes: _allDone());
      expect(find.text(_l10n(Lang.bn).todayAlertsTitle), findsNothing);
      await _pumpDesktop(tester, fakes: _allDone());
      expect(find.text(_l10n(Lang.bn).todayAlertsEmpty), findsOneWidget);
    });
  });

  // ---- backup nudge, reminder hint, clash banner ------------------------------------
  group('banners and nudges', () {
    testWidgets('phone: the backup card appears only when the nudge is due', (WidgetTester tester) async {
      final AppLocalizations l10n = _l10n(Lang.bn);
      await _pumpPhone(tester);
      expect(find.text(l10n.todayBackupButton), findsNothing);

      await _pumpPhone(tester, fakes: _bannersAndNudges());
      expect(find.text(l10n.todayBackupButton), findsOneWidget);
      expect(find.text(l10n.todayBackupAge(AppFormat(Lang.bn).number(10))), findsOneWidget);
      expect(find.text(l10n.todayBackupDueHint), findsOneWidget);
    });

    testWidgets('desktop: the backup tile is always there', (WidgetTester tester) async {
      final AppLocalizations l10n = _l10n(Lang.bn);
      await _pumpDesktop(tester);
      expect(find.byType(BackupNudgeTile), findsOneWidget);
      expect(find.text(l10n.todayBackupNever), findsOneWidget);
      expect(find.text(l10n.todayBackupOkHint), findsOneWidget);
    });

    testWidgets('the reminder window hint and the clash banner (scenario 21)', (WidgetTester tester) async {
      await _pumpPhone(tester, fakes: _bannersAndNudges());
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.text(l10n.todayRemindersHint(AppFormat(Lang.bn).number(1))), findsOneWidget);
      expect(find.text(l10n.todayConflictTitle), findsOneWidget);
      expect(find.text(l10n.todayConflictFix), findsOneWidget);
    });

    testWidgets('no hint and no banner on a normal day', (WidgetTester tester) async {
      await _pumpPhone(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.text(l10n.todayConflictTitle), findsNothing);
      expect(find.text(l10n.todayRemindersHintZero), findsNothing);
    });
  });

  // ---- tiles ----------------------------------------------------------------------
  group('tiles', () {
    testWidgets('collection: received this month over expected, by method', (WidgetTester tester) async {
      await _pumpPhone(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      expect(find.byType(CollectionTile), findsOneWidget);
      expect(find.text(fmt.money(1000)), findsWidgets);
      expect(find.text(l10n.todayCollectionOf(fmt.money(4600))), findsOneWidget);
    });

    testWidgets('attendance today: classes with a roll call and the present rate', (WidgetTester tester) async {
      await _pumpPhone(tester, fakes: _allDone(), time: '18:00');
      final AppLocalizations l10n = _l10n(Lang.bn);
      final AppFormat fmt = AppFormat(Lang.bn);
      expect(find.text(l10n.todayAttendanceTaken(fmt.number(1), fmt.number(1))), findsOneWidget);
      expect(find.text(fmt.percent(100)), findsOneWidget);
    });

    testWidgets('recent payments: newest first, with the share button', (WidgetTester tester) async {
      await _pumpDesktop(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.byType(RecentPaymentsTile), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('today-receipt-rcp-4')), findsOneWidget);
      expect(_byLabel(l10n.todayRecentShare), findsWidgets);
    });

    testWidgets('quick actions: four pills on the phone page', (WidgetTester tester) async {
      await _pumpPhone(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.byType(QuickActionsCard), findsOneWidget);
      for (final String label in <String>[
        l10n.todayQuickCollect,
        l10n.todayQuickAddStudent,
        l10n.todayQuickExtra,
        l10n.todayQuickSearch,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('the language chip lives in More, not on the Today header', (WidgetTester tester) async {
      await _pumpPhone(tester);
      expect(find.byKey(const Key('language-chip')), findsNothing);
    });
  });

  // ---- desktop: bento at the three wide classes + week toggle -------------------------
  group('desktop bento', () {
    final Map<TodayTile, Type> types = <TodayTile, Type>{
      TodayTile.hero: HeroClassCard,
      TodayTile.dues: DuesCard,
      TodayTile.timeline: TodayTimeline,
      TodayTile.collection: CollectionTile,
      TodayTile.attendance: AttendanceTodayTile,
      TodayTile.alerts: AbsenceAlertsTile,
      TodayTile.quick: QuickActionsTile,
      TodayTile.backup: BackupNudgeTile,
      TodayTile.recent: RecentPaymentsTile,
      TodayTile.week: WeekGlanceTile,
    };

    for (final (String, Size, WindowClass, double) c in <(String, Size, WindowClass, double)>[
      ('expanded', const Size(900, 700), WindowClass.expanded, 16),
      ('large', const Size(1280, 800), WindowClass.large, 20),
      ('extra-large', const Size(1700, 900), WindowClass.extraLarge, 24),
    ]) {
      final String name = c.$1;
      final Size size = c.$2;
      final WindowClass wc = c.$3;
      final double gutter = c.$4;

      testWidgets('$name: every row sums to 12, equal heights, aligned edges', (WidgetTester tester) async {
        await _pumpDesktop(tester, size: size);
        expect(WindowClass.fromWidth(size.width), wc);
        expect(find.byType(BentoGrid), findsOneWidget);
        final Rect grid = tester.getRect(find.byType(BentoGrid));
        final List<TileSlot> slots = bentoSlots(wc);

        // Exactly the tiles of this class are on screen.
        for (final MapEntry<TodayTile, Type> e in types.entries) {
          final bool expected = slots.any((TileSlot s) => s.tile == e.key);
          expect(find.byType(e.value), expected ? findsOneWidget : findsNothing,
              reason: '${e.key} at $name');
        }

        final Map<TodayTile, Rect> rect = <TodayTile, Rect>{
          for (final TileSlot s in slots) s.tile: tester.getRect(find.byType(types[s.tile]!)),
        };

        // Rows: widths of the tiles crossing a row plus the gutters fill the grid.
        for (int r = 0; r < bentoRowCount(wc); r++) {
          final List<TileSlot> crossing =
              slots.where((TileSlot s) => s.row <= r && r < s.row + s.rowSpan).toList();
          double sum = gutter * (crossing.length - 1);
          for (final TileSlot s in crossing) {
            sum += rect[s.tile]!.width;
          }
          expect(sum, closeTo(grid.width, 0.6), reason: 'row $r at $name');
          expect(crossing.fold<int>(0, (int a, TileSlot s) => a + s.colSpan), 12);
        }

        // Equal heights and a common top for tiles that start on the same row.
        final double unit = rect[TodayTile.hero]!.height;
        for (final TileSlot s in slots) {
          final Rect r = rect[s.tile]!;
          expect(r.height, closeTo(s.rowSpan * unit + (s.rowSpan - 1) * gutter, 0.6),
              reason: '${s.tile} height at $name');
          expect(r.top, closeTo(grid.top + s.row * (unit + gutter), 0.6),
              reason: '${s.tile} top at $name');
          expect(r.left, greaterThanOrEqualTo(grid.left - 0.1));
          expect(r.right, lessThanOrEqualTo(grid.right + 0.1));
        }
        expectNoException(tester, name);
      });
    }

    testWidgets('the day / week toggle swaps the bento for the real week grid', (WidgetTester tester) async {
      await _pumpDesktop(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.byType(BentoGrid), findsOneWidget);
      expect(find.byType(WeekGrid), findsNothing);

      await tester.tap(find.text(l10n.todayViewWeek));
      await _settle(tester);
      expect(find.byType(WeekGrid), findsOneWidget);
      expect(find.byType(BentoGrid), findsNothing);

      await tester.tap(find.text(l10n.todayViewDay));
      await _settle(tester);
      expect(find.byType(BentoGrid), findsOneWidget);
      expect(find.byType(WeekGrid), findsNothing);
      expectNoException(tester, 'toggle');
    });

    testWidgets('extra-large: tapping the week tile opens the week grid', (WidgetTester tester) async {
      await _pumpDesktop(tester, size: const Size(1700, 900));
      await tester.tap(find.byType(WeekGlanceTile));
      await _settle(tester);
      expect(find.byType(WeekGrid), findsOneWidget);
    });

    testWidgets('large: quick actions sit behind one "New…" menu, not in a tile', (WidgetTester tester) async {
      await _pumpDesktop(tester);
      final AppLocalizations l10n = _l10n(Lang.bn);
      expect(find.byType(QuickActionsTile), findsNothing);
      expect(find.byKey(const Key('language-chip')), findsNothing);
      await tester.tap(find.widgetWithText(BhorButton, l10n.todayNewMenu));
      await _settle(tester);
      expect(find.text(l10n.todayQuickCollect), findsOneWidget);
      expect(find.text(l10n.todayQuickAddStudent), findsOneWidget);
      expect(find.text(l10n.todayQuickExtra), findsOneWidget);
    });

    testWidgets('medium window: stacked cards, paired tiles of equal height', (WidgetTester tester) async {
      await _pumpDesktop(tester, size: const Size(720, 1000));
      expect(find.byType(BentoGrid), findsNothing);
      expect(find.byType(DayStrip), findsOneWidget);
      final Rect hero = tester.getRect(find.byType(HeroClassCard));
      final Rect dues = tester.getRect(find.byType(DuesCard));
      expect(hero.top, closeTo(dues.top, 0.6));
      expect(hero.height, closeTo(dues.height, 0.6));
      final Rect collection = tester.getRect(find.byType(CollectionTile));
      final Rect attendance = tester.getRect(find.byType(AttendanceTodayTile));
      expect(collection.top, closeTo(attendance.top, 0.6));
      expect(collection.height, closeTo(attendance.height, 0.6));
      expectNoException(tester, 'medium');
    });

    testWidgets('a short window keeps the minimum tile height and scrolls', (WidgetTester tester) async {
      await _pumpDesktop(tester, size: const Size(1280, 560));
      final Rect hero = tester.getRect(find.byType(HeroClassCard));
      expect(hero.height, greaterThanOrEqualTo(184));
      expectNoException(tester, 'short window');
    });
  });

  // ---- bigger text (1.3x) --------------------------------------------------------
  for (final TestViewport v in TestViewport.values) {
    testWidgets('no overflow at 1.3x text, ${v.name}, Bangla', (WidgetTester tester) async {
      final SeededFakes f = _bannersAndNudges();
      await pumpApp(
        tester,
        Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: const TodayScreen(),
          ),
        ),
        viewport: v,
        overrides: <Override>[...f.overrides, _prefs(Lang.bn)],
      );
      await _settle(tester);
      expectNoException(tester, '1.3x ${v.name}');
    });
  }
}
