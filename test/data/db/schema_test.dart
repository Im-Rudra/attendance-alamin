import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/connection/storage_persist.dart';
import 'package:attendance_alamin/data/db/connection/web_storage_report.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_fixtures.dart';

const _localTables = ['local_meta', 'safety_snapshots', 'import_log'];

const _expectedIndexes = {
  'idx_subjects_deleted_sort': 'subjects',
  'idx_batches_subject': 'batches',
  'idx_batch_slots_weekday': 'batch_slots',
  'idx_batch_slots_batch': 'batch_slots',
  'idx_schedule_exceptions_original_date': 'schedule_exceptions',
  'idx_schedule_exceptions_new_date': 'schedule_exceptions',
  'idx_schedule_exceptions_batch': 'schedule_exceptions',
  'idx_batch_fees_batch_month': 'batch_fees',
  'idx_students_status': 'students',
  'idx_students_name': 'students',
  'idx_enrollments_student': 'enrollments',
  'idx_enrollments_batch': 'enrollments',
  'idx_enrollment_fees_enrollment_month': 'enrollment_fees',
  'idx_attendance_sessions_occ': 'attendance_sessions',
  'idx_attendance_sessions_batch_date': 'attendance_sessions',
  'idx_attendance_sessions_date': 'attendance_sessions',
  'idx_attendance_records_session': 'attendance_records',
  'idx_attendance_records_student_batch_date': 'attendance_records',
  'idx_payments_enrollment_month': 'payments',
  'idx_payments_paid_on': 'payments',
  'idx_payments_student': 'payments',
  'idx_payments_receipt': 'payments',
  'idx_other_income_paid_on': 'other_income',
  'idx_other_income_student': 'other_income',
};

void main() {
  test('schemaVersion equals kCurrentSchemaVersion', () {
    final db = openMemoryDb();
    expect(db.schemaVersion, kCurrentSchemaVersion);
  });

  test('drift tables are exactly kSyncedTables + local tables', () {
    final db = openMemoryDb();
    final names = db.allTables.map((t) => t.actualTableName).toList();
    expect(names, hasLength(18));
    expect(names.toSet(), {...kSyncedTables, ..._localTables});
  });

  test('every table exists in sqlite_master', () async {
    final db = openMemoryDb();
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll([...kSyncedTables, ..._localTables]));
  });

  Future<Map<String, Map<String, Object?>>> columns(
      AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return {for (final r in rows) r.read<String>('name'): r.data};
  }

  test('synced tables carry the sync columns with id as text primary key',
      () async {
    final db = openMemoryDb();
    for (final t in kSyncedTables) {
      final cols = await columns(db, t);
      expect(cols.keys, containsAll(kSyncColumns), reason: t);
      expect(cols['id']!['pk'], 1, reason: t);
      expect(cols['id']!['type'], 'TEXT', reason: t);
      expect(cols['id']!['notnull'], 1, reason: t);
      for (final c in ['created_at', 'updated_at', 'rev']) {
        expect(cols[c]!['type'], 'INTEGER', reason: '$t.$c');
        expect(cols[c]!['notnull'], 1, reason: '$t.$c');
      }
      expect(cols['deleted_at']!['notnull'], 0, reason: t);
      expect(cols['device_id']!['notnull'], 1, reason: t);
      // Only `id` is part of the primary key.
      expect(cols.values.where((c) => c['pk'] != 0).length, 1, reason: t);
    }
  });

  test('local tables are not synced and have no sync columns', () async {
    final db = openMemoryDb();
    for (final t in _localTables) {
      expect(kSyncedTables, isNot(contains(t)));
      final cols = await columns(db, t);
      expect(cols.keys, isNot(contains('device_id')), reason: t);
      expect(cols.keys, isNot(contains('rev')), reason: t);
    }
    expect((await columns(db, 'local_meta')).keys,
        containsAll(['meta_key', 'meta_value']));
  });

  test('plan section 1 amendments are in the schema', () async {
    final db = openMemoryDb();
    final enrollments = await columns(db, 'enrollments');
    expect(enrollments.keys, containsAll(['join_date', 'end_date']));
    expect(enrollments['join_date']!['notnull'], 1);
    expect(enrollments['end_date']!['notnull'], 0);
    expect(enrollments.keys, isNot(contains('fee_override')));
    final fees = await columns(db, 'enrollment_fees');
    expect(fees.keys,
        containsAll(['enrollment_id', 'effective_month', 'amount']));
    expect(fees['amount']!['notnull'], 0);
    final payments = await columns(db, 'payments');
    expect(payments['receipt_id']!['notnull'], 1);
    final other = await columns(db, 'other_income');
    expect(other.keys, containsAll(
        ['student_id', 'label', 'amount', 'paid_on', 'method', 'note']));
    final settings = await columns(db, 'settings');
    expect(settings.keys, contains('value'));
    for (final e in kBlobColumns.entries) {
      final cols = await columns(db, e.key);
      for (final c in e.value) {
        expect(cols[c]!['type'], 'BLOB', reason: '${e.key}.$c');
      }
    }
  });

  test('all indexes exist on the right tables', () async {
    final db = openMemoryDb();
    final rows = await db
        .customSelect(
            "SELECT name, tbl_name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'idx_%'")
        .get();
    final found = {
      for (final r in rows) r.read<String>('name'): r.read<String>('tbl_name')
    };
    expect(found, _expectedIndexes);
  });

  test('index columns follow Arch 3.2', () async {
    final db = openMemoryDb();
    Future<List<String>> indexCols(String index) async {
      final rows = await db.customSelect('PRAGMA index_info($index)').get();
      return rows.map((r) => r.read<String>('name')).toList();
    }

    expect(await indexCols('idx_subjects_deleted_sort'),
        ['deleted_at', 'sort_order']);
    expect(await indexCols('idx_attendance_sessions_batch_date'),
        ['batch_id', 'date']);
    expect(await indexCols('idx_attendance_records_student_batch_date'),
        ['student_id', 'batch_id', 'date']);
    expect(await indexCols('idx_payments_enrollment_month'),
        ['enrollment_id', 'billing_month']);
    expect(await indexCols('idx_batch_fees_batch_month'),
        ['batch_id', 'effective_month']);
  });

  test('foreign keys are on after open and the DB passes integrity checks',
      () async {
    final db = openMemoryDb();
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);
    final qc = await db.customSelect('PRAGMA quick_check').getSingle();
    expect(qc.data.values.first, 'ok');
    final fkCheck = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fkCheck, isEmpty);
  });

  test('declared foreign keys (no ON DELETE CASCADE)', () async {
    final db = openMemoryDb();
    Future<Map<String, String>> fks(String table) async {
      final rows =
          await db.customSelect('PRAGMA foreign_key_list($table)').get();
      for (final r in rows) {
        expect(r.read<String>('on_delete'), 'NO ACTION', reason: table);
      }
      return {
        for (final r in rows) r.read<String>('from'): r.read<String>('table')
      };
    }

    expect(await fks('batches'), {'subject_id': 'subjects'});
    expect(await fks('batch_slots'), {'batch_id': 'batches'});
    expect(await fks('schedule_exceptions'),
        {'batch_id': 'batches', 'slot_id': 'batch_slots'});
    expect(await fks('batch_fees'), {'batch_id': 'batches'});
    expect(await fks('student_photos'), {'id': 'students'});
    expect(await fks('enrollments'),
        {'student_id': 'students', 'batch_id': 'batches'});
    expect(await fks('enrollment_fees'), {'enrollment_id': 'enrollments'});
    expect(await fks('attendance_sessions'), {
      'batch_id': 'batches',
      'slot_id': 'batch_slots',
      'exception_id': 'schedule_exceptions',
    });
    expect(await fks('attendance_records'), {
      'session_id': 'attendance_sessions',
      'batch_id': 'batches',
      'student_id': 'students',
    });
    expect(await fks('payments'), {
      'student_id': 'students',
      'enrollment_id': 'enrollments',
      'batch_id': 'batches',
    });
    expect(await fks('other_income'), {'student_id': 'students'});
  });

  group('web storage report', () {
    test('inMemory is not persistent, IndexedDB / OPFS are', () {
      expect(const WebStorageInfo('inMemory', ['indexedDb']).persistent,
          isFalse);
      for (final impl in [
        'sharedIndexedDb',
        'unsafeIndexedDb',
        'opfsShared',
        'opfsLocks'
      ]) {
        expect(WebStorageInfo(impl, const []).persistent, isTrue, reason: impl);
      }
    });

    test('native: report stays null and persist request is a no-op',
        () async {
      expect(webStorageReport.value, isNull);
      await requestPersistentStorage();
      expect(webStorageReport.value, isNull);
    });
  });
}
