// M7-A: roll call screens and sheets in the 8-case matrix, plus the flows of
// Product scenarios 12 (roll call), 23 (screen part: opening one occurrence)
// and 25 (two classes of one batch in a day).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/widgets/widgets.dart';
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
import 'package:attendance_alamin/features/attendance/widgets/session_chooser_sheet.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

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
      expect(find.byType(StatTile), findsNWidgets(2));
    },
  );

  testScreenMatrix(
    'BatchAttendanceTab without sessions',
    () => const BatchAttendanceTab(batchId: kBatPhysA),
    overrides: () => seedFakes(withAttendance: false).overrides,
    verify: (WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.byType(StatTile), findsNWidgets(2));
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
      expect(find.byType(AttendanceStatusChip), findsNWidgets(5));
    },
  );

  // ---- scenario 12: roll call ---------------------------------------------

  testWidgets('all present by default; taps change the counts; save writes the day', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    final String occ = physOcc('2026-11-21');
    await open(tester, RollCallScreen(occ: occ), f);

    expect(find.text('Present 3 · Absent 0 · Late 0'), findsOneWidget);
    expect(find.text('Save attendance (3)'), findsOneWidget);
    expect(find.text('Everyone is marked present. Tap only the absent ones.'), findsOneWidget);

    final double rowTop = tester.getTopLeft(find.text('রহিম উদ্দিন')).dy;
    await tester.tap(find.text('রহিম উদ্দিন'));
    await tester.pump();
    expect(find.text('Present 2 · Absent 1 · Late 0'), findsOneWidget);
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

  testWidgets('reopening a saved day: late counts as attended and autosaves', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    final String occ = physOcc('2026-11-18');
    await open(tester, RollCallScreen(occ: occ), f);

    expect(find.text('You are viewing attendance of a past day'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Present 2 · Absent 1 · Late 0'), findsOneWidget);

    await tester.tap(find.text('Late').first);
    await tester.pumpAndSettle();
    expect(find.text('Present 2 · Absent 0 · Late 1'), findsOneWidget);
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
    expect(find.text('Present 2 · Absent 0 · Late 0 · Excused 1'), findsOneWidget);
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
    expect(find.text('Present 2 · Absent 1 · Late 0'), findsOneWidget);
    expect(f.attendance.sessions, isEmpty);
  });

  testWidgets('leaving with changes asks; discard drops the draft, save keeps the day', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    final String occ = physOcc('2026-11-21');
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext context) => Center(
          child: ElevatedButton(
            onPressed: () => openRollCallForBatchDate(context, batchId: kBatPhysA, date: kToday),
            child: const Text('go'),
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
    await tester.tap(find.byTooltip('Close'));
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
    await tester.tap(find.byTooltip('Close'));
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
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    await tester.tap(find.text('Save attendance (3)'));
    await tester.pumpAndSettle();
    expect(f.attendance.sessions, hasLength(1));
    expect(f.attendance.sessions.single.occ, physOcc('2026-11-21'));
    // The "saved" snackbar covers the bottom bar until it times out.
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '6:00–7:00 PM'));
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

    expect(find.byType(ConflictCard), findsOneWidget);
    expect(find.text('Fix the time clash first'), findsOneWidget);
    final FilledButton save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save attendance (3)'));
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
    expect(find.text('Present 2 · Absent 1 · Late 0'), findsOneWidget);
  });

  testWidgets('a future date cannot be taken', (WidgetTester tester) async {
    final SeededFakes f = seedFakes();
    await open(tester, const BatchRollCallLauncher(batchId: kBatChemB, date: _sunday), f);

    expect(find.text('Attendance cannot be taken for a future date'), findsOneWidget);
    await tester.tap(find.text('করিম হোসেন'));
    await tester.pump();
    expect(find.text('Present 2 · Absent 0 · Late 0'), findsOneWidget);
    expect(f.attendance.sessions.where((AttendanceSession s) => s.date == _sunday), isEmpty);
  });

  // ---- desktop keys, shrink-wrapped widgets -----------------------------------

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
