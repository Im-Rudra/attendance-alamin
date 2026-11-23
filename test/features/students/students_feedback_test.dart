// Teacher feedback (docs/council/19 items 4, 6, 10, 11) on the students
// feature: join date in the enrol flows and its later change, a student's own
// fee from a chosen month, rejoin from an earlier day, and multi-select with
// the selection bar and its bulk actions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_table.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_form_model.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/controllers/student_selection.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';
import 'package:attendance_alamin/features/students/ui/left_students_screen.dart';
import 'package:attendance_alamin/features/students/ui/student_profile_screen.dart';
import 'package:attendance_alamin/features/students/ui/students_screen.dart';
import 'package:attendance_alamin/features/students/widgets/enrollment_edits.dart';
import 'package:attendance_alamin/features/students/widgets/student_bulk_actions.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

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

List<Enrollment> _open(SeededFakes f, String studentId, String batchId) => <Enrollment>[
      for (final Enrollment e in f.enrollments.enrollments)
        if (e.studentId == studentId && e.batchId == batchId && e.endDate == null) e,
    ];

Enrollment _enrollment(SeededFakes f, String id) =>
    f.enrollments.enrollments.firstWhere((Enrollment e) => e.id == id);

Future<void> _tapKey(WidgetTester tester, String key) async {
  final Finder f = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Rahim (left on 5 Aug, last billable month July) for the rejoin flow.
SeededFakes _rahimLeft() {
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
  final int j = f.enrollments.enrollments.indexWhere((Enrollment e) => e.id == kEnrRahimPhys);
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
  return f;
}

Finder _inTable(String text) =>
    find.descendant(of: find.byType(BatchTable<StudentRow>), matching: find.text(text));

void main() {
  group('pure helpers', () {
    test('selection: toggle, Shift range from the anchor, all, visible order', () {
      const List<String> order = <String>['a', 'b', 'c', 'd', 'e'];
      StudentSelection s = const StudentSelection();
      s = s.toggle('b');
      expect(s.ids, <String>{'b'});
      expect(s.anchor, 'b');
      s = s.range(order, 'd');
      expect(s.ids, <String>{'b', 'c', 'd'});
      s = s.range(order, 'a'); // same anchor, the other way
      expect(s.ids, <String>{'a', 'b'});
      s = s.toggle('a');
      expect(s.ids, <String>{'b'});
      expect(s.anchor, 'a');
      expect(const StudentSelection().range(order, 'c').ids, <String>{'c'});
      expect(s.all(order).ids.length, 5);
      expect(s.all(order).visibleIn(<String>['e', 'x', 'a']), <String>['e', 'a']);
    });

    test('special fee and batch fee in force in a month', () {
      final List<FeePeriod> overrides = <FeePeriod>[
        const FeePeriod(effective: YearMonth(2026, 9), amount: 750),
        const FeePeriod(effective: YearMonth(2027, 1)),
      ];
      expect(specialFeeAt(overrides, const YearMonth(2026, 8)), isNull);
      expect(specialFeeAt(overrides, const YearMonth(2026, 11)), 750);
      expect(specialFeeAt(overrides, const YearMonth(2027, 2)), isNull, reason: 'cleared');
      final List<FeePeriod> batch = <FeePeriod>[
        const FeePeriod(effective: YearMonth(2026, 1), amount: 1000),
        const FeePeriod(effective: YearMonth(2026, 12), amount: 1200),
      ];
      expect(batchFeeAt(batch, const YearMonth(2025, 6)), 1000);
      expect(batchFeeAt(batch, const YearMonth(2026, 11)), 1000);
      expect(batchFeeAt(batch, const YearMonth(2027, 3)), 1200);
      expect(batchFeeAt(const <FeePeriod>[], const YearMonth(2027, 3)), isNull);
    });

    test('fee-change months never start before the first billable month', () {
      final ({List<YearMonth> quick, List<YearMonth> older}) m =
          feeChangeMonths(const YearMonth(2026, 11), const YearMonth(2026, 10));
      expect(m.quick.first, const YearMonth(2026, 10));
      expect(m.quick.last, const YearMonth(2027, 5));
      expect(m.older, isEmpty);
      final ({List<YearMonth> quick, List<YearMonth> older}) n =
          feeChangeMonths(const YearMonth(2026, 11), const YearMonth(2026, 6));
      expect(n.quick.first, const YearMonth(2026, 9));
      expect(n.older, <YearMonth>[
        const YearMonth(2026, 8),
        const YearMonth(2026, 7),
        const YearMonth(2026, 6),
      ]);
    });

    test('guardian groups and phone numbers', () {
      const Student a = Student(
          id: 'a', name: 'A', guardianPhone: '01811111111', admissionDate: kToday, status: StudentStatus.active);
      const Student b = Student(
          id: 'b', name: 'B', guardianPhone: '01811111111', phone: '01922222222', admissionDate: kToday,
          status: StudentStatus.active);
      const Student c = Student(id: 'c', name: 'C', admissionDate: kToday, status: StudentStatus.active);
      const Student d = Student(id: 'd', name: 'D', admissionDate: kToday, status: StudentStatus.active);
      final List<List<Student>> groups = groupByGuardian(<Student>[a, c, b, d]);
      expect(groups.map((List<Student> g) => g.map((Student s) => s.id).join()), <String>['ab', 'c', 'd']);
      expect(phoneNumbersOf(<Student>[a, b, c]), <String>['01811111111', '01922222222']);
    });

    test('join date drives the default billing start; rejoin starts the day after leaving', () {
      final EnrollChoice c = EnrollChoice();
      addTearDown(c.dispose);
      expect(c.joinFor(kToday), kToday);
      expect(c.isDirty, isFalse);
      c.setJoin(const LocalDate(2026, 11, 5));
      expect(c.isDirty, isTrue);
      final LocalDate join = c.joinFor(kToday);
      expect(join, const LocalDate(2026, 11, 5));
      expect(c.startFor(join, 15), const YearMonth(2026, 11));
      final Student left = _rahimLeft().students.students.firstWhere((Student s) => s.id == kStuRahim);
      expect(rejoinFirstDay(left, kToday), const LocalDate(2026, 8, 6));
    });
  });

  group('item 6: joined this batch on', () {
    testWidgets('enrolling in another batch keeps the picked join date', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          await showEnrollSheet(c, studentId: kStuRahim);
        }),
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('কেমিস্ট্রি বি'));
      await tester.pumpAndSettle();
      expect(find.text('ব্যাচে যোগ দেওয়ার তারিখ'), findsOneWidget);
      tester.widget<JoinDateField>(find.byType(JoinDateField)).onChanged(const LocalDate(2026, 11, 5));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'stu-enroll-confirm');

      final Enrollment e = _open(f, kStuRahim, kBatChemB).single;
      expect(e.joinDate, const LocalDate(2026, 11, 5));
      expect(e.startMonth, const YearMonth(2026, 11), reason: 'joined by the 15th: billed from November');
    });

    testWidgets('"Add to this batch" uses the join date picked above the matches', (WidgetTester tester) async {
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
      await tester.enterText(find.byKey(const ValueKey<String>('stu-add-search')), 'রহিম');
      await tester.pump();
      tester.widget<JoinDateField>(find.byType(JoinDateField)).onChanged(const LocalDate(2026, 10, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.text('এই ব্যাচে যোগ করুন'));
      await tester.pumpAndSettle();
      final Enrollment e = _open(f, kStuRahim, kBatChemB).single;
      expect(e.joinDate, const LocalDate(2026, 10, 20));
      expect(e.startMonth, const YearMonth(2026, 11));
    });

    testWidgets('Change join date moves the date and leaves the billing start alone',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => openChangeJoinDate(c, _enrollment(f, kEnrRahimPhys))),
        viewport: TestViewport.desktop,
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('stu-join-keeps-fee')), findsOneWidget);
      tester.widget<JoinDateField>(find.byType(JoinDateField)).onChanged(const LocalDate(2026, 8, 20));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'stu-join-save');

      final Enrollment e = _enrollment(f, kEnrRahimPhys);
      expect(e.joinDate, const LocalDate(2026, 8, 20));
      expect(e.startMonth, const YearMonth(2026, 9));
      expect(find.byType(BhorSidePanelFrame), findsNothing);
    });

    testWidgets('the enrolment ⋮ offers both changes', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const StudentProfileScreen(studentId: kStuKarim),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('stu-joined-$kEnrKarimChem')), findsOneWidget);
      final Finder more = find.byWidgetPredicate(
          (Widget w) => w is BhorIconButton && w.icon == BhorIcons.overflowVertical);
      await tester.tap(more.last);
      await tester.pumpAndSettle();
      expect(find.text('যোগ দেওয়ার তারিখ বদলান'), findsOneWidget);
      expect(find.text('এই শিক্ষার্থীর ফি বদলান'), findsOneWidget);
    });
  });

  group('item 4: a student\'s own fee', () {
    testWidgets('Change fee saves the amount from the chosen month', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => openChangeStudentFee(c, _enrollment(f, kEnrRahimPhys))),
        viewport: TestViewport.desktop,
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('stu-fee-amount')), '750');
      await tester.pump();
      await _tapKey(tester, 'stu-fee-from-202612');
      await _tapKey(tester, 'stu-fee-save');

      expect(f.enrollments.overrides[kEnrRahimPhys], <FeePeriod>[
        const FeePeriod(effective: YearMonth(2026, 12), amount: 750),
      ]);
    });

    testWidgets('a blank amount goes back to the batch fee', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => openChangeStudentFee(c, _enrollment(f, kEnrRahimPhys))),
        viewport: TestViewport.desktop,
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'stu-fee-save');
      expect(f.enrollments.overrides[kEnrRahimPhys], <FeePeriod>[
        const FeePeriod(effective: YearMonth(2026, 11)),
      ]);
    });

    testWidgets('the enrolment card shows the special fee', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      final int i = f.enrollments.terms.indexWhere((EnrollmentTerms t) => t.enrollmentId == kEnrRahimPhys);
      final EnrollmentTerms t = f.enrollments.terms[i];
      f.enrollments.terms[i] = EnrollmentTerms(
        enrollmentId: t.enrollmentId,
        studentId: t.studentId,
        batchId: t.batchId,
        studentName: t.studentName,
        batchName: t.batchName,
        subjectName: t.subjectName,
        billing: t.billing,
        start: t.start,
        end: t.end,
        batchFees: t.batchFees,
        overrides: const <FeePeriod>[FeePeriod(effective: YearMonth(2026, 9), amount: 750)],
      );
      await pumpApp(
        tester,
        const StudentProfileScreen(studentId: kStuRahim),
        viewport: TestViewport.desktop,
        overrides: f.overrides,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('stu-special-fee-$kEnrRahimPhys')), findsOneWidget);
      expect(find.textContaining('বিশেষ ফি'), findsOneWidget);
    });
  });

  group('item 11: rejoin from an earlier day', () {
    testWidgets('a back-from date shrinks the gap and is passed on', (WidgetTester tester) async {
      final SeededFakes f = _rahimLeft();
      await pumpApp(tester, const LeftStudentsScreen(), overrides: f.overrides);
      await tester.tap(find.byKey(const ValueKey<String>('stu-left-rejoin-$kStuRahim')));
      await tester.pumpAndSettle();
      expect(find.text('মাঝের ৩ মাস মাফ করবেন?'), findsOneWidget);

      tester.widget<DateField>(find.byKey(const ValueKey<String>('stu-rejoin-date')))
          .onChanged(const LocalDate(2026, 9, 10));
      await tester.pumpAndSettle();
      expect(find.text('মাঝের ১ মাস মাফ করবেন?'), findsOneWidget);
      await _tapKey(tester, 'stu-rejoin-keep');
      await _tapKey(tester, 'stu-rejoin-confirm');

      expect(f.students.rejoinedOn, const LocalDate(2026, 9, 10));
      expect(f.students.rejoinWaived, isFalse);
      expect(f.students.students.firstWhere((Student s) => s.id == kStuRahim).status, StudentStatus.active);
    });
  });

  group('item 10: multi-select', () {
    testWidgets('Ctrl+click, Shift+click, Ctrl+A and Esc drive the selection bar', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const StudentsScreen(),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(StudentSelectionBar.barKey), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(_inTable('রহিম উদ্দিন'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(StudentSelectionBar.barKey), findsOneWidget);
      expect(find.text('১ জন বাছাই করা'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(_inTable('সারা আক্তার'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('৩ জন বাছাই করা'), findsOneWidget);

      // A plain click opens the profile and keeps the selection.
      await tester.tap(_inTable('নীলা বেগম'));
      await tester.pumpAndSettle();
      expect(find.text('৩ জন বাছাই করা'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('৪ জন বাছাই করা'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(StudentSelectionBar.barKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the hover select box toggles a row', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const StudentsScreen(),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('stu-check-$kStuKarim')));
      await tester.pumpAndSettle();
      expect(find.text('১ জন বাছাই করা'), findsOneWidget);
      await _tapKey(tester, 'stu-bulk-clear');
      expect(find.byKey(StudentSelectionBar.barKey), findsNothing);
    });

    testWidgets('phone: a long press starts selecting, taps toggle, the bar replaces the FAB',
        (WidgetTester tester) async {
      await pumpApp(tester, const StudentsScreen(), overrides: seedFakes().overrides);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('stu-fab-new')), findsOneWidget);
      await tester.longPress(find.byKey(const ValueKey<String>('stu-row-$kStuRahim')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('stu-row-$kStuKarim')));
      await tester.pumpAndSettle();
      expect(find.text('২ জন বাছাই করা'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stu-fab-new')), findsNothing);
      expect(find.byKey(const ValueKey<String>('stu-bulk-menu')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('stu-row-$kStuRahim')));
      await tester.pumpAndSettle();
      expect(find.text('১ জন বাছাই করা'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final Size size in const <Size>[Size(1214, 800), Size(910, 800)]) {
      for (final bool english in const <bool>[false, true]) {
        testWidgets('the bar never overflows [${size.width.toInt()}, ${english ? 'en' : 'bn'}]',
            (WidgetTester tester) async {
          await pumpApp(
            tester,
            const StudentsScreen(),
            viewport: TestViewport.desktop,
            lang: english ? Lang.en : Lang.bn,
            overrides: seedFakes().overrides,
          );
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          expect(find.byKey(StudentSelectionBar.barKey), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('bulk Mark as left marks every selected student and clears the selection',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(tester, const StudentsScreen(), viewport: TestViewport.desktop, overrides: f.overrides);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('stu-check-$kStuRahim')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('stu-check-$kStuNila')));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'stu-bulk-left');
      await _tapKey(tester, 'stu-bulk-left-confirm');

      StudentStatus statusOf(String id) => f.students.students.firstWhere((Student s) => s.id == id).status;
      expect(statusOf(kStuRahim), StudentStatus.left);
      expect(statusOf(kStuNila), StudentStatus.left);
      expect(statusOf(kStuKarim), StudentStatus.active);
      expect(find.byKey(StudentSelectionBar.barKey), findsNothing);
    });

    testWidgets('bulk Enrol skips a student already in the batch', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(tester, const StudentsScreen(), viewport: TestViewport.desktop, overrides: f.overrides);
      await tester.pumpAndSettle();
      for (final String id in <String>[kStuRahim, kStuKarim, kStuNila]) {
        await tester.tap(find.byKey(ValueKey<String>('stu-check-$id')));
        await tester.pumpAndSettle();
      }
      await _tapKey(tester, 'stu-bulk-enroll');
      tester
          .widget<BhorSelect<String>>(find.byKey(const ValueKey<String>('stu-bulk-enroll-batch')))
          .onChanged!(kBatChemB);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('stu-bulk-enroll-skipped')), findsOneWidget);
      await _tapKey(tester, 'stu-bulk-enroll-confirm');

      expect(_open(f, kStuRahim, kBatChemB).single.joinDate, kToday);
      expect(_open(f, kStuNila, kBatChemB), hasLength(1));
      expect(_open(f, kStuKarim, kBatChemB), hasLength(1));
    });

    testWidgets('Copy phone numbers puts one number per line on the clipboard', (WidgetTester tester) async {
      final List<String> copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map<Object?, Object?>)['text']! as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpApp(tester, const StudentsScreen(), viewport: TestViewport.desktop, overrides: seedFakes().overrides);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('stu-check-$kStuRahim')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('stu-check-$kStuNila')));
      await tester.pumpAndSettle();
      await _tapKey(tester, 'stu-bulk-phones');
      expect(copied, <String>['01811223344\n01711223344\n01544556677']);
    });
  });
}
