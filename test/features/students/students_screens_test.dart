// Every screen and sheet of the students feature in the 8-case screen matrix
// (light/dark x bn/en x phone/desktop; fails on any exception incl. overflow).

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/ui/left_students_screen.dart';
import 'package:attendance_alamin/features/students/ui/student_form_screen.dart';
import 'package:attendance_alamin/features/students/ui/student_profile_screen.dart';
import 'package:attendance_alamin/features/students/ui/students_screen.dart';
import 'package:attendance_alamin/features/students/widgets/add_student_sheet.dart';
import 'package:attendance_alamin/features/students/widgets/enroll_sheet.dart';
import 'package:attendance_alamin/features/students/widgets/leave_dialog.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

/// Seed with Rahim marked as left on 2026-08-05 (his enrollment ended with the
/// last billable month July).
SeededFakes _withLeftStudent() {
  final SeededFakes f = seedFakes();
  final int i = f.students.students.indexWhere((Student s) => s.id == kStuRahim);
  final Student r = f.students.students[i];
  f.students.students[i] = Student(
    id: r.id,
    name: r.name,
    roll: r.roll,
    phone: r.phone,
    guardianName: r.guardianName,
    guardianPhone: r.guardianPhone,
    admissionDate: r.admissionDate,
    status: StudentStatus.left,
    leftDate: const LocalDate(2026, 8, 5),
  );
  final int j = f.enrollments.enrollments
      .indexWhere((Enrollment e) => e.id == kEnrRahimPhys);
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

void main() {
  testScreenMatrix(
    'students list',
    () => const StudentsScreen(),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'students list with selected profile',
    () => const StudentsScreen(selectedId: kStuSara),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'students list, nobody yet',
    () => const StudentsScreen(),
    overrides: () {
      final SeededFakes f = seedFakes();
      f.students.students.clear();
      return f.overrides;
    },
  );

  testScreenMatrix(
    'student profile, two batches',
    () => const StudentProfileScreen(studentId: kStuSara),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'student profile, student who left',
    () => const StudentProfileScreen(studentId: kStuRahim),
    overrides: () => _withLeftStudent().overrides,
  );

  testScreenMatrix(
    'student profile, not found',
    () => const StudentProfileScreen(studentId: 'nobody'),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'new student form',
    () => const StudentFormScreen(initialBatchId: kBatChemB),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'edit student form',
    () => const StudentFormScreen(studentId: kStuKarim),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'students who left',
    () => const LeftStudentsScreen(),
    overrides: () => _withLeftStudent().overrides,
  );

  testScreenMatrix(
    'students who left, none',
    () => const LeftStudentsScreen(),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'add student sheet',
    () => const AddStudentSheet(batchId: kBatChemB),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'enrol sheet',
    () => const EnrollSheet(studentId: kStuRahim),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'mark left dialog',
    () => const LeaveDialog(studentId: kStuSara),
    overrides: () => seedFakes().overrides,
  );

  testScreenMatrix(
    'remove from one batch dialog',
    () => const LeaveDialog(studentId: kStuSara, enrollmentId: kEnrSaraChem),
    overrides: () => seedFakes().overrides,
  );
}
