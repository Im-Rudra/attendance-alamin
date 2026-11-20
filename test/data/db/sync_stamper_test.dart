import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:drift/drift.dart' hide Batch;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_fixtures.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(t0, isUtc: true);

  group('SyncStamper', () {
    final stamper = SyncStamper(clock: FixedClock(now), deviceId: 'dev-A');

    test('nowMs is the clock instant in UTC epoch ms', () {
      expect(stamper.nowMs(), t0);
      expect(stamper.deviceId, 'dev-A');
    });

    test('nextUpdatedAt = max(now, old + 1)', () {
      expect(stamper.nextUpdatedAt(t0 - 5000), t0); // clock ahead: now
      expect(stamper.nextUpdatedAt(t0), t0 + 1); // same ms: still grows
      expect(stamper.nextUpdatedAt(t0 + 60000), t0 + 60001); // clock behind
    });

    test('nextRev increments', () {
      expect(stamper.nextRev(1), 2);
      expect(stamper.nextRev(41), 42);
    });

    test('insert then update then soft delete follows the stamping rules',
        () async {
      final db = openMemoryDb();
      final ins = SyncStamper(clock: FixedClock(now), deviceId: 'dev-A');
      await db.into(db.subjects).insert(subjectToCompanion(subjectA).copyWith(
            createdAt: Value(ins.nowMs()),
            updatedAt: Value(ins.nowMs()),
            deviceId: Value(ins.deviceId),
          ));
      var row = await db.select(db.subjects).getSingle();
      expect((row.createdAt, row.updatedAt, row.rev, row.deviceId),
          (t0, t0, 1, 'dev-A'));

      // A second device whose clock runs 1 h behind edits the row.
      final behind = SyncStamper(
          clock: FixedClock(now.subtract(const Duration(hours: 1))),
          deviceId: 'dev-B');
      await (db.update(db.subjects)..where((t) => t.id.equals(row.id)))
          .write(SubjectsCompanion(
        name: const Value('Higher Math'),
        updatedAt: Value(behind.nextUpdatedAt(row.updatedAt)),
        rev: Value(behind.nextRev(row.rev)),
        deviceId: Value(behind.deviceId),
      ));
      row = await db.select(db.subjects).getSingle();
      expect((row.createdAt, row.updatedAt, row.rev, row.deviceId),
          (t0, t0 + 1, 2, 'dev-B'));

      await (db.update(db.subjects)..where((t) => t.id.equals(row.id)))
          .write(SubjectsCompanion(
        deletedAt: Value(ins.nowMs()),
        updatedAt: Value(ins.nextUpdatedAt(row.updatedAt)),
        rev: Value(ins.nextRev(row.rev)),
        deviceId: Value(ins.deviceId),
      ));
      row = await db.select(db.subjects).getSingle();
      expect(row.deletedAt, t0);
      expect(row.updatedAt, t0 + 2);
      expect(row.rev, 3);
      expect(
          await (db.select(db.subjects)..where((t) => t.deletedAt.isNull()))
              .get(),
          isEmpty);
    });
  });

  group('infra providers', () {
    test('ensureDeviceId creates once and then returns the stored id',
        () async {
      final db = openMemoryDb();
      final first = await ensureDeviceId(db);
      expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(await ensureDeviceId(db), first);
      final both = await Future.wait([ensureDeviceId(db), ensureDeviceId(db)]);
      expect(both, [first, first]);
      final rows = await db.select(db.localMeta).get();
      expect(rows.single.metaKey, kDeviceIdMetaKey);
    });

    test('syncStamperProvider combines clock and device id', () {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(now)),
          deviceIdProvider.overrideWithValue('dev-X'),
        ],
        retry: (_, __) => null,
      );
      addTearDown(container.dispose);
      final stamper = container.read(syncStamperProvider);
      expect(stamper.deviceId, 'dev-X');
      expect(stamper.nowMs(), t0);
      expect(container.read(centerTimeProvider), CenterTime.dhaka);
    });

    test('database and device id must be overridden in bootstrap', () {
      final container = ProviderContainer(retry: (_, __) => null);
      addTearDown(container.dispose);
      expect(() => container.read(appDatabaseProvider), throwsA(anything));
      expect(() => container.read(deviceIdProvider), throwsA(anything));
    });

    test('appDatabaseProvider accepts an in-memory override', () {
      final db = openMemoryDb();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        retry: (_, __) => null,
      );
      addTearDown(container.dispose);
      expect(container.read(appDatabaseProvider), same(db));
      expect(container.read(appDatabaseProvider), isA<AppDatabase>());
    });
  });
}
