import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/schema_v2.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

/// Migration strategy of `AppDatabase` (Arch 7.2).
///
/// - `onCreate` creates every table and index and seeds the default place.
/// - `onUpgrade` uses explicit `if (from < N)` steps, each additive
///   (`addColumn` / `createTable`) and safe to run again on a half-migrated
///   file (columns are only added when missing, seeds are insert-or-ignore,
///   backfills only fill NULLs). A safety copy of the old rows is written
///   first. Tested from a real v1 file in `test/data/db/migration_test.dart`.
/// - `beforeOpen` turns foreign keys on (they are per connection in SQLite)
///   and, in debug builds, runs `PRAGMA quick_check`.
MigrationStrategy buildMigrationStrategy(AppDatabase db) {
  return MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await ensureDefaultPlace(db);
    },
    onUpgrade: (m, from, to) async {
      if (from > to) {
        throw StateError(
            'Database schema v$from is newer than this app (v$to). Update the app.');
      }
      if (from < 2) await migrateToV2(db, m, from: from);
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

Future<bool> _hasColumn(AppDatabase db, String table, String column) async {
  final rows = await db.customSelect('PRAGMA table_info("$table")').get();
  return rows.any((r) => r.data['name'] == column);
}

/// v1 -> v2 (teacher feedback items 1-3): `places` (+ the default place from
/// the centre settings), `batches.kind` / `batches.place_id`,
/// `payments.receipt_no` (existing receipts numbered in payment-date order)
/// and `other_income.place_id`. Lossless: existing rows only gain columns.
@visibleForTesting
Future<void> migrateToV2(AppDatabase db, Migrator m, {required int from}) async {
  try {
    await writeMigrationSafetyCopy(db, fromVersion: from);
  } on Object catch (e) {
    // The copy is a convenience; never let it block opening the data.
    debugPrint('schema v2: safety copy skipped: $e');
  }
  final present = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'places'",
  ).get();
  if (present.isEmpty) await m.createTable(db.places);
  if (!await _hasColumn(db, 'batches', 'kind')) {
    await m.addColumn(db.batches, db.batches.kind);
  }
  if (!await _hasColumn(db, 'batches', 'place_id')) {
    await m.addColumn(db.batches, db.batches.placeId);
  }
  if (!await _hasColumn(db, 'payments', 'receipt_no')) {
    await m.addColumn(db.payments, db.payments.receiptNo);
  }
  if (!await _hasColumn(db, 'other_income', 'place_id')) {
    await m.addColumn(db.otherIncome, db.otherIncome.placeId);
  }
  await ensureDefaultPlace(db);
  await backfillReceiptNumbers(db);
}
