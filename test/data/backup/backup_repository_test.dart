import 'dart:typed_data';

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/data/backup/backup_files.dart';
import 'package:attendance_alamin/data/backup/backup_providers.dart';
import 'package:attendance_alamin/data/backup/backup_repository.dart';
import 'package:attendance_alamin/data/backup/backup_repository_drift.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/drift/settings_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/domain/sync/snapshot_codec.dart';
import 'package:attendance_alamin/domain/sync/sync_diff.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';
import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-20 09:00 UTC (15:00 in Dhaka).
const t0 = 1795165200000;
const photo = <int>[0xff, 0xd8, 0x00, 0x01, 0x7f, 0xff, 0xd9];

class _MutableClock implements Clock {
  _MutableClock(this.ms);
  int ms;
  @override
  DateTime nowUtc() => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

/// One device: its own in-memory database and repositories.
class _Device {
  _Device(this.id) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    clock = _MutableClock(t0);
    stamper = SyncStamper(clock: clock, deviceId: id);
    repo = DriftBackupRepository(db, stamper, CenterTime.dhaka);
    settings = DriftSettingsRepository(db, stamper);
  }

  final String id;
  late final AppDatabase db;
  late final _MutableClock clock;
  late final SyncStamper stamper;
  late final DriftBackupRepository repo;
  late final DriftSettingsRepository settings;

  /// Raw insert with sync columns (created = updated = [at]).
  Future<void> put(String table, String id, Map<String, Object?> cols,
      {int at = t0, int rev = 1, int? deletedAt, String? device}) async {
    final row = <String, Object?>{
      'id': id,
      'created_at': at,
      'updated_at': at,
      'deleted_at': deletedAt,
      'device_id': device ?? this.id,
      'rev': rev,
      ...cols,
    };
    final names = row.keys.map((k) => '"$k"').join(', ');
    final params = List.filled(row.length, '?').join(', ');
    await db.customStatement(
        'INSERT INTO "$table" ($names) VALUES ($params)', row.values.toList());
  }

  /// Raw edit of one row, stamped like a repository write at [at].
  Future<void> edit(String table, String id, Map<String, Object?> cols, {required int at}) async {
    final sets = [for (final k in cols.keys) '"$k" = ?', 'updated_at = ?', 'rev = rev + 1', 'device_id = ?'];
    await db.customStatement('UPDATE "$table" SET ${sets.join(', ')} WHERE id = ?',
        [...cols.values, at, this.id, id]);
  }

  Future<Map<String, List<Map<String, Object?>>>> dump() async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in kSyncedTables) {
      final rows = await db.customSelect('SELECT * FROM "$t" ORDER BY id').get();
      out[t] = [
        for (final r in rows)
          {
            for (final e in r.data.entries)
              e.key: e.value is Uint8List ? List<int>.of(e.value as Uint8List) : e.value,
          },
      ];
    }
    return out;
  }

  Future<Map<String, Object?>> row(String table, String id) async =>
      (await db.customSelect('SELECT * FROM "$table" WHERE id = ?', variables: [Variable(id)]).getSingle())
          .data;

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS c FROM "$table"').getSingle()).read<int>('c');

  /// One row in every synced table, plus a tombstoned subject.
  Future<void> seedAll() async {
    await put('subjects', 's1', {'name': 'Physics', 'sort_order': 1, 'archived_at': null, 'notes': 'n'});
    await put('subjects', 's2', {'name': 'Old', 'sort_order': 2, 'archived_at': null, 'notes': null},
        deletedAt: t0 + 10, at: t0 + 10, rev: 2);
    await put('batches', 'b1', {
      'subject_id': 's1',
      'name': 'HSC A',
      'billing_type': 'prepaid',
      'reminder_lead_min': 30,
      'archived_at': null,
      'sort_order': 0,
      'notes': null,
    });
    await put('batch_slots', 'sl1', {
      'batch_id': 'b1',
      'weekday': 6,
      'start_min': 960,
      'end_min': 1020,
      'valid_from': '2026-11-01',
      'valid_to': null,
    });
    await put('schedule_exceptions', 'ex1', {
      'batch_id': 'b1',
      'kind': 'cancel',
      'slot_id': 'sl1',
      'original_date': '2026-11-28',
      'new_date': null,
      'new_start_min': null,
      'new_end_min': null,
      'note': 'Eid',
    });
    await put('batch_fees', 'f1', {'batch_id': 'b1', 'effective_month': 202611, 'amount': 1000});
    await put('students', 'st1', {
      'name': 'Rahim',
      'roll': '01',
      'phone': '01711111111',
      'guardian_name': null,
      'guardian_phone': null,
      'admission_date': '2026-11-02',
      'status': 'active',
      'left_date': null,
      'notes': null,
      'has_photo': 1,
    });
    await put('student_photos', 'st1', {'jpeg': Uint8List.fromList(photo)});
    await put('enrollments', 'e1', {
      'student_id': 'st1',
      'batch_id': 'b1',
      'join_date': '2026-11-02',
      'start_month': 202611,
      'end_month': null,
      'end_date': null,
      'notes': null,
    });
    await put('enrollment_fees', 'ef1', {'enrollment_id': 'e1', 'effective_month': 202611, 'amount': 800});
    await put('attendance_sessions', 'ses1', {
      'occ': 's.sl1.20261121',
      'batch_id': 'b1',
      'slot_id': 'sl1',
      'original_date': '2026-11-21',
      'exception_id': null,
      'date': '2026-11-21',
      'start_min': 960,
      'end_min': 1020,
      'note': null,
    });
    await put('attendance_records', 'rec1', {
      'session_id': 'ses1',
      'batch_id': 'b1',
      'student_id': 'st1',
      'date': '2026-11-21',
      'status': 'P',
    });
    await put('payments', 'pay1', {
      'receipt_id': 'rc1',
      'student_id': 'st1',
      'enrollment_id': 'e1',
      'batch_id': 'b1',
      'billing_month': 202611,
      'amount': 800,
      'paid_on': '2026-11-20',
      'method': 'cash',
      'note': null,
      'waived': 0,
    });
    await put('other_income', 'oi1', {
      'student_id': 'st1',
      'label': 'Exam fee',
      'amount': 200,
      'paid_on': '2026-11-20',
      'method': 'custom:উপায়',
      'note': null,
    });
    await settings.set(SettingKeys.centerName, 'আলামিন কোচিং');
  }

  /// Export the way the UI does: snapshot → bytes → decode.
  Future<Snapshot> exportFile() async {
    final s = await repo.buildSnapshot(appVersion: '1.0.0+7');
    return SnapshotCodec.decode(SnapshotCodec.encode(s));
  }

  Future<ApplyOutcome> importFile(Snapshot s) async => repo.apply(s, await repo.preview(s));
}

Future<List<SafetyCopyInfo>> copies(_Device d) => d.repo.watchSafetyCopies().first;

Matcher importError(String code) =>
    throwsA(isA<ImportException>().having((e) => e.code, 'code', code));

/// Rebuilds [s] with table rows changed by [edit] (valid checksum).
Snapshot rebuilt(Snapshot s, void Function(Map<String, List<RowMap>> tables) edit) {
  final tables = {
    for (final e in s.tables.entries) e.key: [for (final r in e.value) Map<String, Object?>.of(r)],
  };
  edit(tables);
  return SnapshotCodec.build(
    tables: tables,
    appVersion: s.appVersion,
    snapshotId: s.snapshotId,
    deviceId: s.deviceId,
    deviceName: s.deviceName,
    createdAtMs: s.createdAtMs,
  );
}

/// [s] as schema v1 wrote it: no places table, none of the v2 columns.
Snapshot asV1(Snapshot s) {
  final v2 = rebuilt(s, (tables) {
    tables.remove('places');
    for (final r in tables['batches'] ?? const <RowMap>[]) {
      r.remove('kind');
      r.remove('place_id');
    }
    for (final r in tables['payments'] ?? const <RowMap>[]) {
      r.remove('receipt_no');
    }
    for (final r in tables['other_income'] ?? const <RowMap>[]) {
      r.remove('place_id');
    }
  });
  return SnapshotCodec.decode(SnapshotCodec.encode(Snapshot(
    formatVersion: v2.formatVersion,
    schemaVersion: 1,
    appVersion: v2.appVersion,
    snapshotId: v2.snapshotId,
    deviceId: v2.deviceId,
    deviceName: v2.deviceName,
    createdAtMs: v2.createdAtMs,
    counts: v2.counts,
    sha256: v2.sha256,
    tables: v2.tables,
  )));
}

void main() {
  late _Device p; // phone
  late _Device w; // PC

  setUp(() {
    p = _Device('dev-P');
    w = _Device('dev-W');
  });

  group('export', () {
    test('includes every synced table, tombstones and base64 blobs; never device keys', () async {
      await p.seedAll();
      await p.settings.set(SettingKeys.locale, 'en');
      await p.settings.set(SettingKeys.deviceName, 'Phone');
      final s = await p.repo.buildSnapshot(appVersion: '1.0.0+7');
      expect(s.tables.keys, containsAll(kSyncedTables));
      expect(s.deviceId, 'dev-P');
      expect(s.deviceName, 'Phone');
      expect(s.createdAtMs, t0);
      expect(s.schemaVersion, kCurrentSchemaVersion);
      expect(s.tables['subjects']!.map((r) => r['id']), ['s1', 's2']);
      expect(s.counts['subjects'], 1); // live only
      expect(s.tables['student_photos']!.single['jpeg'], '/9gAAX//2Q==');
      expect(s.tables['settings']!.map((r) => r['id']), ['center_name']);
      for (final rows in s.tables.values) {
        for (final r in rows) {
          expect(r.keys, isNot(contains('locale')));
        }
      }
      // buildSnapshot does not record lastExportAt (the caller does after save).
      expect(await p.settings.get(SettingKeys.lastExportAt), isNull);
    });

    test('backupFileName uses center wall-clock time', () {
      // 2026-11-20 15:30 UTC = 21:30 in Dhaka.
      expect(backupFileName(t0 + 23400000, CenterTime.dhaka), 'coaching-backup-2026-11-20-2130.ambackup');
      // 18:05 UTC = 00:05 next day in Dhaka.
      expect(backupFileName(t0 + 32700000, CenterTime.dhaka), 'coaching-backup-2026-11-21-0005.ambackup');
    });
  });

  group('import into a fresh database', () {
    test('reproduces every table exactly (tombstones and blobs included)', () async {
      await p.seedAll();
      final file = await p.exportFile();

      final summary = await w.repo.preview(file);
      expect(summary.entities[SummaryEntity.subjects]!.added, 1); // tombstone s2 invisible
      expect(summary.entities[SummaryEntity.batches]!.added, 1);
      expect(summary.entities[SummaryEntity.schedule]!.added, 2);
      expect(summary.entities[SummaryEntity.students]!.added, 1);
      expect(summary.entities[SummaryEntity.enrollments]!.added, 1);
      expect(summary.entities[SummaryEntity.attendance]!.added, 1);
      expect(summary.entities[SummaryEntity.payments]!.added, 2); // receipt + other income
      expect(summary.entities[SummaryEntity.settings]!.added, 1);
      expect(await w.count('subjects'), 0, reason: 'preview never writes');

      final outcome = await w.repo.apply(file, summary);
      expect(outcome.applied, 15);
      expect(outcome.safetyCopyId, isNotEmpty);

      final dp = await p.dump();
      final dw = await w.dump();
      for (final t in kSyncedTables) {
        expect(dw[t], dp[t], reason: t);
        expect(dw[t], isNotEmpty, reason: t);
      }
      expect(await w.settings.get(SettingKeys.centerName), 'আলামিন কোচিং');
    });

    test('records import_log and last_import, and notifies streams', () async {
      await p.seedAll();
      final file = await p.exportFile();
      final seen = <int>[];
      final sub = w.db
          .customSelect('SELECT COUNT(*) AS c FROM students', readsFrom: {w.db.students})
          .watch()
          .listen((rows) => seen.add(rows.single.read<int>('c')));
      addTearDown(sub.cancel);
      await w.importFile(file);
      for (var i = 0; i < 100 && !seen.contains(1); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(seen, contains(1));
      final log = await w.db.select(w.db.importLog).getSingle();
      expect(log.snapshotId, file.snapshotId);
      expect(log.sourceDeviceId, 'dev-P');
      expect(log.summaryJson, contains('"students":{"added":1'));
      final meta = await (w.db.select(w.db.localMeta)
            ..where((t) => t.metaKey.equals(LocalMetaKeys.lastImport('dev-P'))))
          .getSingle();
      expect(meta.metaValue, '$t0');
    });
  });

  group('merge', () {
    test('importing the same file twice gives no changes and applies nothing', () async {
      await p.seedAll();
      final file = await p.exportFile();
      await w.importFile(file);
      final before = await w.dump();

      final again = await w.repo.preview(file);
      expect(again.isEmpty, isTrue);
      expect(again.totalChanges, 0);
      final outcome = await w.repo.apply(file, again);
      expect(outcome.applied, 0);
      expect(outcome.safetyCopyId, '');
      expect(await w.dump(), before);
      expect(await copies(w), hasLength(1));
      expect(await w.count('import_log'), 1);
    });

    test('a newer local edit is kept; new incoming rows are added', () async {
      await p.seedAll();
      await w.importFile(await p.exportFile());
      // W edits Rahim later than P does.
      await w.edit('students', 'st1', {'name': 'Rahim (PC)'}, at: t0 + 20000);
      await p.edit('students', 'st1', {'name': 'Rahim (phone)'}, at: t0 + 10000);
      await p.put('subjects', 's3', {'name': 'Chemistry', 'sort_order': 3, 'archived_at': null, 'notes': null},
          at: t0 + 10000);

      final file = await p.exportFile();
      final summary = await w.repo.preview(file);
      expect(summary.entities[SummaryEntity.students]!.keptLocal, 1);
      expect(summary.entities[SummaryEntity.students]!.updated, 0);
      expect(summary.entities[SummaryEntity.subjects]!.added, 1);
      expect(summary.totalChanges, 1);
      await w.repo.apply(file, summary);
      expect((await w.row('students', 'st1'))['name'], 'Rahim (PC)');
      expect((await w.row('subjects', 's3'))['name'], 'Chemistry');
    });

    test('a newer incoming edit updates the local row', () async {
      await p.seedAll();
      await w.importFile(await p.exportFile());
      await p.edit('batches', 'b1', {'name': 'HSC A (evening)'}, at: t0 + 5000);
      final file = await p.exportFile();
      final summary = await w.repo.preview(file);
      expect(summary.entities[SummaryEntity.batches]!.updated, 1);
      await w.repo.apply(file, summary);
      final b = await w.row('batches', 'b1');
      expect(b['name'], 'HSC A (evening)');
      expect(b['rev'], 2);
      expect(b['device_id'], 'dev-P');
      expect(b['updated_at'], t0 + 5000);
    });

    test('a newer tombstone soft-deletes the local row', () async {
      await p.seedAll();
      await w.importFile(await p.exportFile());
      await p.edit('payments', 'pay1', {'deleted_at': t0 + 3000}, at: t0 + 3000);
      final file = await p.exportFile();
      final summary = await w.repo.preview(file);
      expect(summary.entities[SummaryEntity.payments]!.deleted, 1);
      expect(summary.winners.first.kind, ChangeKind.delete);
      await w.repo.apply(file, summary);
      final pay = await w.row('payments', 'pay1');
      expect(pay['deleted_at'], t0 + 3000);
      expect(pay['amount'], 800, reason: 'tombstones keep the row');
    });

    test('absence in a backup never deletes local rows', () async {
      await w.put('subjects', 'w1', {'name': 'Biology', 'sort_order': 0, 'archived_at': null, 'notes': null});
      await p.seedAll();
      await w.importFile(await p.exportFile());
      expect((await w.row('subjects', 'w1'))['deleted_at'], isNull);
    });

    test('an empty summary is a no-op without a safety copy', () async {
      await p.seedAll();
      final file = await p.exportFile();
      final outcome = await w.repo.apply(file, const ChangeSummary());
      expect(outcome.applied, 0);
      expect(await w.count('subjects'), 0);
      expect(await w.count('safety_snapshots'), 0);
    });
  });

  group('safety copies', () {
    test('apply keeps a safety copy that restores the previous data', () async {
      await w.put('subjects', 'w1', {'name': 'Biology', 'sort_order': 0, 'archived_at': null, 'notes': null});
      final before = await w.dump();
      await p.seedAll();
      w.clock.ms = t0 + 1000;
      final outcome = await w.importFile(await p.exportFile());

      final list = await copies(w);
      expect(list, hasLength(1));
      expect(list.single.id, outcome.safetyCopyId);
      expect(list.single.reason, SafetyCopyReason.beforeImport);
      expect(list.single.createdAtMs, t0 + 1000);
      expect(await w.count('students'), 1);

      w.clock.ms = t0 + 2000;
      await w.repo.restoreSafetyCopy(outcome.safetyCopyId);
      expect(await w.dump(), before);

      final after = await copies(w);
      expect(after, hasLength(2));
      expect(after.first.reason, SafetyCopyReason.beforeRestore);
      expect(after.first.createdAtMs, t0 + 2000);

      // The restore itself can be undone.
      await w.repo.restoreSafetyCopy(after.first.id);
      expect(await w.count('students'), 1);
      expect(await w.count('student_photos'), 1);
    });

    test('only the newest 3 are kept', () async {
      await p.seedAll();
      final outcome = await w.importFile(await p.exportFile());
      for (var i = 1; i <= 4; i++) {
        w.clock.ms = t0 + i * 1000;
        await w.repo.restoreSafetyCopy((await copies(w)).last.id);
      }
      final list = await copies(w);
      expect(list, hasLength(kSafetyCopiesKept));
      expect(await w.count('safety_snapshots'), kSafetyCopiesKept);
      expect(list.map((c) => c.createdAtMs), [t0 + 4000, t0 + 3000, t0 + 2000]);
      expect(list.map((c) => c.id), isNot(contains(outcome.safetyCopyId)));
    });

    test('restoring an unknown id throws notFound', () async {
      await expectLater(
          w.repo.restoreSafetyCopy('nope'),
          throwsA(isA<NotFoundException>().having((e) => e.code, 'code', ErrorCodes.notFound)));
    });
  });

  group('schema v1 backups', () {
    test('an old (v1) backup imports: defaults filled, default place kept, receipts numbered', () async {
      await p.seedAll();
      final old = asV1(await p.exportFile());
      expect(old.schemaVersion, 1);
      expect(old.tables.containsKey('places'), isFalse);

      final outcome = await w.importFile(old);
      expect(outcome.applied, greaterThan(0));

      final b1 = await w.row('batches', 'b1');
      expect((b1['kind'], b1['place_id']), ('batch', kDefaultPlaceId));
      expect((await w.row('payments', 'pay1'))['receipt_no'], '2026-0001');
      expect((await w.row('other_income', 'oi1'))['place_id'], isNull);
      expect(await w.count('places'), 1);
      expect((await w.row('places', kDefaultPlaceId))['deleted_at'], isNull);
    });

    test('merging a v1 backup keeps local v2 values', () async {
      await p.seedAll();
      final old = asV1(await p.exportFile());
      await w.importFile(await p.exportFile());
      await w.db.customStatement("UPDATE payments SET receipt_no = '2026-0042' WHERE id = 'pay1'");
      await w.db.customStatement("UPDATE batches SET kind = 'tuition' WHERE id = 'b1'");

      final summary = await w.repo.preview(old);
      expect(summary.isEmpty, isTrue, reason: 'same rows, same stamps');
      await w.repo.apply(old, summary);
      expect((await w.row('payments', 'pay1'))['receipt_no'], '2026-0042');
      expect((await w.row('batches', 'b1'))['kind'], 'tuition');
    });

    test('restoring a v1 safety copy (e.g. the pre-migration one) refills places and numbers', () async {
      await p.seedAll();
      final old = asV1(await p.exportFile());
      await w.db.into(w.db.safetySnapshots).insert(SafetySnapshotsCompanion.insert(
            id: 'mig',
            createdAt: t0,
            reason: SafetyCopyReason.beforeMigration,
            bytes: Uint8List.fromList(SnapshotCodec.encode(old)),
          ));

      await w.repo.restoreSafetyCopy('mig');
      expect(await w.count('students'), 1);
      expect(await w.count('places'), 1);
      expect((await w.row('payments', 'pay1'))['receipt_no'], '2026-0001');
      expect((await w.row('batches', 'b1'))['place_id'], kDefaultPlaceId);
    });
  });

  group('all or nothing', () {
    late Snapshot good;
    late Map<String, List<Map<String, Object?>>> before;

    setUp(() async {
      await w.put('subjects', 'w1', {'name': 'Biology', 'sort_order': 0, 'archived_at': null, 'notes': null});
      before = await w.dump();
      await p.seedAll();
      good = await p.exportFile();
    });

    Future<void> expectUnchanged() async {
      expect(await w.dump(), before);
      expect(await w.count('safety_snapshots'), 0);
      expect(await w.count('import_log'), 0);
      expect(await w.count('local_meta'), 0);
    }

    test('a CHECK violation in the last table rolls back every earlier write', () async {
      final bad = rebuilt(good, (t) => t['attendance_records']![0]['status'] = 'X');
      await expectLater(w.repo.preview(bad), importError(ErrorCodes.importCorrupt));
      await expectUnchanged();
      // apply without a preview (summary from the pure diff) fails the same way.
      final summary = SyncDiff.diff(local: {}, incoming: bad);
      expect(summary.isEmpty, isFalse);
      await expectLater(w.repo.apply(bad, summary), importError(ErrorCodes.importCorrupt));
      await expectUnchanged();
    });

    test('a missing parent row is rejected by foreign_key_check', () async {
      final bad = rebuilt(good, (t) => t['payments']![0]['enrollment_id'] = 'ghost');
      await expectLater(w.repo.preview(bad), importError(ErrorCodes.importMissingParent));
      await expectUnchanged();
      final summary = SyncDiff.diff(local: {}, incoming: bad);
      await expectLater(w.repo.apply(bad, summary), importError(ErrorCodes.importMissingParent));
      await expectUnchanged();
    });

    test('the good file still applies afterwards', () async {
      await w.importFile(good);
      expect(await w.count('payments'), 1);
    });
  });

  group('rejected files', () {
    test('not a backup', () {
      expect(() => SnapshotCodec.decode(Uint8List.fromList([1, 2, 3, 4, 5])),
          importError(ErrorCodes.importNotBackup));
    });

    test('corrupted bytes', () async {
      await p.seedAll();
      final bytes = SnapshotCodec.encode(await p.repo.buildSnapshot(appVersion: '1'));
      final damaged = List<int>.of(bytes);
      damaged[damaged.length ~/ 2] ^= 0x55;
      expect(
          () => SnapshotCodec.decode(damaged),
          throwsA(isA<ImportException>().having(
              (e) => e.code, 'code', anyOf(ErrorCodes.importCorrupt, ErrorCodes.importChecksum))));
      final truncated = bytes.sublist(0, bytes.length - 20);
      expect(() => SnapshotCodec.decode(truncated), importError(ErrorCodes.importCorrupt));
    });

    test('newer schema', () async {
      final s = await p.repo.buildSnapshot(appVersion: '9');
      final newer = Snapshot(
        formatVersion: s.formatVersion,
        schemaVersion: kCurrentSchemaVersion + 1,
        appVersion: s.appVersion,
        snapshotId: s.snapshotId,
        deviceId: s.deviceId,
        deviceName: s.deviceName,
        createdAtMs: s.createdAtMs,
        counts: s.counts,
        sha256: s.sha256,
        tables: s.tables,
      );
      expect(() => SnapshotCodec.decode(SnapshotCodec.encode(newer)),
          importError(ErrorCodes.importNewerSchema));
    });

    test('rows with unknown columns, wrong types, bad dates or bad base64', () async {
      await p.seedAll();
      final good = await p.exportFile();
      final cases = <String, void Function(Map<String, List<RowMap>>)>{
        'unknown column': (t) => t['subjects']![0]['colour'] = 'red',
        'wrong type': (t) => t['students']![0]['name'] = 5,
        'null in NOT NULL': (t) => t['batches']![0]['name'] = null,
        'missing column': (t) => t['payments']![0].remove('paid_on'),
        'bad date': (t) => t['students']![0]['admission_date'] = '2026-02-30',
        'bad month': (t) => t['payments']![0]['billing_month'] = 202613,
        'bad base64': (t) => t['student_photos']![0]['jpeg'] = '***',
      };
      for (final e in cases.entries) {
        await expectLater(w.repo.preview(rebuilt(good, e.value)), importError(ErrorCodes.importCorrupt),
            reason: e.key);
      }
      expect(await w.count('subjects'), 0);
    });
  });

  group('overfilled months', () {
    test('counts months whose payments exceed the fee', () async {
      await p.seedAll(); // fee 1000, override 800, paid 800
      expect(await p.repo.countOverfilledMonths(), 0);
      await p.put('payments', 'pay2', {
        'receipt_id': 'rc2',
        'student_id': 'st1',
        'enrollment_id': 'e1',
        'batch_id': 'b1',
        'billing_month': 202611,
        'amount': 100,
        'paid_on': '2026-11-21',
        'method': 'bkash',
        'note': null,
        'waived': 0,
      });
      expect(await p.repo.countOverfilledMonths(), 1);
      await p.edit('payments', 'pay2', {'deleted_at': t0 + 1}, at: t0 + 1);
      expect(await p.repo.countOverfilledMonths(), 0);
    });
  });

  group('providers', () {
    test('backup providers resolve against the overridden database', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(w.db),
          deviceIdProvider.overrideWithValue('dev-W'),
          clockProvider.overrideWithValue(w.clock),
        ],
        retry: (_, __) => null,
      );
      addTearDown(container.dispose);
      final s = await container.read(backupRepositoryProvider).buildSnapshot(appVersion: '1');
      expect(s.deviceId, 'dev-W');
      expect(container.read(backupFilesProvider), isA<PluginBackupFiles>());
    });
  });
}
