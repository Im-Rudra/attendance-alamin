import 'package:attendance_alamin/data/db/tables/structure_tables.dart';
import 'package:attendance_alamin/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// `students` (Arch 3.2). Dates are `TEXT 'YYYY-MM-DD'`.
@DataClassName('StudentRow')
@TableIndex(name: 'idx_students_status', columns: {#status})
@TableIndex(name: 'idx_students_name', columns: {#name})
class Students extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get roll => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get guardianName => text().nullable()();
  TextColumn get guardianPhone => text().nullable()();
  TextColumn get admissionDate => text()();
  TextColumn get status => text()();
  TextColumn get leftDate => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// INTEGER 0/1 (drift adds `CHECK (has_photo IN (0, 1))`).
  BoolColumn get hasPhoto => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (status IN ('active','left'))",
      ];
}

/// `student_photos`: id = student_id, JPEG ≤ 200 KB. Separate table so list
/// queries never load blobs.
@DataClassName('StudentPhotoRow')
class StudentPhotos extends Table with SyncColumns {
  BlobColumn get jpeg => blob()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (id) REFERENCES students (id)',
        'CHECK (length(jpeg) <= 204800)',
      ];
}

/// `enrollments` (Arch 3.2 with plan section 1 #10/#11: `join_date`,
/// `end_date`; no `fee_override`). Re-enrolling is allowed, so no unique key.
@DataClassName('EnrollmentRow')
@TableIndex(name: 'idx_enrollments_student', columns: {#studentId})
@TableIndex(name: 'idx_enrollments_batch', columns: {#batchId})
class Enrollments extends Table with SyncColumns {
  TextColumn get studentId => text().references(Students, #id)();
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get joinDate => text()();
  IntColumn get startMonth => integer()();
  IntColumn get endMonth => integer().nullable()();
  TextColumn get endDate => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// `enrollment_fees`: per-enrollment fee override history (plan section 1 #10),
/// id = v5("efee:"+enrollment_id+":"+month). `amount NULL` = override cleared.
@DataClassName('EnrollmentFeeRow')
@TableIndex(
    name: 'idx_enrollment_fees_enrollment_month',
    columns: {#enrollmentId, #effectiveMonth})
class EnrollmentFees extends Table with SyncColumns {
  TextColumn get enrollmentId => text().references(Enrollments, #id)();
  IntColumn get effectiveMonth => integer()();
  IntColumn get amount => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (amount IS NULL OR amount >= 0)',
      ];
}
