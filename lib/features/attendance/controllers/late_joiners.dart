// Students who joined a batch AFTER the date of the roll call being viewed
// (they are not on that day's roster). The roll call shows a quiet footer line
// and lets the teacher see them.

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/student.dart';

/// Marking a late joiner means moving their join date back to the roll-call
/// date first (otherwise the mark would not belong to their enrolment): the
/// list asks once "Move {name}'s join date to {date}?", calls
/// `EnrollmentsRepository.updateJoinDate` and reloads the roster, so the
/// student can be marked. Billing is not touched.
const bool kLateJoinerMoveEnabled = true;

class LateJoiner {
  const LateJoiner({required this.enrollmentId, required this.student, required this.joinDate});

  final String enrollmentId;
  final Student student;
  final LocalDate joinDate;
}

/// Open enrolments of the batch whose join date is after [date], with their
/// students (an enrolment without a student is skipped). Earliest join first,
/// then by name.
List<LateJoiner> lateJoinersOf({
  required LocalDate date,
  required Iterable<Enrollment> enrollments,
  required Map<String, Student> studentsById,
}) {
  final List<LateJoiner> out = <LateJoiner>[];
  for (final Enrollment e in enrollments) {
    if (e.endDate != null || !e.joinDate.isAfter(date)) continue;
    final Student? s = studentsById[e.studentId];
    if (s == null) continue;
    out.add(LateJoiner(enrollmentId: e.id, student: s, joinDate: e.joinDate));
  }
  out.sort((LateJoiner a, LateJoiner b) {
    final int byDate = a.joinDate.compareTo(b.joinDate);
    return byDate != 0 ? byDate : a.student.name.compareTo(b.student.name);
  });
  return out;
}
