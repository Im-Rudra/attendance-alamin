import 'package:attendance_alamin/data/db/tables/sync_columns.dart';
import 'package:drift/drift.dart';

/// `settings`: synced settings only (Arch 3.8). id = the setting key, `value`
/// is a JSON-encoded scalar.
@DataClassName('SettingRow')
class SyncedSettings extends Table with SyncColumns {
  @override
  String get tableName => 'settings';

  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// `local_meta` (local only, never exported): device keys such as
/// `device_id`, `locale`, `theme_mode`, drafts (Arch 3.3, plan M4-C).
@DataClassName('LocalMetaRow')
class LocalMeta extends Table {
  TextColumn get metaKey => text()();
  TextColumn get metaValue => text()();

  @override
  Set<Column> get primaryKey => {metaKey};
}

/// `safety_snapshots` (local only): gzip snapshot written before every import
/// and every schema migration.
@DataClassName('SafetySnapshotRow')
class SafetySnapshots extends Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();
  TextColumn get reason => text()();
  BlobColumn get bytes => blob()();

  @override
  Set<Column> get primaryKey => {id};
}

/// `import_log` (local only): one row per applied import.
@DataClassName('ImportLogRow')
class ImportLog extends Table {
  TextColumn get id => text()();
  IntColumn get importedAt => integer()();
  TextColumn get snapshotId => text()();
  TextColumn get sourceDeviceId => text()();
  TextColumn get summaryJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}
