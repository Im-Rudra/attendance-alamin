import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

/// Migration strategy of `AppDatabase` (Arch 7.2).
///
/// - `onCreate` creates every table and index.
/// - `onUpgrade` uses explicit `if (from < N)` steps, each additive
///   (`addColumn` / `createTable`). Schema v1 has no steps yet. Before the
///   first real step is added, write a safety snapshot first (Arch 7.2) and add
///   a migration test from the committed `drift_schemas/` dump.
/// - `beforeOpen` turns foreign keys on (they are per connection in SQLite)
///   and, in debug builds, runs `PRAGMA quick_check`.
MigrationStrategy buildMigrationStrategy(GeneratedDatabase db) {
  return MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from > to) {
        throw StateError(
            'Database schema v$from is newer than this app (v$to). Update the app.');
      }
      // v1 -> v2 steps go here: if (from < 2) { ... }
    },
    beforeOpen: (details) async {
      await db.customStatement('PRAGMA foreign_keys = ON');
      if (kDebugMode) {
        final rows = await db.customSelect('PRAGMA quick_check').get();
        final result = rows.map((r) => r.data.values.first).join('; ');
        assert(result == 'ok', 'PRAGMA quick_check failed: $result');
      }
    },
  );
}
