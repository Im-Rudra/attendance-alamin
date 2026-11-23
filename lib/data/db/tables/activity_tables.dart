import 'package:attendance_alamin/data/db/tables/people_tables.dart';
import 'package:attendance_alamin/data/db/tables/structure_tables.dart';
import 'package:attendance_alamin/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// `attendance_sessions`: "roll call was taken" for ONE class occurrence
/// (Arch 3.2a), id = v5("ses:"+occ). A batch can have several sessions on one
/// date. `date` / `start_min` / `end_min` are the actual (snapshotted) values.
@DataClassName('SessionRow')
@TableIndex(name: 'idx_attendance_sessions_occ', columns: {#occ})
@TableIndex(name: 'idx_attendance_sessions_batch_date', columns: {#batchId, #date})
@TableIndex(name: 'idx_attendance_sessions_date', columns: {#date})
class AttendanceSessions extends Table with SyncColumns {
  TextColumn get occ => text()();
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get slotId => text().nullable().references(BatchSlots, #id)();
  TextColumn get originalDate => text().nullable()();
  TextColumn get exceptionId =>
      text().nullable().references(ScheduleExceptions, #id)();
  TextColumn get date => text()();
  IntColumn get startMin => integer()();
  IntColumn get endMin => integer()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (0 <= start_min AND start_min < end_min AND end_min <= 1440)',
      ];
}

/// `attendance_records`: id = v5("att:"+occ+":"+student_id); status
/// P / A / L / E (E = leave, plan section 1 #12).
@DataClassName('RecordRow')
@TableIndex(name: 'idx_attendance_records_session', columns: {#sessionId})
@TableIndex(
    name: 'idx_attendance_records_student_batch_date',
    columns: {#studentId, #batchId, #date})
class AttendanceRecords extends Table with SyncColumns {
  TextColumn get sessionId => text().references(AttendanceSessions, #id)();
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get studentId => text().references(Students, #id)();
  TextColumn get date => text()();
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (status IN ('P','A','L','E'))",
      ];
}

/// `payments`: one row per billing month (an allocation); rows entered
/// together share `receipt_id` (plan section 1 #9). Waived = `waived=1,
/// amount=0`. Method: built-in or `custom:<label>` (1..20 chars, #13).
@DataClassName('PaymentRow')
@TableIndex(
    name: 'idx_payments_enrollment_month',
    columns: {#enrollmentId, #billingMonth})
@TableIndex(name: 'idx_payments_paid_on', columns: {#paidOn})
@TableIndex(name: 'idx_payments_student', columns: {#studentId})
@TableIndex(name: 'idx_payments_receipt', columns: {#receiptId})
class Payments extends Table with SyncColumns {
  TextColumn get receiptId => text()();
  TextColumn get studentId => text().references(Students, #id)();
  TextColumn get enrollmentId => text().references(Enrollments, #id)();
  TextColumn get batchId => text().references(Batches, #id)();
  IntColumn get billingMonth => integer()();
  IntColumn get amount => integer()();
  TextColumn get paidOn => text()();
  TextColumn get method => text()();
  TextColumn get note => text().nullable()();

  /// INTEGER 0/1 (drift adds `CHECK (waived IN (0, 1))`).
  BoolColumn get waived => boolean().withDefault(const Constant(false))();

  /// Schema v2: slip number `{year}-{seq:4}`, same on every row of a receipt,
  /// NULL on waivers (see `receipt_numbers.dart`).
  TextColumn get receiptNo => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (amount >= 0)',
        'CHECK (waived = 0 OR amount = 0)',
        "CHECK (method IN ('cash','bkash','nagad','rocket','bank','other') "
            "OR (substr(method, 1, 7) = 'custom:' AND length(method) BETWEEN 8 AND 27))",
      ];
}

/// `other_income` (F22, plan section 1 #14): income that is not a monthly fee.
@DataClassName('OtherIncomeRow')
@TableIndex(name: 'idx_other_income_paid_on', columns: {#paidOn})
@TableIndex(name: 'idx_other_income_student', columns: {#studentId})
class OtherIncome extends Table with SyncColumns {
  TextColumn get studentId => text().nullable().references(Students, #id)();
  TextColumn get label => text()();
  IntColumn get amount => integer()();
  TextColumn get paidOn => text()();
  TextColumn get method => text()();
  TextColumn get note => text().nullable()();

  /// Schema v2: the place it belongs to; NULL = general. No foreign key
  /// (kept valid by the repository, like `batches.place_id`).
  TextColumn get placeId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (amount >= 0)',
        "CHECK (method IN ('cash','bkash','nagad','rocket','bank','other') "
            "OR (substr(method, 1, 7) = 'custom:' AND length(method) BETWEEN 8 AND 27))",
      ];
}
