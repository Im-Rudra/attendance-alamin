// In-memory fakes for widget tests (plan 2.11): settings, local meta, backup.

import 'dart:async';
import 'dart:typed_data';

import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/backup/backup_files.dart';
import 'package:attendance_alamin/data/backup/backup_repository.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_repository.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';

/// Emits [read] on listen and again on every [changes] event that [matches].
Stream<T> _follow<T>(Stream<Object?> changes, bool Function(Object? e) matches, T Function() read) {
  StreamSubscription<Object?>? sub;
  late final StreamController<T> controller;
  controller = StreamController<T>(
    onListen: () {
      controller.add(read());
      sub = changes.listen((e) {
        if (matches(e)) controller.add(read());
      });
    },
    onCancel: () => sub?.cancel(),
  );
  return controller.stream;
}

/// Settings kept as encoded JSON values by key id (scope is ignored).
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([Map<String, Object?>? initialEncoded])
      : _values = {...?initialEncoded};

  final Map<String, Object?> _values;
  final StreamController<String> _changes = StreamController<String>.broadcast();

  /// Encoded values by key id (inspect in tests).
  Map<String, Object?> get encodedValues => Map.unmodifiable(_values);

  T _read<T>(SettingKey<T> key) =>
      _values.containsKey(key.id) ? key.decode(_values[key.id]) : key.defaultValue;

  @override
  Future<T> get<T>(SettingKey<T> key) async => _read(key);

  @override
  Future<void> set<T>(SettingKey<T> key, T value) async {
    final encoded = key.encode(value);
    try {
      key.fromJson(encoded);
    } on Object catch (e) {
      throw ArgumentError.value(value, key.id, 'rejected by the setting codec: $e');
    }
    _values[key.id] = encoded;
    _changes.add(key.id);
  }

  @override
  Stream<T> watch<T>(SettingKey<T> key) =>
      _follow<T>(_changes.stream, (id) => id == key.id, () => _read(key)).distinct();
}

class FakeLocalMetaRepository implements LocalMetaRepository {
  FakeLocalMetaRepository([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;
  final StreamController<String> _changes = StreamController<String>.broadcast();

  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<String?> getRaw(String key) async => _values[key];

  @override
  Future<void> setRaw(String key, String? value) async {
    if (key.isEmpty || LocalMetaKeys.reserved.contains(key)) {
      throw ArgumentError.value(key, 'key', 'reserved or empty local_meta key');
    }
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    _changes.add(key);
  }

  @override
  Stream<String?> watchRaw(String key) =>
      _follow<String?>(_changes.stream, (k) => k == key, () => _values[key]).distinct();
}

/// Scriptable backup repository: set the `next*` fields, inspect the calls.
class FakeBackupRepository implements BackupRepository {
  Snapshot? nextSnapshot;
  ChangeSummary nextSummary = const ChangeSummary();
  Object? previewError;
  Object? applyError;
  int overfilledMonths = 0;

  final List<Snapshot> previewed = [];
  final List<Snapshot> applied = [];
  final List<String> restored = [];

  final StreamController<List<SafetyCopyInfo>> _copies =
      StreamController<List<SafetyCopyInfo>>.broadcast();
  List<SafetyCopyInfo> _safetyCopies = const [];

  List<SafetyCopyInfo> get safetyCopies => _safetyCopies;
  set safetyCopies(List<SafetyCopyInfo> v) {
    _safetyCopies = List.unmodifiable(v);
    _copies.add(_safetyCopies);
  }

  @override
  Future<Snapshot> buildSnapshot({required String appVersion}) async {
    final s = nextSnapshot;
    if (s == null) throw StateError('FakeBackupRepository.nextSnapshot not set');
    return s;
  }

  @override
  Future<ChangeSummary> preview(Snapshot incoming) async {
    previewed.add(incoming);
    final e = previewError;
    if (e != null) throw e;
    return nextSummary;
  }

  @override
  Future<ApplyOutcome> apply(Snapshot incoming, ChangeSummary summary) async {
    final e = applyError;
    if (e != null) throw e;
    if (summary.isEmpty) return const ApplyOutcome(applied: 0, safetyCopyId: '');
    applied.add(incoming);
    final id = 'safety-${applied.length}';
    safetyCopies = [
      SafetyCopyInfo(id: id, createdAtMs: incoming.createdAtMs, reason: SafetyCopyReason.beforeImport),
      ..._safetyCopies,
    ].take(kSafetyCopiesKept).toList();
    return ApplyOutcome(applied: summary.winners.length, safetyCopyId: id);
  }

  @override
  Stream<List<SafetyCopyInfo>> watchSafetyCopies() =>
      _follow<List<SafetyCopyInfo>>(_copies.stream, (_) => true, () => _safetyCopies);

  @override
  Future<void> restoreSafetyCopy(String id) async => restored.add(id);

  @override
  Future<int> countOverfilledMonths() async => overfilledMonths;
}

class FakeBackupFiles implements BackupFiles {
  bool saveResult = true;
  Uint8List? pickResult;

  final List<(String, Uint8List)> saved = [];
  final List<(String, Uint8List)> shared = [];

  @override
  Future<bool> save(Uint8List bytes, {required String fileName}) async {
    if (saveResult) saved.add((fileName, bytes));
    return saveResult;
  }

  @override
  Future<void> share(Uint8List bytes, {required String fileName}) async =>
      shared.add((fileName, bytes));

  @override
  Future<Uint8List?> pick() async => pickResult;
}
