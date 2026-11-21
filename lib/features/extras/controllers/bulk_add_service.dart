// One step of the bulk quick-add loop (F20): validate, create the student and
// enrol them in the batch. When the enrolment fails the new student is removed
// again so a failed row never leaves an orphan.

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/repositories/enrollments_repository.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/student.dart';

/// A student added in this session.
class BulkAdded {
  const BulkAdded({required this.id, required this.name, required this.roll, this.guardianPhone});

  final String id;
  final String name;
  final String roll;
  final String? guardianPhone;
}

/// The existing student who already uses [rawPhone] (null when none or when
/// the phone is blank / invalid; validation errors surface on save).
Future<Student?> phoneOwner(StudentsRepository students, String rawPhone) async {
  final String? phone;
  try {
    phone = Validators.phone(rawPhone);
  } on Object {
    return null;
  }
  if (phone == null) return null;
  final List<Student> hits = await students.findDuplicates(name: '', phone: phone);
  for (final Student s in hits) {
    if (s.phone == phone || s.guardianPhone == phone) return s;
  }
  return null;
}

/// Creates [name] with the guardian phone and enrols them in [batchId] from
/// [today]; these are existing students, so billing starts this month. Throws
/// `AppException` for invalid input or an archived batch.
Future<BulkAdded> bulkAddStudent({
  required StudentsRepository students,
  required EnrollmentsRepository enrollments,
  required String batchId,
  required String name,
  required String guardianPhone,
  required LocalDate today,
}) async {
  final String cleanName = Validators.name(name);
  final String? phone = Validators.phone(guardianPhone);
  final String roll = await students.nextRoll();
  final String id = await students.create(StudentDraft(
    name: cleanName,
    roll: roll,
    guardianPhone: phone,
    admissionDate: today,
  ));
  try {
    await enrollments.enroll(
      studentId: id,
      batchId: batchId,
      joinDate: today,
      startMonth: today.yearMonth,
    );
  } catch (_) {
    await students.softDelete(id);
    rethrow;
  }
  return BulkAdded(id: id, name: cleanName, roll: roll, guardianPhone: phone);
}
