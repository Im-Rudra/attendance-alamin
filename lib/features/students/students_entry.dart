// Public surface of the students feature (plan section 1 #32). Signatures are
// frozen by M5-A; the bodies live in widgets/.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/features/students/widgets/add_student_sheet.dart';
import 'package:attendance_alamin/features/students/widgets/enroll_sheet.dart';
import 'package:attendance_alamin/features/students/widgets/leave_dialog.dart';

/// Search-first "add student to this batch" sheet; returns the student id.
Future<String?> showAddStudentToBatchSheet(BuildContext context, {required String batchId}) =>
    openAddStudentSheet(context, batchId);

/// Enrol an existing student in another batch; true when enrolled.
Future<bool> showEnrollSheet(BuildContext context, {required String studentId}) =>
    openEnrollSheet(context, studentId);

/// Mark a student as left (per-enrolment last billable month); true when done.
Future<bool> showMarkLeftDialog(BuildContext context, {required String studentId}) =>
    openLeaveDialog(context, studentId: studentId);
