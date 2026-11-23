/// Current drift schema version (also the snapshot `schemaVersion`).
const kCurrentSchemaVersion = 2;

/// Every table that travels in a backup snapshot, parents before children.
const kSyncedTables = <String>[
  'places',
  'subjects',
  'batches',
  'batch_slots',
  'schedule_exceptions',
  'batch_fees',
  'students',
  'student_photos',
  'enrollments',
  'enrollment_fees',
  'attendance_sessions',
  'attendance_records',
  'payments',
  'other_income',
  'settings',
];

/// Columns holding binary data (base64 in the JSON snapshot).
const kBlobColumns = <String, Set<String>>{
  'student_photos': {'jpeg'},
};

/// Sync-stamp columns present on every synced table.
const kSyncColumns = {
  'id',
  'created_at',
  'updated_at',
  'deleted_at',
  'device_id',
  'rev',
};
