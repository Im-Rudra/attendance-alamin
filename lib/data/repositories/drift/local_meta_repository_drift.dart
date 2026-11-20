import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';

/// Drift implementation of [LocalMetaRepository] over `local_meta`.
class DriftLocalMetaRepository implements LocalMetaRepository {
  DriftLocalMetaRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String?> getRaw(String key) async {
    final row = await (_db.select(_db.localMeta)..where((t) => t.metaKey.equals(key)))
        .getSingleOrNull();
    return row?.metaValue;
  }

  @override
  Stream<String?> watchRaw(String key) =>
      (_db.select(_db.localMeta)..where((t) => t.metaKey.equals(key)))
          .watchSingleOrNull()
          .map((r) => r?.metaValue)
          .distinct();

  @override
  Future<void> setRaw(String key, String? value) async {
    if (key.isEmpty || LocalMetaKeys.reserved.contains(key)) {
      throw ArgumentError.value(key, 'key', 'reserved or empty local_meta key');
    }
    if (value == null) {
      await (_db.delete(_db.localMeta)..where((t) => t.metaKey.equals(key))).go();
      return;
    }
    await _db
        .into(_db.localMeta)
        .insertOnConflictUpdate(LocalMetaCompanion.insert(metaKey: key, metaValue: value));
  }
}
