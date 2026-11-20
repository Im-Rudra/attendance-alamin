import 'package:attendance_alamin/core/settings/setting_keys.dart';

/// Typed settings (Arch 3.8, plan 2.9). Routes by [SettingKey.scope]:
/// - `synced` keys live in the `settings` table (id = key), are stamped like
///   every synced row and travel in backups (last-writer-wins per key);
/// - `device` keys live in `local_meta` and never leave this device.
///
/// Values are stored JSON-encoded. A missing, malformed or out-of-range stored
/// value reads as the key's default. Use only [SettingKeys] constants, each
/// with its static type (do not route a `SettingKey<Object?>` from
/// `SettingKeys.all` through these generic methods).
abstract interface class SettingsRepository {
  /// Current value, re-emitted on every change (distinct values only).
  Stream<T> watch<T>(SettingKey<T> key);

  Future<T> get<T>(SettingKey<T> key);

  /// Stores [value]. Throws [ArgumentError] when the key's own codec rejects
  /// it (UI pickers only offer valid values). Writing the value already
  /// stored is a no-op (no new sync stamp).
  Future<void> set<T>(SettingKey<T> key, T value);
}
