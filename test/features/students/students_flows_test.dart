// Behaviour of the students feature: duplicate guard, search-first add,
// enrolling in a second batch (scenarios 6, 7) and marking a student left
// (scenario 8), rejoin with the gap waiver.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_form_model.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';
import 'package:attendance_alamin/features/students/ui/left_students_screen.dart';
import 'package:attendance_alamin/features/students/ui/student_form_screen.dart';
import 'package:attendance_alamin/features/students/widgets/leave_dialog.dart';

import '../../helpers/fakes/fake_people_repos.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

class _Launcher extends StatelessWidget {
  const _Launcher(this.onTap);

  final Future<void> Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) => Center(
        child: BhorButton(label: 'open', onPressed: () => onTap(context)),
      );
}

/// Remembers what `markLeft` was asked to do (the fake only flips the status).
class _RecordingStudents extends FakeStudentsRepository {
  _RecordingStudents(List<Student> students) : super(students: students);

  LocalDate? leftOn;
  Map<String, YearMonth>? recorded;

  @override
  Future<void> markLeft(String id,
      {required LocalDate on,
      required Map<String, YearMonth> lastBillableByEnrollment}) {
    leftOn = on;
    recorded = lastBillableByEnrollment;
    return super.markLeft(id,
        on: on, lastBillableByEnrollment: lastBillableByEnrollment);
  }
}

List<Enrollment> _open(SeededFakes f, String studentId, String batchId) => <Enrollment>[
      for (final Enrollment e in f.enrollments.enrollments)
        if (e.studentId == studentId && e.batchId == batchId && e.endDate == null) e,
    ];

/// [f] with its students fake swapped for [students] (an override of the same
/// provider twice in one scope is an error).
SeededFakes _withStudents(SeededFakes f, FakeStudentsRepository students) =>
    SeededFakes(
      store: f.store,
      subjects: f.subjects,
      batches: f.batches,
      schedule: f.schedule,
      students: students,
      enrollments: f.enrollments,
      payments: f.payments,
      attendance: f.attendance,
      otherIncome: f.otherIncome,
      settings: f.settings,
      localMeta: f.localMeta,
    );

const String _rahimGuardianPhone = '01811223344';

void main() {
  group('first billable month (scenario 6)', () {
    test('join day 1..15 bills the join month, later days the next month', () {
      final EnrollChoice c = EnrollChoice();
      addTearDown(c.dispose);
      expect(c.startFor(const LocalDate(2026, 11, 10), 15), const YearMonth(2026, 11));
      expect(c.startFor(const LocalDate(2026, 11, 20), 15), const YearMonth(2026, 12));
    });

    test('the teacher can change it, earlier or later', () {
      final EnrollChoice c = EnrollChoice();
      addTearDown(c.dispose);
      c.setStart(const YearMonth(2026, 11));
      expect(c.startFor(const LocalDate(2026, 11, 20), 15), const YearMonth(2026, 11));
      c.setStart(const YearMonth(2027, 1));
      expect(c.startFor(const LocalDate(2026, 11, 10), 15), const YearMonth(2027, 1));
    });
  });

  group('list helpers', () {
    test('search matches name, roll and Bangla or ASCII phone digits', () {
      final Student rahim = kStudents.first;
      expect(studentMatchesQuery(rahim, 'রহিম'), isTrue);
      expect(studentMatchesQuery(rahim, '১'), isTrue); // roll 1
      expect(studentMatchesQuery(rahim, '০১৮১১২২'), isTrue);
      expect(studentMatchesQuery(rahim, '01711'), isTrue);
      expect(studentMatchesQuery(rahim, 'করিম'), isFalse);
    });

    test('rejoin gap counts the months between the last billable month and now', () {
      final Student left = Student(
        id: 's',
        name: 'x',
        admissionDate: const LocalDate(2026, 1, 1),
        status: StudentStatus.left,
        leftDate: const LocalDate(2026, 8, 5),
      );
      final Enrollment e = Enrollment(
        id: 'e',
        studentId: 's',
        batchId: 'b',
        joinDate: const LocalDate(2026, 1, 1),
        startMonth: const YearMonth(2026, 1),
        endMonth: const YearMonth(2026, 7),
        endDate: const LocalDate(2026, 8, 5),
      );
      // Aug, Sep, Oct are the gap before November.
      expect(rejoinGapMonths(left, <Enrollment>[e], kToday), 3);
      expect(rejoinGapMonths(left, const <Enrollment>[], kToday), 0);
    });
  });

  group('search-first add sheet', () {
    testWidgets('an existing student is offered and added, not duplicated',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      String? result;
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          result = await showAddStudentToBatchSheet(c, batchId: kBatChemB);
        }),
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-add-search')), 'রহিম');
      await tester.pump();
      expect(find.text('রহিম উদ্দিন'), findsOneWidget);
      expect(find.text('এই ব্যাচে যোগ করুন'), findsOneWidget);

      await tester.tap(find.text('এই ব্যাচে যোগ করুন'));
      await tester.pumpAndSettle();

      expect(result, kStuRahim);
      expect(f.students.students.length, kStudents.length);
      final List<Enrollment> mine = _open(f, kStuRahim, kBatChemB);
      expect(mine.length, 1);
      // 2026-11-21 is after the 15th: billing starts in December.
      expect(mine.single.startMonth, const YearMonth(2026, 12));
    });

    testWidgets('a student already in the batch is shown but not addable',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          await showAddStudentToBatchSheet(c, batchId: kBatChemB);
        }),
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-add-search')), 'করিম');
      await tester.pump();
      expect(find.text('করিম হোসেন'), findsOneWidget);
      expect(find.text('এই ব্যাচে আছে'), findsOneWidget);
      expect(find.text('এই ব্যাচে যোগ করুন'), findsNothing);
    });

    testWidgets('joining on the 10th starts billing in the join month',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes(today: const LocalDate(2026, 11, 10));
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          await showAddStudentToBatchSheet(c, batchId: kBatChemB);
        }),
        overrides: f.overrides,
        today: const LocalDate(2026, 11, 10),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-add-search')), 'রহিম');
      await tester.pump();
      await tester.tap(find.text('এই ব্যাচে যোগ করুন'));
      await tester.pumpAndSettle();
      expect(_open(f, kStuRahim, kBatChemB).single.startMonth,
          const YearMonth(2026, 11));
    });

    testWidgets('duplicate guard: same phone offers the existing student',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      String? result;
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          result = await showAddStudentToBatchSheet(c, batchId: kBatChemB);
        }),
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-add-search')), 'নতুন ছাত্র');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('stu-add-new')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-field-guardian-phone')),
          _rahimGuardianPhone);
      final Finder save = find.byKey(const ValueKey<String>('stu-add-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('এই নম্বর আগে থেকে আছে'), findsOneWidget);
      expect(find.textContaining('রহিম উদ্দিন'), findsOneWidget);
      await tester.tap(find.text('হ্যাঁ, তাকেই যোগ করুন'));
      await tester.pumpAndSettle();

      expect(result, kStuRahim);
      expect(f.students.students.length, kStudents.length);
      expect(_open(f, kStuRahim, kBatChemB).length, 1);
    });

    testWidgets('duplicate guard: "no, new student" still creates one',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      String? result;
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          result = await showAddStudentToBatchSheet(c, batchId: kBatChemB);
        }),
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-add-search')), 'নতুন ছাত্র');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('stu-add-new')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-field-guardian-phone')),
          _rahimGuardianPhone);
      final Finder save = find.byKey(const ValueKey<String>('stu-add-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.text('না, নতুন শিক্ষার্থী'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result, isNot(kStuRahim));
      expect(f.students.students.length, kStudents.length + 1);
      expect(_open(f, result!, kBatChemB).length, 1);
    });

    testWidgets('a new student with no matching phone is created and enrolled',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      String? result;
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          result = await showAddStudentToBatchSheet(c, batchId: kBatPhysA);
        }),
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-add-search')), 'রাকিব হাসান');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('stu-add-new')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-field-guardian-phone')),
          '01999887766');
      final Finder save = find.byKey(const ValueKey<String>('stu-add-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('এই নম্বর আগে থেকে আছে'), findsNothing);
      expect(result, isNotNull);
      expect(f.students.students.any((Student s) => s.name == 'রাকিব হাসান'), isTrue);
      expect(_open(f, result!, kBatPhysA).length, 1);
    });

    testWidgets('a new admission shows the billing start and a one-tap toggle',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      String? result;
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          result = await showAddStudentToBatchSheet(c, batchId: kBatPhysA);
        }),
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-add-search')), 'রাকিব হাসান');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('stu-add-new')));
      await tester.pumpAndSettle();

      // The 21st is past the cutoff: December by default, shown prominently.
      final Finder line = find.byKey(const ValueKey<String>('stu-billing-start-line'));
      await tester.ensureVisible(line);
      expect(tester.widget<Text>(line).data, 'বেতন শুরু: ডিসেম্বর ২০২৬');
      await tester.tap(find.text('এই মাস থেকে'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(line).data, 'বেতন শুরু: নভেম্বর ২০২৬');

      final Finder save = find.byKey(const ValueKey<String>('stu-add-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(_open(f, result!, kBatPhysA).single.startMonth, const YearMonth(2026, 11));
    });
  });

  group('new student form', () {
    testWidgets('duplicate phone: the existing student is added to the batch',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        const StudentFormScreen(initialBatchId: kBatChemB),
        overrides: f.overrides,
      );
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-field-name')), 'অন্য নাম');
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-field-guardian-phone')),
          _rahimGuardianPhone);
      await tester.tap(find.widgetWithText(BhorButton, 'সেভ করুন'));
      await tester.pumpAndSettle();
      expect(find.text('এই নম্বর আগে থেকে আছে'), findsOneWidget);
      await tester.tap(find.text('হ্যাঁ, তাকেই যোগ করুন'));
      await tester.pumpAndSettle();

      expect(f.students.students.length, kStudents.length);
      expect(_open(f, kStuRahim, kBatChemB).length, 1);
    });

    testWidgets('an invalid phone is explained and nothing is saved',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        const StudentFormScreen(),
        overrides: f.overrides,
      );
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-field-name')), 'ঠিক নাম');
      await tester.enterText(
          find.byKey(const ValueKey<String>('stu-field-guardian-phone')), '123');
      await tester.tap(find.widgetWithText(BhorButton, 'সেভ করুন'));
      await tester.pumpAndSettle();
      expect(f.students.students.length, kStudents.length);
      expect(f.students.writes, 0);
    });

    testWidgets('a missing name is explained and nothing is saved',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        const StudentFormScreen(),
        overrides: f.overrides,
      );
      await tester.tap(find.widgetWithText(BhorButton, 'সেভ করুন'));
      await tester.pumpAndSettle();
      expect(f.students.students.length, kStudents.length);
    });
  });

  group('enrol in a second batch (scenario 7)', () {
    testWidgets('Rahim joins Chem B; Physics A is shown as already joined',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      bool? done;
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          done = await showEnrollSheet(c, studentId: kStuRahim);
        }),
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Physics A is his current batch: marked, not selectable.
      expect(find.text('এই ব্যাচে আছে'), findsOneWidget);
      final Finder confirm = find.byKey(const ValueKey<String>('stu-enroll-confirm'));
      expect(tester.widget<BhorButton>(confirm).onPressed, isNull);

      await tester.tap(find.text('কেমিস্ট্রি বি'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(_open(f, kStuRahim, kBatChemB).length, 1);
      expect(_open(f, kStuRahim, kBatPhysA).length, 1);
    });
  });

  group('mark left (scenario 8)', () {
    testWidgets('left on the 5th: last billable month defaults to October',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      final _RecordingStudents students = _RecordingStudents(kStudents);
      bool? done;
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          done = await showMarkLeftDialog(c, studentId: kStuRahim);
        }),
        overrides: _withStudents(f, students).overrides,
        today: const LocalDate(2026, 11, 5),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('অক্টোবর ২০২৬'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('stu-leave-confirm')));
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(students.leftOn, const LocalDate(2026, 11, 5));
      expect(students.recorded, <String, YearMonth>{
        kEnrRahimPhys: const YearMonth(2026, 10),
      });
      final Student after =
          students.students.firstWhere((Student s) => s.id == kStuRahim);
      expect(after.status, StudentStatus.left);
    });

    testWidgets('left on the 21st: November is still billed; it can be edited',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      final _RecordingStudents students = _RecordingStudents(kStudents);
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          await showMarkLeftDialog(c, studentId: kStuRahim);
        }),
        overrides: _withStudents(f, students).overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('নভেম্বর ২০২৬'), findsOneWidget);

      await tester.tap(find.byType(BhorSelect<YearMonth>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('সেপ্টেম্বর ২০২৬').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('stu-leave-confirm')));
      await tester.pumpAndSettle();

      expect(students.recorded, <String, YearMonth>{
        kEnrRahimPhys: const YearMonth(2026, 9),
      });
    });

    testWidgets('Sara leaves Chem B only: Physics A stays open',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          await openLeaveForTest(c);
        }),
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('stu-leave-confirm')));
      await tester.pumpAndSettle();

      expect(_open(f, kStuSara, kBatChemB), isEmpty);
      expect(_open(f, kStuSara, kBatPhysA).length, 1);
    });
  });

  group('rejoin', () {
    testWidgets('asks whether to waive the gap months, then reactivates',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      final int i = f.students.students.indexWhere((Student s) => s.id == kStuRahim);
      final Student r = f.students.students[i];
      f.students.students[i] = Student(
        id: r.id,
        name: r.name,
        roll: r.roll,
        phone: r.phone,
        guardianPhone: r.guardianPhone,
        admissionDate: r.admissionDate,
        status: StudentStatus.left,
        leftDate: const LocalDate(2026, 8, 5),
      );
      final int j =
          f.enrollments.enrollments.indexWhere((Enrollment e) => e.id == kEnrRahimPhys);
      final Enrollment e = f.enrollments.enrollments[j];
      f.enrollments.enrollments[j] = Enrollment(
        id: e.id,
        studentId: e.studentId,
        batchId: e.batchId,
        joinDate: e.joinDate,
        startMonth: e.startMonth,
        endMonth: const YearMonth(2026, 7),
        endDate: const LocalDate(2026, 8, 5),
      );
      await pumpApp(tester, const LeftStudentsScreen(), overrides: f.overrides);
      expect(find.text('রহিম উদ্দিন'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('stu-left-rejoin-$kStuRahim')));
      await tester.pumpAndSettle();
      expect(find.text('মাঝের ৩ মাস মাফ করবেন?'), findsOneWidget);
      await tester.tap(find.text('হ্যাঁ, মাফ করুন'));
      await tester.pumpAndSettle();

      final Student after =
          f.students.students.firstWhere((Student s) => s.id == kStuRahim);
      expect(after.status, StudentStatus.active);
    });
  });
}

/// Opens the "remove from this batch" dialog for Sara's Chem B enrollment.
Future<void> openLeaveForTest(BuildContext context) async {
  await showBhorDialog<bool>(
    context,
    builder: (BuildContext ctx) => const LeaveDialog(
      studentId: kStuSara,
      enrollmentId: kEnrSaraChem,
    ),
  );
}
