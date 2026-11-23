// GENERATED from drift_schemas/drift_schema_v1.json (`fixed_sql`, the exact
// statements schema v1 ran). Used to build a real v1 database file for the
// v1 -> v2 migration test. Do not edit by hand.

const List<String> kSchemaV1Sql = <String>[
  // subjects
  'CREATE TABLE IF NOT EXISTS "subjects" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "sort_order" INTEGER NOT NULL DEFAULT 0, "archived_at" INTEGER NULL, "notes" TEXT NULL, PRIMARY KEY ("id"));',
  // batches
  'CREATE TABLE IF NOT EXISTS "batches" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "subject_id" TEXT NOT NULL REFERENCES subjects (id), "name" TEXT NOT NULL, "billing_type" TEXT NOT NULL, "reminder_lead_min" INTEGER NULL, "archived_at" INTEGER NULL, "sort_order" INTEGER NOT NULL, "notes" TEXT NULL, PRIMARY KEY ("id"), CHECK (billing_type IN (\'prepaid\',\'postpaid\')), CHECK (reminder_lead_min IS NULL OR reminder_lead_min BETWEEN 0 AND 720));',
  // batch_slots
  'CREATE TABLE IF NOT EXISTS "batch_slots" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "batch_id" TEXT NOT NULL REFERENCES batches (id), "weekday" INTEGER NOT NULL, "start_min" INTEGER NOT NULL, "end_min" INTEGER NOT NULL, "valid_from" TEXT NULL, "valid_to" TEXT NULL, PRIMARY KEY ("id"), CHECK (weekday BETWEEN 1 AND 7), CHECK (0 <= start_min AND start_min < end_min AND end_min <= 1440));',
  // schedule_exceptions
  'CREATE TABLE IF NOT EXISTS "schedule_exceptions" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "batch_id" TEXT NOT NULL REFERENCES batches (id), "kind" TEXT NOT NULL, "slot_id" TEXT NULL REFERENCES batch_slots (id), "original_date" TEXT NULL, "new_date" TEXT NULL, "new_start_min" INTEGER NULL, "new_end_min" INTEGER NULL, "note" TEXT NULL, PRIMARY KEY ("id"), CHECK (kind IN (\'cancel\',\'reschedule\',\'extra\')), CHECK ((kind = \'cancel\' AND slot_id IS NOT NULL AND original_date IS NOT NULL) OR (kind = \'reschedule\' AND slot_id IS NOT NULL AND original_date IS NOT NULL AND new_date IS NOT NULL AND new_start_min IS NOT NULL AND new_end_min IS NOT NULL) OR (kind = \'extra\' AND slot_id IS NULL AND original_date IS NULL AND new_date IS NOT NULL AND new_start_min IS NOT NULL AND new_end_min IS NOT NULL)), CHECK (new_start_min IS NULL OR new_end_min IS NULL OR (0 <= new_start_min AND new_start_min < new_end_min AND new_end_min <= 1440)));',
  // batch_fees
  'CREATE TABLE IF NOT EXISTS "batch_fees" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "batch_id" TEXT NOT NULL REFERENCES batches (id), "effective_month" INTEGER NOT NULL, "amount" INTEGER NOT NULL, PRIMARY KEY ("id"), CHECK (amount >= 0));',
  // students
  'CREATE TABLE IF NOT EXISTS "students" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "roll" TEXT NULL, "phone" TEXT NULL, "guardian_name" TEXT NULL, "guardian_phone" TEXT NULL, "admission_date" TEXT NOT NULL, "status" TEXT NOT NULL, "left_date" TEXT NULL, "notes" TEXT NULL, "has_photo" INTEGER NOT NULL DEFAULT 0 CHECK ("has_photo" IN (0, 1)), PRIMARY KEY ("id"), CHECK (status IN (\'active\',\'left\')));',
  // student_photos
  'CREATE TABLE IF NOT EXISTS "student_photos" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "jpeg" BLOB NOT NULL, PRIMARY KEY ("id"), FOREIGN KEY (id) REFERENCES students (id), CHECK (length(jpeg) <= 204800));',
  // enrollments
  'CREATE TABLE IF NOT EXISTS "enrollments" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "student_id" TEXT NOT NULL REFERENCES students (id), "batch_id" TEXT NOT NULL REFERENCES batches (id), "join_date" TEXT NOT NULL, "start_month" INTEGER NOT NULL, "end_month" INTEGER NULL, "end_date" TEXT NULL, "notes" TEXT NULL, PRIMARY KEY ("id"));',
  // enrollment_fees
  'CREATE TABLE IF NOT EXISTS "enrollment_fees" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "enrollment_id" TEXT NOT NULL REFERENCES enrollments (id), "effective_month" INTEGER NOT NULL, "amount" INTEGER NULL, PRIMARY KEY ("id"), CHECK (amount IS NULL OR amount >= 0));',
  // attendance_sessions
  'CREATE TABLE IF NOT EXISTS "attendance_sessions" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "occ" TEXT NOT NULL, "batch_id" TEXT NOT NULL REFERENCES batches (id), "slot_id" TEXT NULL REFERENCES batch_slots (id), "original_date" TEXT NULL, "exception_id" TEXT NULL REFERENCES schedule_exceptions (id), "date" TEXT NOT NULL, "start_min" INTEGER NOT NULL, "end_min" INTEGER NOT NULL, "note" TEXT NULL, PRIMARY KEY ("id"), CHECK (0 <= start_min AND start_min < end_min AND end_min <= 1440));',
  // attendance_records
  'CREATE TABLE IF NOT EXISTS "attendance_records" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "session_id" TEXT NOT NULL REFERENCES attendance_sessions (id), "batch_id" TEXT NOT NULL REFERENCES batches (id), "student_id" TEXT NOT NULL REFERENCES students (id), "date" TEXT NOT NULL, "status" TEXT NOT NULL, PRIMARY KEY ("id"), CHECK (status IN (\'P\',\'A\',\'L\',\'E\')));',
  // payments
  'CREATE TABLE IF NOT EXISTS "payments" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "receipt_id" TEXT NOT NULL, "student_id" TEXT NOT NULL REFERENCES students (id), "enrollment_id" TEXT NOT NULL REFERENCES enrollments (id), "batch_id" TEXT NOT NULL REFERENCES batches (id), "billing_month" INTEGER NOT NULL, "amount" INTEGER NOT NULL, "paid_on" TEXT NOT NULL, "method" TEXT NOT NULL, "note" TEXT NULL, "waived" INTEGER NOT NULL DEFAULT 0 CHECK ("waived" IN (0, 1)), PRIMARY KEY ("id"), CHECK (amount >= 0), CHECK (waived = 0 OR amount = 0), CHECK (method IN (\'cash\',\'bkash\',\'nagad\',\'rocket\',\'bank\',\'other\') OR (substr(method, 1, 7) = \'custom:\' AND length(method) BETWEEN 8 AND 27)));',
  // other_income
  'CREATE TABLE IF NOT EXISTS "other_income" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "student_id" TEXT NULL REFERENCES students (id), "label" TEXT NOT NULL, "amount" INTEGER NOT NULL, "paid_on" TEXT NOT NULL, "method" TEXT NOT NULL, "note" TEXT NULL, PRIMARY KEY ("id"), CHECK (amount >= 0), CHECK (method IN (\'cash\',\'bkash\',\'nagad\',\'rocket\',\'bank\',\'other\') OR (substr(method, 1, 7) = \'custom:\' AND length(method) BETWEEN 8 AND 27)));',
  // settings
  'CREATE TABLE IF NOT EXISTS "settings" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, "rev" INTEGER NOT NULL DEFAULT 1, "value" TEXT NOT NULL, PRIMARY KEY ("id"));',
  // local_meta
  'CREATE TABLE IF NOT EXISTS "local_meta" ("meta_key" TEXT NOT NULL, "meta_value" TEXT NOT NULL, PRIMARY KEY ("meta_key"));',
  // safety_snapshots
  'CREATE TABLE IF NOT EXISTS "safety_snapshots" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "reason" TEXT NOT NULL, "bytes" BLOB NOT NULL, PRIMARY KEY ("id"));',
  // import_log
  'CREATE TABLE IF NOT EXISTS "import_log" ("id" TEXT NOT NULL, "imported_at" INTEGER NOT NULL, "snapshot_id" TEXT NOT NULL, "source_device_id" TEXT NOT NULL, "summary_json" TEXT NOT NULL, PRIMARY KEY ("id"));',
  // idx_subjects_deleted_sort
  'CREATE INDEX idx_subjects_deleted_sort ON subjects (deleted_at, sort_order)',
  // idx_batches_subject
  'CREATE INDEX idx_batches_subject ON batches (subject_id)',
  // idx_batch_slots_weekday
  'CREATE INDEX idx_batch_slots_weekday ON batch_slots (weekday)',
  // idx_batch_slots_batch
  'CREATE INDEX idx_batch_slots_batch ON batch_slots (batch_id)',
  // idx_schedule_exceptions_original_date
  'CREATE INDEX idx_schedule_exceptions_original_date ON schedule_exceptions (original_date)',
  // idx_schedule_exceptions_new_date
  'CREATE INDEX idx_schedule_exceptions_new_date ON schedule_exceptions (new_date)',
  // idx_schedule_exceptions_batch
  'CREATE INDEX idx_schedule_exceptions_batch ON schedule_exceptions (batch_id)',
  // idx_batch_fees_batch_month
  'CREATE INDEX idx_batch_fees_batch_month ON batch_fees (batch_id, effective_month)',
  // idx_students_status
  'CREATE INDEX idx_students_status ON students (status)',
  // idx_students_name
  'CREATE INDEX idx_students_name ON students (name)',
  // idx_enrollments_student
  'CREATE INDEX idx_enrollments_student ON enrollments (student_id)',
  // idx_enrollments_batch
  'CREATE INDEX idx_enrollments_batch ON enrollments (batch_id)',
  // idx_enrollment_fees_enrollment_month
  'CREATE INDEX idx_enrollment_fees_enrollment_month ON enrollment_fees (enrollment_id, effective_month)',
  // idx_attendance_sessions_occ
  'CREATE INDEX idx_attendance_sessions_occ ON attendance_sessions (occ)',
  // idx_attendance_sessions_batch_date
  'CREATE INDEX idx_attendance_sessions_batch_date ON attendance_sessions (batch_id, date)',
  // idx_attendance_sessions_date
  'CREATE INDEX idx_attendance_sessions_date ON attendance_sessions (date)',
  // idx_attendance_records_session
  'CREATE INDEX idx_attendance_records_session ON attendance_records (session_id)',
  // idx_attendance_records_student_batch_date
  'CREATE INDEX idx_attendance_records_student_batch_date ON attendance_records (student_id, batch_id, date)',
  // idx_payments_enrollment_month
  'CREATE INDEX idx_payments_enrollment_month ON payments (enrollment_id, billing_month)',
  // idx_payments_paid_on
  'CREATE INDEX idx_payments_paid_on ON payments (paid_on)',
  // idx_payments_student
  'CREATE INDEX idx_payments_student ON payments (student_id)',
  // idx_payments_receipt
  'CREATE INDEX idx_payments_receipt ON payments (receipt_id)',
  // idx_other_income_paid_on
  'CREATE INDEX idx_other_income_paid_on ON other_income (paid_on)',
  // idx_other_income_student
  'CREATE INDEX idx_other_income_student ON other_income (student_id)',
];
