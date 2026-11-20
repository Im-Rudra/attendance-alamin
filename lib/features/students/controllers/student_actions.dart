// Write-side logic of the students feature: create + enrol, the duplicate
// guard, rejoin and the leave defaults. Pure functions over the repositories so
// the sheets, the form and the tests share one implementation.

import 'dart:typed_data';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/enrollments_repository.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/student.dart';

/// Existing students that already use one of the draft's phone numbers
/// (UX 2e duplicate guard: phone alone, or name and phone, matches).
Future<List<Student>> findPhoneDuplicates(
  StudentsRepository students,
  StudentDraft draft, {
  String? exceptId,
}) async {
  final Set<String> phones = <String>{
    if (draft.phone != null) draft.phone!,
    if (draft.guardianPhone != null) draft.guardianPhone!,
  };
  final Map<String, Student> found = <String, Student>{};
  for (final String phone in phones) {
    final List<Student> hits =
        await students.findDuplicates(name: draft.name, phone: phone);
    for (final Student s in hits) {
      if (s.id == exceptId) continue;
      final bool samePhone = phones.contains(s.phone) ||
          phones.contains(s.guardianPhone);
      if (samePhone) found[s.id] = s;
    }
  }
  return found.values.toList();
}

/// Creates the student, stores the photo and (optionally) enrols them. When a
/// later step fails the new student is removed again so no orphan is left.
Future<String> createStudentAndEnroll({
  required StudentsRepository students,
  required EnrollmentsRepository enrollments,
  required StudentDraft draft,
  Uint8List? photo,
  String? batchId,
  YearMonth? startMonth,
  int? feeOverride,
}) async {
  final String id = await students.create(draft);
  try {
    if (photo != null) await students.setPhoto(id, photo);
    if (batchId != null && startMonth != null) {
      await enrollments.enroll(
        studentId: id,
        batchId: batchId,
        joinDate: draft.admissionDate,
        startMonth: startMonth,
        feeOverride: feeOverride,
      );
    }
  } catch (_) {
    await students.softDelete(id);
    rethrow;
  }
  return id;
}

/// Months of the gap between the leave and today that a rejoin would waive:
/// the distinct months after the last billable month and before this month
/// (the same count `StudentsRepository.rejoin` reports).
int rejoinGapMonths(Student student, List<Enrollment> enrollments, LocalDate today) {
  final LocalDate? left = student.leftDate;
  if (left == null) return 0;
  var gap = 0;
  for (final Enrollment e in enrollments) {
    final YearMonth? lbm = e.endMonth;
    if (lbm == null || e.endDate != left) continue;
    final int n = lbm.monthsUntil(today.yearMonth) - 1;
    if (n > gap) gap = n;
  }
  return gap;
}

/// Months offered for a first/last billable month dropdown, always including
/// [selected].
List<YearMonth> monthChoices(YearMonth lo, YearMonth hi, YearMonth selected) {
  final List<YearMonth> out = <YearMonth>[];
  var m = lo.isAfter(selected) ? selected : lo;
  final YearMonth end = hi.isBefore(selected) ? selected : hi;
  while (!m.isAfter(end)) {
    out.add(m);
    m = m.addMonths(1);
  }
  return out;
}

/// The 12-month strip of an enrollment (UX 3): the months around [current]
/// (up to 9 before, 2 after) out of all billable months.
List<MonthDue> stripMonths(List<MonthDue> months, YearMonth current) {
  if (months.length <= 12) return months;
  var idx = 0;
  for (var i = 0; i < months.length; i++) {
    if (!months[i].month.isAfter(current)) idx = i;
  }
  final int end = (idx + 3).clamp(0, months.length).toInt();
  final int start = (end - 12).clamp(0, months.length).toInt();
  return months.sublist(start, end);
}
