// Public surface of the students feature (plan section 1 #32). Signatures are
// frozen by M5-A; the bodies live in widgets/.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/features/students/ui/student_form_screen.dart';
import 'package:attendance_alamin/features/students/widgets/add_student_sheet.dart';
import 'package:attendance_alamin/features/students/widgets/enroll_sheet.dart';
import 'package:attendance_alamin/features/students/widgets/leave_dialog.dart';

/// The add-student form in the side panel (a sheet on phones), optionally
/// pre-selecting [batchId]; true when saved. Used by Today's New… menu.
Future<bool?> showAddStudentPanel(BuildContext context, {String? batchId}) =>
    showStudentFormPanel(context, initialBatchId: batchId);

/// Search-first "add student to this batch" sheet; returns the student id.
Future<String?> showAddStudentToBatchSheet(BuildContext context, {required String batchId}) =>
    openAddStudentSheet(context, batchId);

/// Enrol an existing student in another batch; true when enrolled.
Future<bool> showEnrollSheet(BuildContext context, {required String studentId}) =>
    openEnrollSheet(context, studentId);

/// Mark a student as left (per-enrolment last billable month); true when done.
Future<bool> showMarkLeftDialog(BuildContext context, {required String studentId}) =>
    openLeaveDialog(context, studentId: studentId);

/// Opens "Add student" in place: a side panel on desktop, a sheet on phones
/// (Today's New... menu, Batches, search). [batchId] pre-selects the batch to
/// enrol in. True when a student was saved, null when dismissed.
Future<bool?> openAddStudent(BuildContext context, {String? batchId}) =>
    showStudentFormPanel(context, initialBatchId: batchId);

/// Opens "Edit student" in place (same containers as [openAddStudent]).
Future<bool?> openEditStudent(BuildContext context, {required String studentId}) =>
    showStudentFormPanel(context, studentId: studentId);
