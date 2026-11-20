import 'dart:convert';

import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/settings_repository.dart';
import 'package:drift/drift.dart' hide Batch;

/// Drift implementation of [SettingsRepository] (Arch 3.8).
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, this._stamper);

  final AppDatabase _db;
  final SyncStamper _stamper;

  @override
  Stream<T> watch<T>(SettingKey<T> key) {
    final Stream<String?> raw;
    if (key.scope == SettingScope.synced) {
      raw = (_db.select(_db.syncedSettings)
            ..where((t) => t.id.equals(key.id) & t.deletedAt.isNull()))
          .watchSingleOrNull()
          .map((r) => r?.value);
    } else {
      raw = (_db.select(_db.localMeta)..where((t) => t.metaKey.equals(key.id)))
          .watchSingleOrNull()
          .map((r) => r?.metaValue);
    }
    return raw.map((text) => decodeSetting(key, text)).distinct();
  }

  @override
  Future<T> get<T>(SettingKey<T> key) async {
    if (key.scope == SettingScope.synced) {
      final row = await (_db.select(_db.syncedSettings)
            ..where((t) => t.id.equals(key.id) & t.deletedAt.isNull()))
          .getSingleOrNull();
      return decodeSetting(key, row?.value);
    }
    final row = await (_db.select(_db.localMeta)
          ..where((t) => t.metaKey.equals(key.id)))
        .getSingleOrNull();
    return decodeSetting(key, row?.metaValue);
  }

  @override
  Future<void> set<T>(SettingKey<T> key, T value) async {
    final encoded = key.encode(value);
    try {
      key.fromJson(encoded);
    } on Object catch (e) {
      throw ArgumentError.value(value, key.id, 'rejected by the setting codec: $e');
    }
    final text = jsonEncode(encoded);

    if (key.scope == SettingScope.device) {
      if (encoded == null) {
        await (_db.delete(_db.localMeta)..where((t) => t.metaKey.equals(key.id))).go();
      } else {
        await _db
            .into(_db.localMeta)
            .insertOnConflictUpdate(LocalMetaCompanion.insert(metaKey: key.id, metaValue: text));
      }
      return;
    }

    await _db.transaction(() async {
      // Tombstoned rows included: a re-set revives the same id.
      final old = await (_db.select(_db.syncedSettings)..where((t) => t.id.equals(key.id)))
          .getSingleOrNull();
      if (old == null) {
        final now = _stamper.nowMs();
        await _db.into(_db.syncedSettings).insert(SyncedSettingsCompanion.insert(
              id: key.id,
              createdAt: now,
              updatedAt: now,
              deviceId: _stamper.deviceId,
              value: text,
            ));
        return;
      }
      if (old.deletedAt == null && old.value == text) return;
      await (_db.update(_db.syncedSettings)..where((t) => t.id.equals(key.id))).write(
        SyncedSettingsCompanion(
          value: Value(text),
          updatedAt: Value(_stamper.nextUpdatedAt(old.updatedAt)),
          rev: Value(_stamper.nextRev(old.rev)),
          deviceId: Value(_stamper.deviceId),
          deletedAt: const Value(null),
        ),
      );
    });
  }
}

/// Stored JSON text to a typed value; absent, malformed or invalid text
/// gives the key's default.
T decodeSetting<T>(SettingKey<T> key, String? text) {
  if (text == null) return key.defaultValue;
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return key.defaultValue;
  }
  return key.decode(json);
}
