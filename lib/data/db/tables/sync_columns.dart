import 'package:drift/drift.dart';

/// Sync stamp columns shared by every synced table (Arch 3.1).
///
/// `id` is a UUID text primary key (each table declares `primaryKey => {id}`),
/// times are UTC epoch ms, `deleted_at` is the tombstone, `device_id` is the
/// last writer and `rev` grows by one on every write. Stamped only through
/// `SyncStamper` inside repositories.
///
/// Note: drift_dev only accepts `customConstraints` written as a list of plain
/// string literals, so CHECK texts are repeated per table instead of being
/// built by helper functions.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get deviceId => text()();
  IntColumn get rev => integer().withDefault(const Constant(1))();
}
