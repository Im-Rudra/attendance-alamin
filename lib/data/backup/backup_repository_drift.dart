import 'dart:convert';
import 'dart:typed_data';

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/backup/backup_repository.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/db_queries.dart';
import 'package:attendance_alamin/data/db/schema_v2.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/drift/settings_repository_drift.dart'
    show decodeSetting;
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/sync/snapshot_codec.dart';
import 'package:attendance_alamin/domain/sync/sync_diff.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';
import 'package:drift/drift.dart' hide Batch;

/// Drift implementation of [BackupRepository] (Arch 3.3-3.6, plan M4-C).
///
/// Table-agnostic: rows are read with `SELECT *` and written with
/// `INSERT ... ON CONFLICT(id) DO UPDATE` (never `INSERT OR REPLACE`), using
/// the column list from `PRAGMA table_info`. Imported rows keep their own
/// sync columns (that is what last-writer-wins compares).
class DriftBackupRepository implements BackupRepository {
  DriftBackupRepository(this._db, this._stamper, this._center);

  final AppDatabase _db;
  final SyncStamper _stamper;
  final CenterTime _center;

  Map<String, List<_Col>>? _schemaCache;

  // ---------------------------------------------------------------- export

  @override
  Future<Snapshot> buildSnapshot({required String appVersion}) async {
    final tables = await _db.transaction(_readSyncedTables);
    return SnapshotCodec.build(
      tables: tables,
      appVersion: appVersion,
      snapshotId: Ids.v4(),
      deviceId: _stamper.deviceId,
      deviceName: await _deviceName(),
      createdAtMs: _stamper.nowMs(),
    );
  }

  // ---------------------------------------------------------------- import

  @override
  Future<ChangeSummary> preview(Snapshot incoming) async {
    final schema = await _schema();
    _validateTables(incoming.tables, schema);
    ChangeSummary? summary;
    try {
      await _db.transaction(() async {
        final local = await _readSyncedTables();
        final diff = SyncDiff.diff(local: local, incoming: incoming);
        summary = diff;
        if (diff.winners.isEmpty) return;
        // Trial apply: surfaces CHECK / parent-row problems before the
        // teacher confirms, then always rolls back.
        await _db.customStatement('PRAGMA defer_foreign_keys = ON');
        await _writeRows([for (final w in diff.winners) (w.table, w.incoming)], schema);
        await _integrityChecks();
        throw const _TrialRollback();
      });
    } on _TrialRollback {
      // expected: nothing was changed
    }
    final result = summary;
    if (result == null) throw StateError('preview produced no summary');
    return result;
  }

  @override
  Future<ApplyOutcome> apply(Snapshot incoming, ChangeSummary summary) async {
    // Lead rule (M2-D): apply only when the summary shows changes.
    if (summary.isEmpty) return const ApplyOutcome(applied: 0, safetyCopyId: '');
    final schema = await _schema();
    _validateTables(incoming.tables, schema);

    final outcome = await _db.transaction(() async {
      final local = await _readSyncedTables();
      final diff = SyncDiff.diff(local: local, incoming: incoming);
      if (diff.isEmpty) return const ApplyOutcome(applied: 0, safetyCopyId: '');

      final copyId = await _writeSafetyCopy(local, SafetyCopyReason.beforeImport);
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      // Winners are already ordered: deletions first, then registry order.
      await _writeRows([for (final w in diff.winners) (w.table, w.incoming)], schema);
      await _afterRawWrite(incoming);
      final now = _stamper.nowMs();
      await _db.into(_db.importLog).insert(ImportLogCompanion.insert(
            id: Ids.v4(),
            importedAt: now,
            snapshotId: incoming.snapshotId,
            sourceDeviceId: incoming.deviceId,
            summaryJson: _summaryJson(diff),
          ));
      await _db.into(_db.localMeta).insertOnConflictUpdate(LocalMetaCompanion.insert(
            metaKey: LocalMetaKeys.lastImport(incoming.deviceId),
            metaValue: '${incoming.createdAtMs}',
          ));
      await _integrityChecks();
      return ApplyOutcome(applied: diff.winners.length, safetyCopyId: copyId);
    });
    if (outcome.applied > 0) _notifySyncedTables();
    return outcome;
  }

  // ---------------------------------------------------------------- safety copies

  @override
  Stream<List<SafetyCopyInfo>> watchSafetyCopies() => _db
      .customSelect(
        'SELECT id, created_at, reason FROM safety_snapshots '
        'ORDER BY created_at DESC, rowid DESC LIMIT $kSafetyCopiesKept',
        readsFrom: {_db.safetySnapshots},
      )
      .watch()
      .map((rows) => List<SafetyCopyInfo>.unmodifiable([
            for (final r in rows)
              SafetyCopyInfo(
                id: r.read<String>('id'),
                createdAtMs: r.read<int>('created_at'),
                reason: r.read<String>('reason'),
              ),
          ]));

  @override
  Future<void> restoreSafetyCopy(String id) async {
    final row = await (_db.select(_db.safetySnapshots)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw NotFoundException(ErrorCodes.notFound, detail: 'safety copy $id');
    final snapshot = SnapshotCodec.decode(row.bytes);
    final schema = await _schema();
    _validateTables(snapshot.tables, schema);

    await _db.transaction(() async {
      final local = await _readSyncedTables();
      await _writeSafetyCopy(local, SafetyCopyReason.beforeRestore);
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      // The only sanctioned hard delete (plan 2.6): full replace.
      for (final t in kSyncedTables.reversed) {
        await _db.customStatement('DELETE FROM "$t"');
      }
      await _writeRows([
        for (final t in kSyncedTables)
          for (final r in snapshot.tables[t] ?? const <RowMap>[]) (t, r),
      ], schema);
      await _afterRawWrite(snapshot);
      await _integrityChecks();
    });
    _notifySyncedTables();
  }

  // ---------------------------------------------------------------- overfilled months

  @override
  Future<int> countOverfilledMonths() async {
    final terms = await loadEnrollmentTerms(_db, _center);
    final termsById = {for (final t in terms) t.enrollmentId: t};
    final payments = await (_db.select(_db.payments)..where((t) => t.deletedAt.isNull())).get();
    final paid = <(String, int), int>{};
    final waived = <(String, int)>{};
    for (final p in payments) {
      final key = (p.enrollmentId, p.billingMonth);
      if (p.waived) {
        waived.add(key);
      } else {
        paid[key] = (paid[key] ?? 0) + p.amount;
      }
    }
    var count = 0;
    for (final e in paid.entries) {
      if (waived.contains(e.key)) continue;
      final t = termsById[e.key.$1];
      if (t == null) continue;
      final fee = DuesEngine.feeFor(t, YearMonth.fromInt(e.key.$2)).fee;
      if (e.value > fee) count++;
    }
    return count;
  }

  // ---------------------------------------------------------------- internals

  /// Schema v2 after rows were written straight into the tables: the default
  /// place must exist (a full restore deletes it), and rows of a v1 file
  /// (schemaVersion 1, or the pre-migration safety copy, which has no
  /// `places` table) get slip numbers in payment-date order.
  Future<void> _afterRawWrite(Snapshot s) async {
    await ensureDefaultPlace(_db);
    if (s.schemaVersion < 2 || !s.tables.containsKey('places')) {
      await backfillReceiptNumbers(_db);
    }
  }

  /// Every row (tombstones included) of every synced table; blobs as base64.
  Future<Map<String, List<RowMap>>> _readSyncedTables() async {
    final out = <String, List<RowMap>>{};
    for (final t in kSyncedTables) {
      final blobs = kBlobColumns[t] ?? const <String>{};
      final rows = await _db.customSelect('SELECT * FROM "$t"').get();
      out[t] = [
        for (final r in rows)
          <String, Object?>{
            for (final e in r.data.entries)
              e.key: (blobs.contains(e.key) && e.value is List<int>)
                  ? base64Encode(e.value as List<int>)
                  : e.value,
          },
      ];
    }
    return out;
  }

  Future<String> _deviceName() async {
    final row = await (_db.select(_db.localMeta)
          ..where((t) => t.metaKey.equals(SettingKeys.deviceName.id)))
        .getSingleOrNull();
    return decodeSetting(SettingKeys.deviceName, row?.metaValue);
  }

  Future<Map<String, List<_Col>>> _schema() async {
    final cached = _schemaCache;
    if (cached != null) return cached;
    final out = <String, List<_Col>>{};
    for (final t in kSyncedTables) {
      final rows = await _db.customSelect('PRAGMA table_info("$t")').get();
      out[t] = [
        for (final r in rows)
          _Col(
            name: r.read<String>('name'),
            type: r.read<String>('type').toUpperCase(),
            notNull: r.read<int>('notnull') != 0,
            hasDefault: r.data['dflt_value'] != null,
          ),
      ];
    }
    return _schemaCache = out;
  }

  /// Shape checks the database cannot do itself (SQLite is loosely typed).
  /// CHECK constraints and parent rows are verified by the (trial) apply.
  void _validateTables(Map<String, List<RowMap>> tables, Map<String, List<_Col>> schema) {
    for (final t in kSyncedTables) {
      final rows = tables[t];
      if (rows == null) continue;
      final cols = {for (final c in schema[t]!) c.name: c};
      for (final row in rows) {
        _validateRow(t, row, cols);
      }
    }
  }

  static void _validateRow(String table, RowMap row, Map<String, _Col> cols) {
    final id = row['id'];
    Never fail(String what) =>
        throw ImportException(ErrorCodes.importCorrupt, detail: '$table/$id: $what');
    for (final k in row.keys) {
      if (!cols.containsKey(k)) fail('unknown column $k');
    }
    for (final c in cols.values) {
      if (!row.containsKey(c.name)) {
        if (c.notNull && !c.hasDefault) fail('missing ${c.name}');
        continue;
      }
      final v = row[c.name];
      if (v == null) {
        if (c.notNull) fail('null ${c.name}');
        continue;
      }
      switch (c.type) {
        case 'INTEGER':
          if (v is! int) fail('${c.name} is not an integer');
          if (_isMonthColumn(c.name) && !_validMonth(v)) fail('bad month ${c.name}');
        case 'TEXT':
          if (v is! String) fail('${c.name} is not text');
          if (_isDateColumn(c.name) && LocalDate.tryParse(v) == null) {
            fail('bad date ${c.name}');
          }
        case 'BLOB':
          if (v is! String) fail('${c.name} is not base64');
          try {
            base64Decode(v);
          } on FormatException {
            fail('${c.name} is not base64');
          }
        case 'REAL':
          if (v is! num) fail('${c.name} is not a number');
        default:
          fail('unsupported column type ${c.type}');
      }
    }
  }

  static bool _isDateColumn(String name) =>
      name == 'date' ||
      name.endsWith('_date') ||
      name == 'paid_on' ||
      name == 'valid_from' ||
      name == 'valid_to';

  static bool _isMonthColumn(String name) => name.endsWith('_month');

  static bool _validMonth(int yyyymm) {
    final m = yyyymm % 100;
    return yyyymm > 0 && m >= 1 && m <= 12;
  }

  /// Upserts [rows] (`(table, row)` in the given order) in one drift batch.
  /// Database errors (CHECK failures) become `ImportException(importCorrupt)`.
  Future<void> _writeRows(List<(String, RowMap)> rows, Map<String, List<_Col>> schema) async {
    if (rows.isEmpty) return;
    final sqlCache = <String, String>{};
    final statements = <(String, List<Object?>)>[];
    for (final (table, row) in rows) {
      final cols = [
        for (final c in schema[table]!)
          if (row.containsKey(c.name)) c,
      ];
      final names = cols.map((c) => c.name).toList();
      final sql = sqlCache.putIfAbsent('$table|${names.join(',')}', () => _upsertSql(table, names));
      final args = <Object?>[
        for (final c in cols)
          if (c.type == 'BLOB' && row[c.name] is String)
            base64Decode(row[c.name] as String)
          else
            row[c.name],
      ];
      statements.add((sql, args));
    }
    try {
      await _db.batch((b) {
        for (final (sql, args) in statements) {
          b.customStatement(sql, args);
        }
      });
    } on AppException {
      rethrow;
    } on Object catch (e) {
      throw ImportException(ErrorCodes.importCorrupt, detail: 'write failed: $e');
    }
  }

  static String _upsertSql(String table, List<String> cols) {
    final quoted = cols.map((c) => '"$c"').join(', ');
    final params = List.filled(cols.length, '?').join(', ');
    final updates = [
      for (final c in cols)
        if (c != 'id') '"$c" = excluded."$c"',
    ];
    final onConflict =
        updates.isEmpty ? 'DO NOTHING' : 'DO UPDATE SET ${updates.join(', ')}';
    return 'INSERT INTO "$table" ($quoted) VALUES ($params) ON CONFLICT("id") $onConflict';
  }

  /// Arch 3.6 step 5: any failure rolls the transaction back.
  Future<void> _integrityChecks() async {
    final fk = await _db.customSelect('PRAGMA foreign_key_check').get();
    if (fk.isNotEmpty) {
      final first = fk.first.data;
      throw ImportException(ErrorCodes.importMissingParent,
          detail: '${first['table']} row ${first['rowid']} -> ${first['parent']} (${fk.length} rows)');
    }
    final qc = await _db.customSelect('PRAGMA quick_check').get();
    final result = qc.map((r) => '${r.data.values.first}').join('; ');
    if (result != 'ok') {
      throw ImportException(ErrorCodes.importCorrupt, detail: 'quick_check: $result');
    }
  }

  /// Stores a gzip snapshot of [local] and keeps only the newest
  /// [kSafetyCopiesKept]. Returns its id.
  Future<String> _writeSafetyCopy(Map<String, List<RowMap>> local, String reason) async {
    final now = _stamper.nowMs();
    final id = Ids.v4();
    final snapshot = SnapshotCodec.build(
      tables: local,
      appVersion: '',
      snapshotId: id,
      deviceId: _stamper.deviceId,
      deviceName: await _deviceName(),
      createdAtMs: now,
    );
    await _db.into(_db.safetySnapshots).insert(SafetySnapshotsCompanion.insert(
          id: id,
          createdAt: now,
          reason: reason,
          bytes: Uint8List.fromList(SnapshotCodec.encode(snapshot)),
        ));
    await _db.customUpdate(
      'DELETE FROM safety_snapshots WHERE id NOT IN '
      '(SELECT id FROM safety_snapshots ORDER BY created_at DESC, rowid DESC '
      'LIMIT $kSafetyCopiesKept)',
      updates: {_db.safetySnapshots},
      updateKind: UpdateKind.delete,
    );
    return id;
  }

  static String _summaryJson(ChangeSummary s) => jsonEncode(<String, Object?>{
        for (final e in s.entities.entries)
          e.key.name: <String, int>{
            'added': e.value.added,
            'updated': e.value.updated,
            'deleted': e.value.deleted,
            'keptLocal': e.value.keptLocal,
          },
        'rows': s.winners.length,
      });

  /// Raw statements do not notify drift streams; tell them every synced
  /// table may have changed.
  void _notifySyncedTables() {
    _db.notifyUpdates({
      for (final t in _db.allTables)
        if (kSyncedTables.contains(t.actualTableName)) TableUpdate.onTable(t, kind: UpdateKind.update),
    });
  }
}

class _Col {
  const _Col({required this.name, required this.type, required this.notNull, required this.hasDefault});

  final String name;
  final String type;
  final bool notNull;
  final bool hasDefault;
}

class _TrialRollback implements Exception {
  const _TrialRollback();
}
