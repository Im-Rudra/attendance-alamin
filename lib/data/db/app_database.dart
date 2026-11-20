import 'package:attendance_alamin/data/db/migrations.dart';
import 'package:attendance_alamin/data/db/tables/activity_tables.dart';
import 'package:attendance_alamin/data/db/tables/meta_tables.dart';
import 'package:attendance_alamin/data/db/tables/people_tables.dart';
import 'package:attendance_alamin/data/db/tables/structure_tables.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The app's SQLite database (Arch 3, plan M3-A).
///
/// 14 synced tables (in `kSyncedTables` order) + 3 local-only tables.
/// Repositories are the only writers; they stamp sync columns through
/// `SyncStamper` and never hard-delete. Open with `openConnection()` in the
/// app and `NativeDatabase.memory()` in tests.
@DriftDatabase(tables: [
  Subjects,
  Batches,
  BatchSlots,
  ScheduleExceptions,
  BatchFees,
  Students,
  StudentPhotos,
  Enrollments,
  EnrollmentFees,
  AttendanceSessions,
  AttendanceRecords,
  Payments,
  OtherIncome,
  SyncedSettings,
  LocalMeta,
  SafetySnapshots,
  ImportLog,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Must equal `kCurrentSchemaVersion` (asserted by a test). Kept as a
  /// literal because drift_dev reads it from the source for schema dumps.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => buildMigrationStrategy(this);

  /// Re-runs [load] whenever any of [tables] changes (and once on listen).
  /// Used for multi-table reads; v1 has no SQL joins (plan section 2.6).
  Stream<T> watchComposite<T>(
    Set<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() load,
  ) {
    // Drift shares one query stream per (sql, variables) key and keeps the
    // table set of the FIRST registration. Composite streams over different
    // tables must therefore carry their table names in the SQL, or they would
    // never refresh after writes to their own tables.
    final names = <String>[for (final t in tables) t.entityName]..sort();
    return customSelect('SELECT 1 /* ${names.join(',')} */', readsFrom: tables)
        .watch()
        .asyncMap((_) => load());
  }
}
