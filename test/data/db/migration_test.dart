// Schema v1 -> v2 (teacher feedback items 1-3) from a REAL v1 database file:
// the exact CREATE statements v1 ran (drift_schemas/drift_schema_v1.json,
// see schema_v1_sql.dart), v1 rows written with raw SQL, then the app opens
// the file and migrates it.

import 'dart:io';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/migrations.dart';
import 'package:attendance_alamin/data/db/schema_v2.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/domain/sync/snapshot_codec.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';
import 'package:drift/drift.dart' hide Batch, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'schema_v1_sql.dart';

const int _t = 1795165200000; // 2026-11-20 09:00 UTC

/// One v1 row: table + column values (sync columns included).
typedef _Row = (String, Map<String, Object?>);

Map<String, Object?> _sync(String id, {int at = _t, int? deletedAt, int rev = 1}) => <String, Object?>{
      'id': id,
      'created_at': at,
      'updated_at': at,
      'deleted_at': deletedAt,
      'device_id': 'dev-old',
      'rev': rev,
    };

Map<String, Object?> _setting(String key, String jsonValue) =>
    <String, Object?>{..._sync(key), 'value': jsonValue};

Map<String, Object?> _pay(String id, String receipt, String enrollment, int month, int amount, String paidOn,
        {int at = _t, int? deletedAt, bool waived = false}) =>
    <String, Object?>{
      ..._sync(id, at: at, deletedAt: deletedAt),
      'receipt_id': receipt,
      'student_id': enrollment == 'e1' ? 'st1' : 'st2',
      'enrollment_id': enrollment,
      'batch_id': enrollment == 'e1' ? 'b1' : 'b2',
      'billing_month': month,
      'amount': amount,
      'paid_on': paidOn,
      'method': waived ? 'other' : 'cash',
      'note': null,
      'waived': waived ? 1 : 0,
    };

/// The teacher's v1 data: two batches (one finished), two students, five
/// receipts (one deleted, one edited), a waiver and other income.
List<_Row> v1Rows({bool withCenter = true}) => <_Row>[
      if (withCenter) ...<_Row>[
        ('settings', _setting('center_name', '"আলামিন কোচিং"')),
        ('settings', _setting('center_phone', '"01712345678"')),
        ('settings', _setting('center_address', '"Mirpur 10"')),
      ],
      ('subjects', <String, Object?>{..._sync('s1'), 'name': 'Physics', 'sort_order': 0, 'archived_at': null, 'notes': null}),
      ('batches', <String, Object?>{
        ..._sync('b1'),
        'subject_id': 's1',
        'name': 'HSC A',
        'billing_type': 'prepaid',
        'reminder_lead_min': 30,
        'archived_at': null,
        'sort_order': 0,
        'notes': 'evening',
      }),
      ('batches', <String, Object?>{
        ..._sync('b2'),
        'subject_id': 's1',
        'name': 'Old batch',
        'billing_type': 'postpaid',
        'reminder_lead_min': null,
        'archived_at': _t,
        'sort_order': 1,
        'notes': null,
      }),
      ('batch_fees', <String, Object?>{..._sync('f1'), 'batch_id': 'b1', 'effective_month': 202501, 'amount': 1000}),
      for (final String s in <String>['st1', 'st2'])
        ('students', <String, Object?>{
          ..._sync(s),
          'name': s == 'st1' ? 'Rahim' : 'Karim',
          'roll': null,
          'phone': null,
          'guardian_name': null,
          'guardian_phone': null,
          'admission_date': '2025-01-01',
          'status': 'active',
          'left_date': null,
          'notes': null,
          'has_photo': 0,
        }),
      ('enrollments', <String, Object?>{
        ..._sync('e1'),
        'student_id': 'st1',
        'batch_id': 'b1',
        'join_date': '2025-01-01',
        'start_month': 202501,
        'end_month': null,
        'end_date': null,
        'notes': null,
      }),
      ('enrollments', <String, Object?>{
        ..._sync('e2'),
        'student_id': 'st2',
        'batch_id': 'b2',
        'join_date': '2025-01-01',
        'start_month': 202501,
        'end_month': 202512,
        'end_date': null,
        'notes': null,
      }),
      // Inserted out of date order on purpose.
      ('payments', _pay('p-c', 'R-C', 'e1', 202602, 1000, '2026-01-05', at: _t + 200)),
      ('payments', _pay('p-b', 'R-B', 'e1', 202601, 1000, '2026-01-05', at: _t + 100)),
      ('payments', _pay('p-a1', 'R-A', 'e2', 202511, 800, '2025-12-30')),
      ('payments', _pay('p-a2', 'R-A', 'e2', 202512, 800, '2025-12-30')),
      ('payments', _pay('p-d', 'R-D', 'e1', 202512, 500, '2026-01-02', deletedAt: _t + 5)),
      // R-E was edited: one row replaced (tombstoned), one live.
      ('payments', _pay('p-e1', 'R-E', 'e1', 202511, 300, '2026-01-01', deletedAt: _t + 9)),
      ('payments', _pay('p-e2', 'R-E', 'e1', 202511, 400, '2026-01-01')),
      ('payments', _pay('w1', 'w1', 'e1', 202510, 0, '2026-01-03', waived: true)),
      ('other_income', <String, Object?>{
        ..._sync('o1'),
        'student_id': null,
        'label': 'Exam fee',
        'amount': 200,
        'paid_on': '2026-01-04',
        'method': 'cash',
        'note': null,
      }),
    ];

/// Opens [file] as the app does. On the first open the file is created with
/// the exact v1 schema and [rows] (plus [extraSql]), `user_version = 1`, so
/// drift runs the v1 -> v2 migration right away.
AppDatabase openV1File(File file, List<_Row> rows,
    {List<String> extraSql = const <String>[], Map<String, String> meta = const <String, String>{}}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase(file, setup: (raw) {
    if (raw.userVersion != 0) return;
    for (final String sql in kSchemaV1Sql) {
      raw.execute(sql);
    }
    for (final (String table, Map<String, Object?> row) in rows) {
      final String cols = row.keys.map((String k) => '"$k"').join(', ');
      final String params = List<String>.filled(row.length, '?').join(', ');
      raw.execute('INSERT INTO "$table" ($cols) VALUES ($params)', row.values.toList());
    }
    for (final MapEntry<String, String> e in meta.entries) {
      raw.execute('INSERT INTO local_meta (meta_key, meta_value) VALUES (?, ?)', <Object?>[e.key, e.value]);
    }
    for (final String sql in extraSql) {
      raw.execute(sql);
    }
    raw.userVersion = 1;
  }));
}

Future<File> tempFile(String tag) async {
  final Directory dir = await Directory.systemTemp.createTemp('w2_migration_$tag');
  addTearDown(() => dir.delete(recursive: true));
  return File('${dir.path}/attendance_alamin.sqlite');
}

Future<Map<String, Map<String, Object?>>> rowsById(AppDatabase db, String table) async {
  final rows = await db.customSelect('SELECT * FROM "$table"').get();
  return <String, Map<String, Object?>>{for (final r in rows) r.data['id']! as String: r.data};
}

Future<Map<String, String?>> receiptNos(AppDatabase db) async => <String, String?>{
      for (final r in await db.customSelect('SELECT id, receipt_no FROM payments').get())
        r.data['id']! as String: r.data['receipt_no'] as String?,
    };

void main() {
  group('v1 -> v2 from a real v1 file', () {
    test('every v1 row and column survives unchanged', () async {
      final File file = await tempFile('lossless');
      final List<_Row> rows = v1Rows();
      final AppDatabase db = openV1File(file, rows, meta: <String, String>{'device_id': 'dev-old'});
      addTearDown(db.close);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, 2);
      expect(kCurrentSchemaVersion, 2);

      final Map<String, Map<String, Map<String, Object?>>> after = <String, Map<String, Map<String, Object?>>>{};
      for (final (String table, Map<String, Object?> row) in rows) {
        final Map<String, Map<String, Object?>> byId = after[table] ??= await rowsById(db, table);
        final Map<String, Object?>? now = byId[row['id']];
        expect(now, isNotNull, reason: '$table/${row['id']}');
        for (final MapEntry<String, Object?> e in row.entries) {
          expect(now![e.key], e.value, reason: '$table/${row['id']}.${e.key}');
        }
      }
      // Row counts are unchanged too (nothing added to v1 tables).
      for (final String table in <String>{for (final (String t, _) in rows) t}) {
        expect(after[table]!.length, rows.where((_Row r) => r.$1 == table).length, reason: table);
      }
    });

    test('new columns get their defaults; the default place comes from the centre settings', () async {
      final AppDatabase db = openV1File(await tempFile('defaults'), v1Rows());
      addTearDown(db.close);

      final Map<String, Map<String, Object?>> batches = await rowsById(db, 'batches');
      for (final Map<String, Object?> b in batches.values) {
        expect(b['kind'], 'batch');
        expect(b['place_id'], kDefaultPlaceId);
      }
      expect((await rowsById(db, 'other_income'))['o1']!['place_id'], isNull);

      final Map<String, Map<String, Object?>> places = await rowsById(db, 'places');
      expect(places.keys, <String>[kDefaultPlaceId]);
      final Map<String, Object?> p = places[kDefaultPlaceId]!;
      expect(p['name'], 'আলামিন কোচিং');
      expect(p['phone'], '01712345678');
      expect(p['address'], 'Mirpur 10');
      expect(p['archived_at'], isNull);
      expect(p['deleted_at'], isNull);
      expect((p['created_at'], p['updated_at'], p['device_id'], p['rev']), (0, 0, kSeedDeviceId, 1));
    });

    test('existing receipts are numbered per year in payment-date order', () async {
      final AppDatabase db = openV1File(await tempFile('numbers'), v1Rows());
      addTearDown(db.close);

      expect(await receiptNos(db), <String, String?>{
        'p-a1': '2025-0001',
        'p-a2': '2025-0001',
        'p-e1': '2026-0001', // the replaced row of an edited receipt keeps the receipt's number
        'p-e2': '2026-0001',
        'p-b': '2026-0002', // same day as R-C, recorded first
        'p-c': '2026-0003',
        'p-d': null, // deleted receipt
        'w1': null, // waiver, not a receipt
      });
      // The high-water marks continue from there.
      expect(await lastReceiptSeq(db, 2025), 1);
      expect(await lastReceiptSeq(db, 2026), 3);
      expect(await allocateReceiptNo(db, const LocalDate(2026, 3, 1)), '2026-0004');
    });

    test('a safety copy of the v1 rows is written first', () async {
      final AppDatabase db =
          openV1File(await tempFile('safety'), v1Rows(), meta: <String, String>{'device_id': 'dev-old'});
      addTearDown(db.close);

      final rows = await db.select(db.safetySnapshots).get();
      expect(rows, hasLength(1));
      expect(rows.single.reason, kSafetyReasonMigration);
      final snap = SnapshotCodec.decode(rows.single.bytes);
      expect(snap.deviceId, 'dev-old');
      expect(snap.tables.containsKey('places'), isFalse);
      expect(snap.tables['payments'], hasLength(8));
      expect(snap.tables['payments']!.first.containsKey('receipt_no'), isFalse, reason: 'v1 columns only');
    });

    test('reopening a migrated file does not migrate again', () async {
      final File file = await tempFile('reopen');
      final AppDatabase first = openV1File(file, v1Rows());
      final Map<String, String?> numbers = await receiptNos(first);
      await first.close();

      final AppDatabase second = openV1File(file, const <_Row>[]);
      addTearDown(second.close);
      expect(await receiptNos(second), numbers);
      expect(await second.select(second.safetySnapshots).get(), hasLength(1));
      expect(await second.select(second.places).get(), hasLength(1));
    });

    test('running the v2 step again changes nothing (idempotent)', () async {
      final AppDatabase db = openV1File(await tempFile('again'), v1Rows());
      addTearDown(db.close);
      final Map<String, String?> numbers = await receiptNos(db);
      final Map<String, Map<String, Object?>> places = await rowsById(db, 'places');

      await migrateToV2(db, db.createMigrator(), from: 1);

      expect(await receiptNos(db), numbers);
      expect(await rowsById(db, 'places'), places);
    });

    test('a half-done migration (places table and kind column already there) finishes', () async {
      final AppDatabase db = openV1File(await tempFile('half'), v1Rows(), extraSql: <String>[
        'CREATE TABLE IF NOT EXISTS "places" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, '
            '"updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "device_id" TEXT NOT NULL, '
            '"rev" INTEGER NOT NULL DEFAULT 1, "name" TEXT NOT NULL, "phone" TEXT NULL, "address" TEXT NULL, '
            '"sort_order" INTEGER NOT NULL DEFAULT 0, "archived_at" INTEGER NULL, PRIMARY KEY ("id"));',
        "ALTER TABLE batches ADD COLUMN \"kind\" TEXT NOT NULL DEFAULT 'batch';",
      ]);
      addTearDown(db.close);

      expect((await rowsById(db, 'batches'))['b1']!['place_id'], kDefaultPlaceId);
      expect(await rowsById(db, 'places'), hasLength(1));
      expect((await receiptNos(db))['p-c'], '2026-0003');
    });

    test('without centre settings the default place is named in the device language', () async {
      final AppDatabase bn = openV1File(await tempFile('bn'), v1Rows(withCenter: false));
      addTearDown(bn.close);
      final Map<String, Object?> p = (await rowsById(bn, 'places'))[kDefaultPlaceId]!;
      expect(p['name'], kDefaultPlaceNameBn);
      expect(p['phone'], isNull);

      final AppDatabase en = openV1File(await tempFile('en'), v1Rows(withCenter: false),
          meta: <String, String>{'locale': '"en"'});
      addTearDown(en.close);
      expect((await rowsById(en, 'places'))[kDefaultPlaceId]!['name'], kDefaultPlaceNameEn);
    });

    test('foreign keys and integrity hold after the migration', () async {
      final AppDatabase db = openV1File(await tempFile('fk'), v1Rows());
      addTearDown(db.close);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      final qc = await db.customSelect('PRAGMA integrity_check').getSingle();
      expect(qc.data.values.first, 'ok');
    });
  });

  group('fresh database (onCreate)', () {
    test('has the default place and the v2 columns', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final AppDatabase db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final places = await db.select(db.places).get();
      expect(places.single.id, kDefaultPlaceId);
      expect(places.single.name, kDefaultPlaceNameBn);
      final cols = await db.customSelect('PRAGMA table_info(batches)').get();
      final Map<String, Object?> placeCol = cols.firstWhere((r) => r.data['name'] == 'place_id').data;
      expect(placeCol['dflt_value'], "'$kDefaultPlaceId'", reason: 'Batches.placeId default must equal kDefaultPlaceId');
      expect(placeCol['notnull'], 1);
    });
  });
}
