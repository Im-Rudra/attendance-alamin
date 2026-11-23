// W1-Shell (feedback items 5 and 6): the roll-call header date is a button that
// opens the calendar under it, and a past day lists the students who joined
// after it (read-only until the join date can be moved).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/attendance/controllers/late_joiners.dart';
import 'package:attendance_alamin/features/attendance/ui/roll_call_screen.dart';
import 'package:attendance_alamin/features/attendance/widgets/late_joiners_ui.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_header.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

Future<void> _open(
  WidgetTester tester,
  Widget screen,
  SeededFakes f, {
  TestViewport viewport = TestViewport.phone,
}) async {
  await pumpApp(tester, screen, lang: Lang.en, viewport: viewport, overrides: f.overrides);
  await tester.pumpAndSettle();
}

void main() {
  group('lateJoinersOf', () {
    const LocalDate day = LocalDate(2026, 11, 7);
    Student student(String id, String name) => Student(
          id: id,
          name: name,
          admissionDate: const LocalDate(2026, 1, 1),
          status: StudentStatus.active,
        );
    Enrollment enr(String id, String studentId, LocalDate join, {LocalDate? end}) => Enrollment(
          id: id,
          studentId: studentId,
          batchId: kBatPhysA,
          joinDate: join,
          startMonth: join.yearMonth,
          endDate: end,
        );

    test('only open enrolments that start after the date, earliest first', () {
      final List<LateJoiner> out = lateJoinersOf(
        date: day,
        enrollments: <Enrollment>[
          enr('e1', 's1', const LocalDate(2026, 11, 12)),
          enr('e2', 's2', const LocalDate(2026, 11, 10)),
          enr('e3', 's3', const LocalDate(2026, 11, 7)), // joined that day
          enr('e4', 's4', const LocalDate(2026, 10, 1)), // before
          enr('e5', 's5', const LocalDate(2026, 11, 20), end: const LocalDate(2026, 11, 25)), // ended
          enr('e6', 'gone', const LocalDate(2026, 11, 15)), // no such student
        ],
        studentsById: <String, Student>{
          for (final String id in <String>['s1', 's2', 's3', 's4', 's5']) id: student(id, 'N$id'),
        },
      );
      expect(out.map((LateJoiner j) => j.enrollmentId), <String>['e2', 'e1']);
      expect(out.first.joinDate, const LocalDate(2026, 11, 10));
    });

    test('moving the join date is not switched on yet', () {
      expect(kLateJoinerMoveEnabled, isFalse);
    });
  });

  group('roll call header date', () {
    testWidgets('desktop: the calendar opens under the date and picks a day', (WidgetTester tester) async {
      final SeededFakes f = seedFakes(withAttendance: false);
      await _open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f, viewport: TestViewport.desktop);

      expect(find.byIcon(BhorIcons.calendar), findsOneWidget);
      await tester.tap(find.byIcon(BhorIcons.calendar));
      await tester.pumpAndSettle();
      expect(find.byType(BhorDatePicker), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(BhorDatePicker), matching: find.text('20')).first);
      await tester.pumpAndSettle();
      expect(find.byType(BhorDatePicker), findsNothing);
      // Friday has no Physics A class: the day opens as an extra class.
      expect(find.byType(AdHocTimeCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone: the date is a button too', (WidgetTester tester) async {
      final SeededFakes f = seedFakes(withAttendance: false);
      await _open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f);
      expect(find.byIcon(BhorIcons.calendar), findsOneWidget);
      await tester.tap(find.byIcon(BhorIcons.calendar));
      await tester.pumpAndSettle();
      expect(find.byType(BhorDatePicker), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('late joiners line', () {
    testWidgets('a past day lists who joined after it, read-only', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await _open(tester, RollCallScreen(occ: physOcc('2026-11-07')), f);

      expect(find.byType(LateJoinersFooter), findsOneWidget);
      expect(find.text('1 joined after this date'), findsOneWidget);
      expect(find.text('নীলা বেগম'), findsNothing);

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('নীলা বেগম'), findsOneWidget);
      expect(find.text('Joined 10 Nov 2026'), findsOneWidget);
      expect(
        find.text('They were not in this batch on 7 Nov 2026. Change their join date in Students to mark them.'),
        findsOneWidget,
      );
      // Nothing was marked or saved for the late joiner.
      expect(
        f.attendance.records.where((AttendanceRecord r) => r.studentId == kStuNila && r.date == const LocalDate(2026, 11, 7)),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a day after everyone joined has no line', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await _open(tester, RollCallScreen(occ: physOcc('2026-11-21')), f);
      expect(find.byType(LateJoinersFooter), findsNothing);
    });
  });
}
