import 'package:attendance_alamin/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// `subjects` (Arch 3.2).
@DataClassName('SubjectRow')
@TableIndex(name: 'idx_subjects_deleted_sort', columns: {#deletedAt, #sortOrder})
class Subjects extends Table with SyncColumns {
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get archivedAt => integer().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// `batches` (Arch 3.2). `reminder_lead_min`: NULL = global default, 0 = off.
@DataClassName('BatchRow')
@TableIndex(name: 'idx_batches_subject', columns: {#subjectId})
class Batches extends Table with SyncColumns {
  TextColumn get subjectId => text().references(Subjects, #id)();
  TextColumn get name => text()();
  TextColumn get billingType => text()();
  IntColumn get reminderLeadMin => integer().nullable()();
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get sortOrder => integer()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (billing_type IN ('prepaid','postpaid'))",
        'CHECK (reminder_lead_min IS NULL OR reminder_lead_min BETWEEN 0 AND 720)',
      ];
}

/// `batch_slots`: one weekly recurring class (ISO weekday, `[start, end)`
/// minutes, inclusive validity dates). No uniqueness on (batch, weekday).
@DataClassName('SlotRow')
@TableIndex(name: 'idx_batch_slots_weekday', columns: {#weekday})
@TableIndex(name: 'idx_batch_slots_batch', columns: {#batchId})
class BatchSlots extends Table with SyncColumns {
  TextColumn get batchId => text().references(Batches, #id)();
  IntColumn get weekday => integer()();
  IntColumn get startMin => integer()();
  IntColumn get endMin => integer()();
  TextColumn get validFrom => text().nullable()();
  TextColumn get validTo => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (weekday BETWEEN 1 AND 7)',
        'CHECK (0 <= start_min AND start_min < end_min AND end_min <= 1440)',
      ];
}

/// `schedule_exceptions`: cancel / reschedule (id = v5("exc:"+occ)) or extra
/// class (id = v4, occurrence `x.<id>`).
@DataClassName('ExceptionRow')
@TableIndex(name: 'idx_schedule_exceptions_original_date', columns: {#originalDate})
@TableIndex(name: 'idx_schedule_exceptions_new_date', columns: {#newDate})
@TableIndex(name: 'idx_schedule_exceptions_batch', columns: {#batchId})
class ScheduleExceptions extends Table with SyncColumns {
  TextColumn get batchId => text().references(Batches, #id)();
  TextColumn get kind => text()();
  TextColumn get slotId => text().nullable().references(BatchSlots, #id)();
  TextColumn get originalDate => text().nullable()();
  TextColumn get newDate => text().nullable()();
  IntColumn get newStartMin => integer().nullable()();
  IntColumn get newEndMin => integer().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (kind IN ('cancel','reschedule','extra'))",
        "CHECK ((kind = 'cancel' AND slot_id IS NOT NULL AND original_date IS NOT NULL) "
            "OR (kind = 'reschedule' AND slot_id IS NOT NULL AND original_date IS NOT NULL "
            'AND new_date IS NOT NULL AND new_start_min IS NOT NULL AND new_end_min IS NOT NULL) '
            "OR (kind = 'extra' AND slot_id IS NULL AND original_date IS NULL "
            'AND new_date IS NOT NULL AND new_start_min IS NOT NULL AND new_end_min IS NOT NULL))',
        'CHECK (new_start_min IS NULL OR new_end_min IS NULL '
            'OR (0 <= new_start_min AND new_start_min < new_end_min AND new_end_min <= 1440))',
      ];
}

/// `batch_fees`: fee history, id = v5("fee:"+batch_id+":"+month). The fee for
/// month M is the row with the greatest `effective_month <= M`.
@DataClassName('BatchFeeRow')
@TableIndex(name: 'idx_batch_fees_batch_month', columns: {#batchId, #effectiveMonth})
class BatchFees extends Table with SyncColumns {
  TextColumn get batchId => text().references(Batches, #id)();
  IntColumn get effectiveMonth => integer()();
  IntColumn get amount => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (amount >= 0)',
      ];
}
