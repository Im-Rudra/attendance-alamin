// Schema v2 data helpers (teacher feedback items 1-3): the default place,
// receipt (slip) numbers and the pre-migration safety copy. Raw SQL only, so
// the same code runs inside the v1 -> v2 migration (before the typed tables
// match the file), after a backup import / restore and in repositories.
//
// None of these writes touch the sync columns: the default place is seeded
// with fixed stamps (created_at = updated_at = 0, device `seed`) so two
// devices that migrate separately hold the identical row, and receipt
// numbers are derived data filled into existing rows.

import 'dart:convert';
import 'dart:typed_data';

import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/domain/models/receipt_no.dart';
import 'package:attendance_alamin/domain/sync/snapshot_codec.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';
import 'package:drift/drift.dart' hide Batch;

/// `device_id` of rows the app seeds itself (the default place).
const String kSeedDeviceId = 'seed';

/// Name of the default place when the centre name setting is empty.
const String kDefaultPlaceNameBn = 'কোচিং সেন্টার';
const String kDefaultPlaceNameEn = 'Coaching centre';

/// Safety-copy reason written before a schema migration.
const String kSafetyReasonMigration = 'migration';

/// `local_meta` key of the highest receipt sequence given out in [year] on
/// this device (survives a restore of an older backup, so a number is never
/// given out twice).
String receiptSeqMetaKey(int year) => 'receipt_seq:$year';

// ------------------------------------------------------------------ settings

Future<String?> _settingText(GeneratedDatabase db, String table, String keyCol,
    String valueCol, String key, {bool synced = false}) async {
  final rows = await db.customSelect(
    'SELECT "$valueCol" AS v FROM "$table" WHERE "$keyCol" = ?'
    '${synced ? ' AND deleted_at IS NULL' : ''}',
    variables: [Variable.withString(key)],
  ).get();
  if (rows.isEmpty) return null;
  final Object? raw = rows.first.data['v'];
  if (raw is! String) return null;
  try {
    final Object? v = jsonDecode(raw);
    return v is String ? v : null;
  } on FormatException {
    return null;
  }
}

/// A synced string setting as stored (JSON text) in `settings`, or null.
Future<String?> _syncedString(GeneratedDatabase db, SettingKey<String> key) =>
    _settingText(db, 'settings', 'id', 'value', key.id, synced: true);

/// The centre settings (name, phone, address); blank values are null.
Future<({String? name, String? phone, String? address})> readCenterSettings(
    GeneratedDatabase db) async {
  String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
  return (
    name: clean(await _syncedString(db, SettingKeys.centerName)),
    phone: clean(await _syncedString(db, SettingKeys.centerPhone)),
    address: clean(await _syncedString(db, SettingKeys.centerAddress)),
  );
}

/// The default place's fallback name in the device language.
Future<String> fallbackPlaceName(GeneratedDatabase db) async {
  final String? locale = await _settingText(
      db, 'local_meta', 'meta_key', 'meta_value', SettingKeys.locale.id);
  return locale == 'en' ? kDefaultPlaceNameEn : kDefaultPlaceNameBn;
}

// ------------------------------------------------------------------ default place

/// Makes sure the default place row exists and is live: inserts it from the
/// centre settings (name falls back to [fallbackPlaceName]) when missing,
/// revives it when it was tombstoned or archived. Idempotent.
Future<void> ensureDefaultPlace(GeneratedDatabase db) async {
  final rows = await db.customSelect(
    'SELECT deleted_at, archived_at FROM places WHERE id = ?',
    variables: [Variable.withString(kDefaultPlaceId)],
  ).get();
  if (rows.isNotEmpty) {
    final Map<String, Object?> r = rows.first.data;
    if (r['deleted_at'] != null || r['archived_at'] != null) {
      await db.customStatement(
        'UPDATE places SET deleted_at = NULL, archived_at = NULL WHERE id = ?',
        [kDefaultPlaceId],
      );
    }
    return;
  }
  final center = await readCenterSettings(db);
  await db.customStatement(
    'INSERT OR IGNORE INTO places '
    '(id, created_at, updated_at, deleted_at, device_id, rev, name, phone, address, sort_order, archived_at) '
    'VALUES (?, 0, 0, NULL, ?, 1, ?, ?, ?, 0, NULL)',
    [
      kDefaultPlaceId,
      kSeedDeviceId,
      center.name ?? await fallbackPlaceName(db),
      center.phone,
      center.address,
    ],
  );
}

// ------------------------------------------------------------------ receipt numbers

Future<int> _maxSeqInRows(GeneratedDatabase db, int year) async {
  final row = await db.customSelect(
    'SELECT MAX(CAST(substr(receipt_no, 6) AS INTEGER)) AS m FROM payments '
    'WHERE receipt_no LIKE ?',
    variables: [Variable.withString('$year-%')],
  ).getSingle();
  final Object? m = row.data['m'];
  return m is int ? m : 0;
}

Future<int> _metaSeq(GeneratedDatabase db, int year) async {
  final rows = await db.customSelect(
    'SELECT meta_value AS v FROM local_meta WHERE meta_key = ?',
    variables: [Variable.withString(receiptSeqMetaKey(year))],
  ).get();
  if (rows.isEmpty) return 0;
  return int.tryParse('${rows.first.data['v']}') ?? 0;
}

Future<void> _putMetaSeq(GeneratedDatabase db, int year, int seq) =>
    db.customStatement(
      'INSERT INTO local_meta (meta_key, meta_value) VALUES (?, ?) '
      'ON CONFLICT(meta_key) DO UPDATE SET meta_value = excluded.meta_value',
      [receiptSeqMetaKey(year), '$seq'],
    );

/// The last sequence given out in [year]: the highest number in `payments`
/// (tombstoned rows included, so deleted receipts keep their numbers) or the
/// device's high-water mark, whichever is larger.
Future<int> lastReceiptSeq(GeneratedDatabase db, int year) async {
  final int a = await _maxSeqInRows(db, year);
  final int b = await _metaSeq(db, year);
  return a > b ? a : b;
}

/// Gives out the next number of the year of [paidOn] and records it as the
/// high-water mark. Call inside the transaction that writes the receipt
/// (drift runs transactions one at a time, so two saves never share one).
Future<String> allocateReceiptNo(GeneratedDatabase db, LocalDate paidOn) async {
  final int year = paidOn.year;
  final int seq = await lastReceiptSeq(db, year) + 1;
  await _putMetaSeq(db, year, seq);
  return ReceiptNo.format(year, seq);
}

/// Numbers every live, non-waiver receipt that has no number yet, in payment
/// date order (then recording time, then receipt id), continuing each year's
/// sequence. Writes the number on every non-waiver row of the receipt
/// (tombstoned ones included). Returns how many receipts were numbered.
/// Idempotent; sync columns are not touched.
Future<int> backfillReceiptNumbers(GeneratedDatabase db) async {
  final rows = await db.customSelect(
    'SELECT receipt_id, MIN(paid_on) AS d, MIN(created_at) AS c FROM payments '
    'WHERE waived = 0 AND receipt_no IS NULL AND deleted_at IS NULL '
    'GROUP BY receipt_id ORDER BY d, c, receipt_id',
  ).get();
  if (rows.isEmpty) return 0;
  final Map<int, int> next = <int, int>{};
  for (final r in rows) {
    final String receiptId = r.data['receipt_id']! as String;
    final LocalDate? date = LocalDate.tryParse('${r.data['d']}');
    final int year = date?.year ?? 1970;
    final int seq = (next[year] ??= await lastReceiptSeq(db, year)) + 1;
    next[year] = seq;
    await db.customStatement(
      'UPDATE payments SET receipt_no = ? '
      'WHERE receipt_id = ? AND waived = 0 AND receipt_no IS NULL',
      [ReceiptNo.format(year, seq), receiptId],
    );
  }
  for (final MapEntry<int, int> e in next.entries) {
    await _putMetaSeq(db, e.key, e.value);
  }
  return rows.length;
}

/// What schema v2 expects after rows were written behind the repositories'
/// back (backup import / restore, possibly of a v1 file): the default place
/// exists and every receipt has a number.
Future<void> ensureSchemaV2Invariants(GeneratedDatabase db) async {
  await ensureDefaultPlace(db);
  await backfillReceiptNumbers(db);
}

// ------------------------------------------------------------------ safety copy

/// Stores a gzip snapshot of every synced table that exists right now (the
/// old schema's rows, tombstones included) in `safety_snapshots` with reason
/// [kSafetyReasonMigration], so the teacher can go back from Settings ›
/// Backup if a migration ever loses something. Returns its id.
Future<String> writeMigrationSafetyCopy(AppDatabase db,
    {required int fromVersion, Clock clock = const SystemClock()}) async {
  final Set<String> present = <String>{
    for (final r in await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get())
      '${r.data['name']}',
  };
  final Map<String, List<RowMap>> tables = <String, List<RowMap>>{};
  for (final String t in kSyncedTables) {
    if (!present.contains(t)) continue;
    final Set<String> blobs = kBlobColumns[t] ?? const <String>{};
    final rows = await db.customSelect('SELECT * FROM "$t"').get();
    tables[t] = <RowMap>[
      for (final r in rows)
        <String, Object?>{
          for (final e in r.data.entries)
            e.key: (blobs.contains(e.key) && e.value is List<int>)
                ? base64Encode(e.value as List<int>)
                : e.value,
        },
    ];
  }
  final meta = await db.customSelect(
    'SELECT meta_value AS v FROM local_meta WHERE meta_key = ?',
    variables: [Variable.withString('device_id')],
  ).get();
  final String deviceId = meta.isEmpty ? '' : '${meta.first.data['v']}';
  final int now = clock.nowUtc().millisecondsSinceEpoch;
  final String id = Ids.v4();
  final snapshot = SnapshotCodec.build(
    tables: tables,
    appVersion: 'schema-v$fromVersion',
    snapshotId: id,
    deviceId: deviceId,
    deviceName: '',
    createdAtMs: now,
  );
  await db.customStatement(
    'INSERT INTO safety_snapshots (id, created_at, reason, bytes) VALUES (?, ?, ?, ?)',
    [id, now, kSafetyReasonMigration, Uint8List.fromList(SnapshotCodec.encode(snapshot))],
  );
  return id;
}
