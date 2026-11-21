// Rejoin (Product 3.2): clears the leave and asks "মাঝের N মাস মাফ করবেন?"
// when the months between the last billable month and today would otherwise
// become owed.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/widgets/student_dialogs.dart';

/// True when the student is active again.
Future<bool> runRejoinFlow(
    BuildContext context, WidgetRef ref, Student student) async {
  final l10n = context.l10n;
  final today = ref.read(todayProvider);
  final List<Enrollment> enrollments = await ref
      .read(enrollmentsRepositoryProvider)
      .watchForStudent(student.id)
      .first;
  final int gap = rejoinGapMonths(student, enrollments, today);
  var waive = false;
  if (gap > 0) {
    if (!context.mounted) return false;
    final bool? choice = await showRejoinGapDialog(context, months: gap);
    if (choice == null) return false;
    waive = choice;
  }
  try {
    await ref
        .read(studentsRepositoryProvider)
        .rejoin(student.id, waiveGap: waive);
    if (context.mounted) BhorToast.show(context, message: l10n.stuRejoined(student.name));
    return true;
  } on AppException catch (e) {
    if (context.mounted) BhorToast.show(context, message: errorText(l10n, e));
    return false;
  }
}
