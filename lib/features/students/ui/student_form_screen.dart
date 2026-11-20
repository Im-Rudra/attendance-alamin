// StudentFormScreen: STUB by M5-A (plan section 0). The body belongs to M6-D (students);
// keep the constructor signature (routes are frozen).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';

class StudentFormScreen extends StatelessWidget {
  const StudentFormScreen({super.key, this.studentId, this.initialBatchId});

  /// null = add a new student.
  final String? studentId;

  /// Batch to enrol the new student in (passed as route `extra`).
  final String? initialBatchId;

  @override
  Widget build(BuildContext context) => StubScreen(
        name: studentId == null ? context.l10n.shellTitleStudentNew : context.l10n.shellTitleStudentEdit,
        icon: Icons.person_add_alt_1_outlined,
        fullScreen: true,
      );
}
