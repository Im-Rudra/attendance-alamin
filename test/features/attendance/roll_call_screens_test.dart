// M7-A: roll call screens and sheets in the 8-case matrix, plus the flows of
// Product scenarios 12 (roll call), 23 (screen part: opening one occurrence)
// and 25 (two classes of one batch in a day).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/shell/templates/templates.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/attendance/attendance_entry.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';
import 'package:attendance_alamin/features/attendance/ui/batch_roll_call_launcher.dart';
import 'package:attendance_alamin/features/attendance/ui/roll_call_screen.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_header.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_row.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_skeleton.dart';
import 'package:attendance_alamin/features/attendance/widgets/session_chooser_sheet.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

/// A Bhor icon button by its accessible name (it doubles as the tooltip).
Finder _byLabel(String label) => find.byWidgetPredicate(
      (Widget w) => w is BhorIconButton && w.semanticLabel == label,
      description: 'BhorIconButton "$label"',
    );

const LocalDate _friday = LocalDate(2026, 11, 20);
const LocalDate _sunday = LocalDate(2026, 11, 22);

Future<void> open(
  WidgetTester tester,
  Widget screen,
  SeededFakes f, {
  Lang lang = Lang.en,
  TestViewport viewport = TestViewport.phone,
}) async {
  await pumpApp(tester, screen, lang: lang, viewport: viewport, overrides: f.overrides);
  await tester.pumpAndSettle();
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  // ---- the matrix ---------------------------------------------------------

  testScreenMatrix(
    'RollCallScreen',
    () => RollCallScreen(occ: physOcc('2026-11-21')),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.text('রহিম উদ্দিন'), findsOneWidget);
      expect(find.byType(RollRow), findsNWidgets(3));
    },
  );

  testScreenMatrix(
    'RollCallScreen saved past day',
    () => RollCallScreen(occ: physOcc('2026-11-18')),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(RollRow), findsNWidgets(3));
    },
  );

  testScreenMatrix(
    'BatchRollCallLauncher ad-hoc class',
    () => const BatchRollCallLauncher(batchId: kBatPhysA, date: _friday),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(AdHocTimeCard), findsOneWidget);
    },
  );

  testScreenMatrix(
    'BatchRollCallLauncher future date',
    () => const BatchRollCallLauncher(batchId: kBatChemB, date: _sunday),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(RollRow), findsNWidgets(2));
    },
  );

  testScreenMatrix(
    'SessionChooserSheet',
    () => const SessionChooserSheet(
      date: kToday,
      choices: <SessionChoice>[
        SessionChoice(
          occ: 'a',
          startMin: 480,
          endMin: 540,
          taken: true,
          tally: AttendanceTally(present: 27, absent: 3),
        ),
        SessionChoice(occ: 'b', startMin: 1020, endMin: 1080),
        SessionChoice(occ: 'c', startMin: 1140, endMin: 1200, cancelled: true),
      ],
    ),
  );

  testScreenMatrix(
    'RollStatusSheet',
    () => const RollStatusSheet(name: 'রহিম উদ্দিন', current: AttendanceStatus.late),
  );

  testScreenMatrix(
    'BatchAttendanceTab',
    () => const BatchAttendanceTab(batchId: kBatPhysA),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(BhorStatText), findsNWidgets(2));
    },
  );

  testScreenMatrix(
    'BatchAttendanceTab without sessions',
    () => const BatchAttendanceTab(batchId: kBatPhysA),
    overrides: () => seedFakes(withAttendance: false).overrides,
    verify: (WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(BhorStatText), findsNWidgets(2));
    },
  );

  testScreenMatrix(
    'EnrollmentAttendanceSummary',
    () => const Padding(
      padding: EdgeInsets.all(16),
      child: EnrollmentAttendanceSummary(studentId: kStuRahim, batchId: kBatPhysA),
    ),
    overrides: () => seedFakes().overrides,
    verify: (WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(BhorTag), findsNWidgets(5));
    },
  );

  /// The live count chips above the roster (the footer line is gone).
void _expectCounts(String a, String b, String c, [String? d]) {
  for (final String label in <String>[a, b, c, ?d]) {
    expect(
      find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.label == label),
      findsOneWidget,
      reason: label,
    );
  }
}

// ---- scenario 12: roll call ---------------------------------------------

  testWidgets('all present by default; taps change the counts; save writes the day', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    final String occ = physOcc('2026-11-21');
    await open(tester, RollCallScreen(occ: occ), f);

    _expectCounts('Present 3', 'Absent 0', 'Late 0');
    expect(find.text('Save attendance (3)'), findsOneWidget);
    expect(find.text('Everyone is marked present. Tap only the absent ones.'), findsOneWidget);

    final double rowTop = tester.getTopLeft(find.text('রহিম উদ্দিন')).dy;
    await tester.tap(find.text('রহিম উদ্দিন'));
    await tester.pump();
    _expectCounts('Present 2', 'Absent 1', 'Late 0');
    // The hint stays: the roster does not shift under the finger.
    expect(find.text('Everyone is marked present. Tap only the absent ones.'), findsOneWidget);
    expect(tester.getTopLeft(find.text('রহিম উদ্দিন')).dy, rowTop);
    expect(f.localMeta.values.keys, contains('rollcall_draft:$occ'));

    await tester.tap(find.text('Save attendance (3)'));
    await tester.pumpAndSettle();
    expect(f.attendance.sessions, hasLength(1));
    expect(f.attendance.sessions.single.occ, occ);
    final Map<String, AttendanceStatus> marks = <String, AttendanceStatus>{
      for (final AttendanceRecord r in f.attendance.records) r.studentId: r.status,
    };
    expect(marks[kStuRahim], AttendanceStatus.absent);
    expect(marks[kStuSara], AttendanceStatus.present);
    expect(marks[kStuNila], AttendanceStatus.present);
    expect(f.localMeta.values.keys, isNot(contains('rollcall_draft:$occ')));
    await unmount(tester);
  });

  testWidgets('Done returns to the screen the teacher came from, not a tab', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    final String occ = physOcc('2026-11-21');
    final GoRouter router = GoRouter(
      initialLocation: '/rollcall',
      routes: <RouteBase>[
        GoRoute(path: '/today', builder: (_, __) => const BhorScaffold(body: Text('TODAY-PAGE'))),
        GoRoute(path: '/students', builder: (_, __) => const BhorScaffold(body: Text('STUDENTS-PAGE'))),
        GoRoute(path: '/rollcall', builder: (_, __) => RollCallScreen(occ: occ, returnTo: '/today')),
      ],
    );
    addTearDown(router.dispose);
    await open(tester, Router.withConfig(config: router), f);
    await tester.tap(find.text('Save attendance (3)'));
    await tester.pumpAndSettle();
    expect(find.text('TODAY-PAGE'), findsOneWidget);
    expect(find.text('STUDENTS-PAGE'), findsNothing);
    await unmount(tester);
  });

  testWidgets('while loading the roll call shows a roster skeleton, not a spinner', (WidgetTester tester) async {
    await pumpApp(tester, const BhorScaffold(body: RollSkeleton()));
    expect(find.byKey(const Key('roll-skeleton')), findsOneWidget);
    expect(find.byType(BhorSpinner), findsNothing);
  });

  testWidgets('dark mode: an absent row keeps the normal surface (at most a faint danger wash)', (WidgetTester tester) async {
    await pumpApp(
      tester,
      BhorTheme(
        data: BhorThemeData.dark(),
        child: const BhorScaffold(
          body: RollRow(name: 'রহিম উদ্দিন', roll: 1, status: AttendanceStatus.absent),
        ),
      ),
      themeMode: ThemeMode.dark,
    );
    final BhorColors c = BhorColors.dark;
    await tester.pumpAndSettle();
    final AnimatedContainer card = tester.widget<AnimatedContainer>(
      find.descendant(of: find.byType(RollRow), matching: find.byType(AnimatedContainer)).first,
    );
    final Color fill = (card.decoration! as BoxDecoration).color!;
    expect(fill, RollRow.fillOf(c, AttendanceStatus.absent));
    expect(fill, isNot(c.absentBg), reason: 'the grey absent tint read as disabled (b277 X4)');
    // Barely different from the plain surface.
    expect((fill.r - c.surface.r).abs(), lessThan(0.05));
    expect((fill.g - c.surface.g).abs(), lessThan(0.05));
    expect((fill.b - c.surface.b).abs(), lessThan(0.05));
    // Primary text on the tinted row, never dark-on-dark.
    final Text name = tester.widget<Text>(find.text('রহিম উদ্দিন'));
    expect(name.style?.color, c.text);
    final Text initials = tester.widget<Text>(find.text('রউ'));
    expect(initials.style?.color, c.accent);
  });

  testWidgets('reopening a saved day: late counts as attended and autosaves', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    final String occ = physOcc('2026-11-18');
    await open(tester, RollCallScreen(occ: occ), f);

    expect(find.text('You are viewing attendance of a past day'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    _expectCounts('Present 2', 'Absent 1', 'Late 0');

    await tester.tap(find.descendant(of: find.byType(RollRow).first, matching: find.byIcon(BhorIcons.late)));
    await tester.pumpAndSettle();
    _expectCounts('Present 2', 'Absent 0', 'Late 1');
    final AttendanceRecord rahim = f.attendance.records.firstWhere((AttendanceRecord r) =>
        r.sessionId == Ids.sessionForOcc(occ) && r.studentId == kStuRahim);
    expect(rahim.status, AttendanceStatus.late);
    expect(rahim.status.attended, isTrue);
  });

  testWidgets('long-press opens the status sheet and marks a student excused', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f);

    await tester.longPress(find.text('রহিম উদ্দিন'));
    await tester.pumpAndSettle();
    expect(find.byType(RollStatusSheet), findsOneWidget);
    await tester.tap(find.text('Excused'));
    await tester.pumpAndSettle();
    _expectCounts('Present 2', 'Absent 0', 'Late 0', 'Excused 1');
  });

  testWidgets('an unsaved draft survives an app restart', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    final String occ = physOcc('2026-11-21');
    await open(tester, RollCallScreen(occ: occ), f);
    await tester.tap(find.text('রহিম উদ্দিন'));
    await tester.pump();
    expect(f.localMeta.values.keys, contains('rollcall_draft:$occ'));

    await unmount(tester);
    await open(tester, RollCallScreen(occ: occ), f);
    expect(find.text('Your earlier unfinished attendance was restored'), findsOneWidget);
    _expectCounts('Present 2', 'Absent 1', 'Late 0');
    expect(f.attendance.sessions, isEmpty);
  });

  testWidgets('leaving with changes asks; discard drops the draft, save keeps the day', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    final String occ = physOcc('2026-11-21');
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext context) => Center(
          child: BhorButton(
            label: 'go',
            onPressed: () => openRollCallForBatchDate(context, batchId: kBatPhysA, date: kToday),
          ),
        ),
      ),
      lang: Lang.en,
      overrides: f.overrides,
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Save attendance (3)'), findsOneWidget);

    await tester.tap(find.text('রহিম উদ্দিন'));
    await tester.pump();
    await tester.tap(_byLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Attendance not saved. Save now?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
    expect(f.attendance.sessions, isEmpty);
    expect(f.localMeta.values.keys, isNot(contains('rollcall_draft:$occ')));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('রহিম উদ্দিন'));
    await tester.pump();
    await tester.tap(_byLabel('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(f.attendance.sessions, hasLength(1));
    expect(find.text('go'), findsOneWidget);
    await unmount(tester);
  });

  // ---- scenario 25: two classes of one batch in a day -----------------------

  testWidgets('two classes on one day: chooser first, then one roll call each', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    final String extra = await f.schedule.addExtra(batchId: kBatPhysA, date: kToday, startMin: 1080, endMin: 1140);
    await open(tester, const BatchRollCallLauncher(batchId: kBatPhysA, date: kToday), f);

    expect(find.text('Which class?'), findsOneWidget);
    await tester.tap(find.text('4:00–5:00 PM'));
    await tester.pumpAndSettle();
    expect(find.byType(BhorChip), findsNWidgets(2));
    await tester.tap(find.text('Save attendance (3)'));
    await tester.pumpAndSettle();
    expect(f.attendance.sessions, hasLength(1));
    expect(f.attendance.sessions.single.occ, physOcc('2026-11-21'));
    // The "saved" snackbar covers the bottom bar until it times out.
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(BhorChip, '6:00–7:00 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('রহিম উদ্দিন'));
    await tester.pump();
    await tester.tap(find.text('Save attendance (3)'));
    await tester.pumpAndSettle();
    expect(f.attendance.sessions, hasLength(2));
    expect(<String>{for (final AttendanceSession s in f.attendance.sessions) s.occ},
        <String>{physOcc('2026-11-21'), extra});
    await unmount(tester);
  });

  // ---- unscheduled, cancelled, archived, future ------------------------------

  testWidgets('a day without a class becomes an ad-hoc extra class on save', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, const BatchRollCallLauncher(batchId: kBatPhysA, date: _friday), f);

    expect(find.text('No class is scheduled at this time — it will be saved as an extra class'), findsOneWidget);
    expect(find.text('You are viewing attendance of a past day'), findsOneWidget);
    await tester.tap(find.text('Save attendance (3)'));
    await tester.pumpAndSettle();

    expect(f.attendance.sessions, hasLength(1));
    final AttendanceSession s = f.attendance.sessions.single;
    expect(s.occ, startsWith('x.'));
    expect(s.date, _friday);
    expect(s.startMin, kPhysStart);
    expect(s.endMin, kPhysEnd);
    expect(f.attendance.records, hasLength(3));
    await unmount(tester);
  });

  testWidgets('a clash on the extra class blocks the save with its reason', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    f.store.clash = const SlotCheckResult(groups: <ClashGroup>[
      ClashGroup(
        batchId: kBatChemB,
        startMin: kPhysStart,
        endMin: kPhysEnd,
        everyWeek: false,
        weekday: 5,
        existingKind: OccurrenceKind.regular,
        count: 1,
        date: _friday,
      ),
    ]);
    await open(tester, const BatchRollCallLauncher(batchId: kBatPhysA, date: _friday), f);

    expect(find.byType(BhorClashCard), findsOneWidget);
    expect(find.text('Fix the time clash first'), findsOneWidget);
    final BhorButton save = tester.widget<BhorButton>(find.widgetWithText(BhorButton, 'Save attendance (3)'));
    expect(save.onPressed, isNull);
  });

  testWidgets('a cancelled class says so and saving removes the cancellation', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    final String occ = physOcc('2026-11-21');
    await f.schedule.cancel(occ);
    await open(tester, RollCallScreen(occ: occ), f);

    expect(find.text('This class was cancelled — taking attendance removes the cancellation'), findsOneWidget);
    await tester.tap(find.text('Save attendance (3)'));
    await tester.pumpAndSettle();
    expect(f.attendance.uncancelled, <String>[occ]);
    expect(f.attendance.sessions, hasLength(1));
    await unmount(tester);
  });

  testWidgets('an archived batch is read-only', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    f.store.replaceBatch(const Batch(
      id: kBatPhysA,
      subjectId: kSubPhysics,
      name: 'ফিজিক্স এ',
      billingType: BillingType.prepaid,
      createdOn: LocalDate(2026, 1, 1),
      sortOrder: 0,
      archivedOn: LocalDate(2026, 11, 19),
    ));
    await open(tester, RollCallScreen(occ: physOcc('2026-11-18')), f);

    expect(find.text('This batch is archived — attendance is read-only'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('রহিম উদ্দিন'));
    await tester.pump();
    _expectCounts('Present 2', 'Absent 1', 'Late 0');
  });

  testWidgets('a future date cannot be taken', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await open(tester, const BatchRollCallLauncher(batchId: kBatChemB, date: _sunday), f);

    expect(find.text('Attendance cannot be taken for a future date'), findsOneWidget);
    await tester.tap(find.text('করিম হোসেন'));
    await tester.pump();
    _expectCounts('Present 2', 'Absent 0', 'Late 0');
    expect(f.attendance.sessions.where((AttendanceSession s) => s.date == _sunday), isEmpty);
  });

  // ---- desktop keys, shrink-wrapped widgets -----------------------------------

  testWidgets('desktop: status labels are full words, not one letter', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f,
        lang: Lang.bn, viewport: TestViewport.desktop);
    expect(find.text('উপস্থিত'), findsWidgets);
    expect(find.text('উ'), findsNothing);
    await unmount(tester);
  });

  testWidgets('desktop keys: J moves, A marks absent, Ctrl+S saves', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f, viewport: TestViewport.desktop);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final Map<String, AttendanceStatus> marks = <String, AttendanceStatus>{
      for (final AttendanceRecord r in f.attendance.records) r.studentId: r.status,
    };
    expect(marks[kStuRahim], AttendanceStatus.absent);
    expect(marks[kStuSara], AttendanceStatus.present);
    await unmount(tester);
  });

  // ---- W2-RollCall: the desktop roll call (docs/council/15 R1-R5) ----------

  testWidgets('desktop: one focus page, sticky bar with counts and Save, no right rail', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f, viewport: TestViewport.desktop);

    expect(find.byType(BhorFocusPage), findsOneWidget);
    // Content is capped at 880 and the three rows are stacked in ONE column.
    final Size body = tester.getSize(find.byKey(BhorFocusPage.bodyKey));
    expect(body.width, greaterThan(880));
    final List<double> lefts = <double>[
      for (final Element e in find.byType(RollRow).evaluate()) tester.getTopLeft(find.byWidget(e.widget)).dx,
    ];
    expect(lefts.toSet(), hasLength(1));
    final List<double> tops = <double>[
      for (final Element e in find.byType(RollRow).evaluate()) tester.getTopLeft(find.byWidget(e.widget)).dy,
    ];
    expect(tops[0] < tops[1] && tops[1] < tops[2], isTrue);
    expect(tester.getSize(find.byType(RollRow).first).width, lessThanOrEqualTo(880));

    // Live counts and Save live in the bar under the rows, not in a rail.
    final Finder bar = find.byKey(BhorFocusPage.barKey);
    expect(bar, findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('Save attendance (3)')), findsOneWidget);
    expect(
      find.descendant(
        of: bar,
        matching: find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.label == 'Present 3'),
      ),
      findsOneWidget,
    );
    expect(find.byType(RollSessionChips), findsNothing);
    await unmount(tester);
  });

  testWidgets('desktop: date chevrons hug the date, class note and shortcuts are top-bar actions', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f, viewport: TestViewport.desktop);

    final Rect prev = tester.getRect(_byLabel('Previous day'));
    final Rect next = tester.getRect(_byLabel('Next day'));
    // Both arrows sit within a short distance of each other (around the date),
    // nowhere near the window edges.
    expect(next.left - prev.right, lessThan(420));
    expect(prev.left, lessThan(next.left));
    expect(next.right, lessThan(600)); // nowhere near the right window edge (1280)

    await tester.tap(_byLabel('Keyboard shortcuts'));
    await tester.pumpAndSettle();
    expect(find.byType(RollShortcutList), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(RollShortcutList), findsNothing);
    expect(find.byType(RollRow), findsNWidgets(3));

    await tester.tap(_byLabel('Class note'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).last, 'Chapter 3');
    await tester.pump(); // Save turns on once the text changed (b277 X3).
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Note: Chapter 3'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('desktop: Leave is one click away on the row', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f, viewport: TestViewport.desktop);

    await tester.tap(find.descendant(of: find.byType(RollRow).first, matching: find.text('Excused')));
    await tester.pumpAndSettle();
    _expectCounts('Present 2', 'Absent 0', 'Late 0', 'Excused 1');
    // Tapping the chip again takes it back.
    await tester.tap(find.descendant(of: find.byType(RollRow).first, matching: find.text('Excused')));
    await tester.pumpAndSettle();
    _expectCounts('Present 3', 'Absent 0', 'Late 0');
    await unmount(tester);
  });

  testWidgets('desktop: the row dots open an anchored menu without the statuses already on the row',
      (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f, viewport: TestViewport.desktop);

    final Finder dots = find.descendant(of: find.byType(RollRow).first, matching: _byLabel('More options'));
    expect(dots, findsOneWidget);
    await tester.tap(dots);
    await tester.pumpAndSettle();
    // The wide row shows Present / Absent / Late / Excused as buttons: the
    // menu only holds the note (b277 X5).
    for (final AttendanceStatus st in AttendanceStatus.values) {
      expect(find.byKey(Key('roll-menu-${st.name}')), findsNothing, reason: st.name);
    }
    expect(find.byKey(const Key('roll-menu-note')), findsOneWidget);
    // Anchored: the menu hangs near the button, not centred in the window.
    final Rect menu = tester.getRect(find.byKey(const Key('roll-menu-note')));
    final Rect btn = tester.getRect(dots);
    expect((menu.center.dy - btn.center.dy).abs(), lessThan(300));
    await tester.tap(find.byKey(const Key('roll-menu-note')));
    await tester.pumpAndSettle();
    // The note opens as an anchored popover, not a full-height side panel (X3).
    expect(find.byKey(const ValueKey<String>('bhor-popover')), findsOneWidget);
    expect(find.byType(BhorSidePanelFrame), findsNothing);
    expect(find.byKey(const ValueKey<String>('roll-note-field')), findsOneWidget);
    await unmount(tester);
  });

  test('wide rows list the statuses they show; collapsed rows none', () {
    expect(RollRow.statusesOnRow(dense: false, width: 900), isEmpty);
    expect(RollRow.statusesOnRow(dense: true, width: 400), isEmpty);
    expect(RollRow.statusesOnRow(dense: true, width: 500),
        <AttendanceStatus>{AttendanceStatus.present, AttendanceStatus.absent, AttendanceStatus.late});
    expect(RollRow.statusesOnRow(dense: true, width: 700), AttendanceStatus.values.toSet());
  });

  testWidgets('desktop: the class note is a small anchored form; Save waits for a change', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f, viewport: TestViewport.desktop);

    final Rect button = tester.getRect(_byLabel('Class note'));
    await tester.tap(_byLabel('Class note'));
    await tester.pumpAndSettle();
    final Finder popover = find.byKey(const ValueKey<String>('bhor-popover'));
    expect(popover, findsOneWidget);
    expect(find.byType(BhorSidePanelFrame), findsNothing);
    final Rect card = tester.getRect(popover);
    // Popover-sized and hanging from the button.
    expect(card.width, lessThanOrEqualTo(400));
    expect(card.height, lessThan(400));
    expect((card.top - button.bottom).abs(), lessThan(24));
    // Focused on open; Save disabled until the text changes.
    final EditableText field = tester.widget<EditableText>(
      find.descendant(of: find.byKey(const ValueKey<String>('roll-note-field')), matching: find.byType(EditableText)),
    );
    expect(field.focusNode.hasFocus, isTrue);
    final Finder save = find.byKey(const ValueKey<String>('roll-note-save'));
    expect(tester.widget<BhorButton>(save).onPressed, isNull);
    await tester.enterText(find.byType(EditableText).last, 'Test today');
    await tester.pump();
    expect(tester.widget<BhorButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Note: Test today'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('desktop: Esc goes back; with changes it asks first', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    final String occ = physOcc('2026-11-21');
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext context) => Center(
          child: BhorButton(
            label: 'go',
            onPressed: () => openRollCallForBatchDate(context, batchId: kBatPhysA, date: kToday),
          ),
        ),
      ),
      lang: Lang.en,
      viewport: TestViewport.desktop,
      overrides: f.overrides,
    );
    // Nothing changed: Esc simply goes back.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(BhorFocusPage), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
    expect(find.byType(BhorFocusPage), findsNothing);

    // A change: Esc asks, Discard drops the draft.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('রহিম উদ্দিন'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Attendance not saved. Save now?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
    expect(f.attendance.sessions, isEmpty);
    expect(f.localMeta.values.keys, isNot(contains('rollcall_draft:$occ')));
  });

  testWidgets('desktop: the keyboard outline shows only for the keyboard cursor', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f, viewport: TestViewport.desktop);

    bool anyFocused() => tester.widgetList<RollRow>(find.byType(RollRow)).any((RollRow r) => r.focused);
    await tester.tap(find.text('রহিম উদ্দিন'));
    await tester.pump();
    expect(anyFocused(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pump();
    expect(anyFocused(), isTrue);
    await tester.tap(find.text('সারা আক্তার'));
    await tester.pump();
    expect(anyFocused(), isFalse);
    await unmount(tester);
  });

  testWidgets('an extra class has two identical time pickers and ONE info line', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    await open(tester, const BatchRollCallLauncher(batchId: kBatPhysA, date: _friday), f,
        viewport: TestViewport.desktop);

    expect(find.byType(BhorPickerField), findsNWidgets(2));
    expect(find.byType(RollNotice), findsOneWidget);
    // Each note on its own line, never run together (b277 X2).
    final Finder l0 = find.byKey(const ValueKey<String>('roll-notice-line-0'));
    final Finder l1 = find.byKey(const ValueKey<String>('roll-notice-line-1'));
    if (l1.evaluate().isNotEmpty) {
      expect(tester.getRect(l1).top, greaterThanOrEqualTo(tester.getRect(l0).bottom));
      expect(tester.getRect(l1).left, tester.getRect(l0).left);
    }
    expect(find.text('No class is scheduled at this time — it will be saved as an extra class'), findsOneWidget);
    expect(find.text('You are viewing attendance of a past day'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the batch tab lists classes and reopens one', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await open(tester, const BatchAttendanceTab(batchId: kBatPhysA), f);

    expect(find.text('Recent classes'), findsOneWidget);
    await tester.tap(find.text('Present 2/3'));
    await tester.pumpAndSettle();
    expect(find.text('You are viewing attendance of a past day'), findsOneWidget);
  });

  testWidgets('the batch tab and the profile summary shrink-wrap inside a scroll view', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await open(
      tester,
      const SingleChildScrollView(
        child: Column(
          children: <Widget>[
            BatchAttendanceTab(batchId: kBatPhysA),
            EnrollmentAttendanceSummary(studentId: kStuRahim, batchId: kBatPhysA),
          ],
        ),
      ),
      f,
    );
    expect(find.text('Recent classes'), findsOneWidget);
    expect(find.text('This month 50%'), findsOneWidget);
    expect(find.text('Overall 50%'), findsOneWidget);
  });
}
