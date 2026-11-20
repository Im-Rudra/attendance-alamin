// Public surface of the students feature (plan section 1 #32). STUB by M5-A;
// bodies by M6-D. Signatures are frozen.

import 'package:flutter/widgets.dart';

/// Search-first "add student to this batch" sheet; returns the student id.
Future<String?> showAddStudentToBatchSheet(BuildContext context, {required String batchId}) async => null;

/// Enrol an existing student in another batch; true when enrolled.
Future<bool> showEnrollSheet(BuildContext context, {required String studentId}) async => false;

/// Mark a student as left (per-enrolment last billable month); true when done.
Future<bool> showMarkLeftDialog(BuildContext context, {required String studentId}) async => false;
