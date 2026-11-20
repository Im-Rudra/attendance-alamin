import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "now" (override with `FixedClock` in tests).
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The center's wall clock: fixed UTC+6 (Arch 3.1).
final centerTimeProvider = Provider<CenterTime>((ref) => CenterTime.dhaka);

/// This device's id (`local_meta.device_id`); overridden in bootstrap with the
/// value of [ensureDeviceId].
final deviceIdProvider = Provider<String>(
    (ref) => throw UnimplementedError('override in bootstrap'));

/// The open database; overridden in bootstrap
/// (`AppDatabase(openConnection())`) and in tests
/// (`AppDatabase(NativeDatabase.memory())`).
final appDatabaseProvider = Provider<AppDatabase>(
    (ref) => throw UnimplementedError('override in bootstrap'));

final syncStamperProvider = Provider<SyncStamper>((ref) => SyncStamper(
    clock: ref.watch(clockProvider), deviceId: ref.watch(deviceIdProvider)));

/// `local_meta` key of the device id.
const kDeviceIdMetaKey = 'device_id';

/// Returns this device's id, creating it (UUID v4) on first launch. Safe to
/// call repeatedly and concurrently: the first stored value always wins.
Future<String> ensureDeviceId(AppDatabase db) async {
  Future<String?> read() async {
    final row = await (db.select(db.localMeta)
          ..where((t) => t.metaKey.equals(kDeviceIdMetaKey)))
        .getSingleOrNull();
    return row?.metaValue;
  }

  final existing = await read();
  if (existing != null) return existing;
  await db.into(db.localMeta).insert(
        LocalMetaCompanion.insert(
            metaKey: kDeviceIdMetaKey, metaValue: Ids.v4()),
        mode: InsertMode.insertOrIgnore,
      );
  final created = await read();
  if (created == null) {
    throw StateError('device_id could not be stored in local_meta');
  }
  return created;
}
