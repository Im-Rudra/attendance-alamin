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
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/student.dart';

/// The batch fee in force in [m] (the earliest one before the history
/// starts); null when the batch has no fee.
int? batchFeeAt(List<FeePeriod> fees, YearMonth m) {
  FeePeriod? best;
  FeePeriod? first;
  for (final FeePeriod f in fees) {
    if (first == null || f.effective.isBefore(first.effective)) first = f;
    if (!f.effective.isAfter(m) && (best == null || f.effective.isAfter(best.effective))) best = f;
  }
  return (best ?? first)?.amount;
}

/// The student's own fee in force in [m] ("Special fee ৳750"), or null when
/// the batch fee applies (no override yet, or the override was cleared).
int? specialFeeAt(List<FeePeriod> overrides, YearMonth m) {
  FeePeriod? best;
  for (final FeePeriod f in overrides) {
    if (!f.effective.isAfter(m) && (best == null || f.effective.isAfter(best.effective))) best = f;
  }
  return best?.amount;
}

/// "From which month?" for a student's fee change: the quick chips (two
/// months back to six ahead of [current]) and the older months for the
/// "earlier month" list, newest first. Nothing before [first] (the first
/// billable month) is offered.
({List<YearMonth> quick, List<YearMonth> older}) feeChangeMonths(YearMonth current, YearMonth first) {
  final List<YearMonth> quick = <YearMonth>[
    for (int i = -2; i <= 6; i++)
      if (!current.addMonths(i).isBefore(first)) current.addMonths(i),
  ];
  final List<YearMonth> older = <YearMonth>[
    for (YearMonth m = current.addMonths(-3); !m.isBefore(first); m = m.addMonths(-1)) m,
  ];
  return (quick: quick, older: older);
}

/// Earliest "back from" day of a rejoin: the day after leaving (today at
/// the latest).
LocalDate rejoinFirstDay(Student student, LocalDate today) {
  final LocalDate? left = student.leftDate;
  if (left == null) return today;
  final LocalDate next = left.addDays(1);
  return next.isAfter(today) ? today : next;
}

/// Students grouped by the number a reminder goes to (guardian, else the
/// student), in list order; students without a number get a group each.
List<List<Student>> groupByGuardian(List<Student> students) {
  final Map<String, List<Student>> byKey = <String, List<Student>>{};
  for (final Student s in students) {
    final String? n = s.callNumber?.trim();
    final String key = (n == null || n.isEmpty) ? 'id:${s.id}' : 'tel:$n';
    (byKey[key] ??= <Student>[]).add(s);
  }
  return byKey.values.toList();
}

/// The distinct phone numbers of [students] (guardian first, then the
/// student's own), in list order.
List<String> phoneNumbersOf(List<Student> students) {
  final List<String> out = <String>[];
  for (final Student s in students) {
    for (final String? p in <String?>[s.guardianPhone, s.phone]) {
      final String? t = p?.trim();
      if (t != null && t.isNotEmpty && !out.contains(t)) out.add(t);
    }
  }
  return out;
}

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
  LocalDate? joinDate,
}) async {
  final String id = await students.create(draft);
  try {
    if (photo != null) await students.setPhoto(id, photo);
    if (batchId != null && startMonth != null) {
      await enrollments.enroll(
        studentId: id,
        batchId: batchId,
        joinDate: joinDate ?? draft.admissionDate,
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
