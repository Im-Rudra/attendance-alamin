import 'dart:typed_data';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/delete_impact.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';

export 'package:attendance_alamin/data/repositories/delete_impact.dart';

/// Largest stored student photo (JPEG bytes), matching the DB CHECK.
const int kMaxPhotoBytes = 204800;

/// Students and their photos (plan M4-B). Reads skip tombstones; every write
/// stamps sync columns. Expected failures throw `AppException` subclasses.
abstract interface class StudentsRepository {
  /// Live students (optionally one status), sorted by roll (numeric first),
  /// then name.
  Stream<List<Student>> watchAll({StudentStatus? status});
  Stream<Student?> watchById(String id);
  Future<Student?> getById(String id);

  /// Live students with the same name (trimmed, case-insensitive) or whose
  /// phone / guardian phone equals [phone] (normalised).
  Future<List<Student>> findDuplicates({required String name, String? phone});

  /// Max numeric roll + 1, zero-padded to 2 (`'01'` when there is none).
  Future<String> nextRoll();

  /// Validates (name, phones) and returns the new id. Status = active.
  Future<String> create(StudentDraft d);
  Future<void> update(String id, StudentDraft d);

  /// Status left from [on]; every open enrollment ends on [on] with the LBM
  /// from [lastBillableByEnrollment] or, when absent, the Product 3.2 default
  /// (`DuesEngine.defaultLastBillableMonth(on)`). One transaction.
  Future<void> markLeft(String id,
      {required LocalDate on,
      required Map<String, YearMonth> lastBillableByEnrollment});

  /// Status active again; re-opens the enrollments that ended with the leave
  /// (clears LBM and end date). Returns the number of distinct gap months
  /// (after the LBM, before the month of [on], default today); with
  /// [waiveGap] they are waived. [on] ("back from") before the leave date
  /// throws `dateInvalid`.
  Future<int> rejoin(String id, {required bool waiveGap, LocalDate? on});

  Future<Uint8List?> getPhoto(String id);

  /// `null` (or empty) removes the photo. More than [kMaxPhotoBytes] throws
  /// `photoTooLarge`.
  Future<void> setPhoto(String id, Uint8List? jpeg);

  /// sessions = attendance marks, payments = receipts, students = 1.
  Future<DeleteImpact> deleteImpact(String id);

  /// Tombstones the student with its enrollments, fee overrides, payments,
  /// attendance marks and photo.
  Future<void> softDelete(String id);
}
