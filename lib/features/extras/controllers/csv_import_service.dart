// Adding students from a CSV file: the file picker (a provider so tests can
// replace it), the check against students that already exist, and the save,
// which goes through the same path as the manual quick-add.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/enrollments_repository.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';
import 'package:attendance_alamin/features/extras/controllers/bulk_add_service.dart';
import 'package:attendance_alamin/features/extras/csv_student_parser.dart';

/// Lets the teacher pick a .csv / .txt file; null when cancelled.
typedef CsvFilePicker = Future<Uint8List?> Function();

final csvFilePickerProvider = Provider<CsvFilePicker>((ref) => () async {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const <String>['csv', 'txt'],
      );
      if (file == null) return null;
      return file.readAsBytes();
    });

/// Flags rows whose name or phone already belongs to a saved student.
Future<List<CsvStudentRow>> flagExistingDuplicates(
  StudentsRepository students,
  List<CsvStudentRow> rows,
) async {
  final List<CsvStudentRow> out = <CsvStudentRow>[];
  for (final CsvStudentRow r in rows) {
    if (r.ok && (await students.findDuplicates(name: r.name, phone: r.phone)).isNotEmpty) {
      out.add(r.withProblem(CsvProblem.duplicate));
    } else {
      out.add(r);
    }
  }
  return out;
}

class CsvImportResult {
  const CsvImportResult(this.added, this.failed);

  final List<BulkAdded> added;

  /// Rows that could not be saved (reported, never fatal to the rest).
  final int failed;
}

/// Saves every ok row, one by one like the manual quick-add (enrolment from
/// [today], roll auto-filled when the file has none). [onProgress] gets the
/// number of rows handled so far.
Future<CsvImportResult> importStudentRows({
  required StudentsRepository students,
  required EnrollmentsRepository enrollments,
  required String? batchId,
  required List<CsvStudentRow> rows,
  required LocalDate today,
  void Function(int done)? onProgress,
}) async {
  final List<BulkAdded> added = <BulkAdded>[];
  int failed = 0;
  int done = 0;
  for (final CsvStudentRow r in rows) {
    if (!r.ok) continue;
    try {
      added.add(await bulkAddStudent(
        students: students,
        enrollments: enrollments,
        batchId: batchId,
        name: r.name,
        guardianPhone: r.phone ?? '',
        today: today,
        roll: r.roll,
      ));
    } on Object {
      failed++;
    }
    onProgress?.call(++done);
  }
  return CsvImportResult(added, failed);
}
