import 'package:attendance_alamin/domain/models/value_equality.dart';

typedef RowMap = Map<String, Object?>;

/// A parsed backup file.
class Snapshot {
  const Snapshot({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.snapshotId,
    required this.deviceId,
    required this.deviceName,
    required this.createdAtMs,
    required this.counts,
    required this.sha256,
    required this.tables,
  });

  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final String snapshotId;
  final String deviceId;
  final String deviceName;
  final int createdAtMs;
  final Map<String, int> counts;
  final String sha256;
  final Map<String, List<RowMap>> tables;

  @override
  bool operator ==(Object other) =>
      other is Snapshot &&
      other.formatVersion == formatVersion &&
      other.schemaVersion == schemaVersion &&
      other.appVersion == appVersion &&
      other.snapshotId == snapshotId &&
      other.deviceId == deviceId &&
      other.deviceName == deviceName &&
      other.createdAtMs == createdAtMs &&
      mapEq(other.counts, counts) &&
      other.sha256 == sha256 &&
      _tablesEq(other.tables, tables);

  @override
  int get hashCode => Object.hash(formatVersion, schemaVersion, appVersion,
      snapshotId, deviceId, deviceName, createdAtMs, mapHash(counts), sha256,
      tables.length);

  static bool _tablesEq(Map<String, List<RowMap>> a, Map<String, List<RowMap>> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null || e.value.length != o.length) return false;
      for (var i = 0; i < o.length; i++) {
        if (!mapEq(e.value[i], o[i])) return false;
      }
    }
    return true;
  }

  @override
  String toString() => 'Snapshot($snapshotId, v$schemaVersion)';
}

enum ChangeKind { add, update, delete, restore }

/// One incoming row that wins over (or is new to) the local database.
class RowChange {
  const RowChange({
    required this.table,
    required this.id,
    required this.kind,
    required this.incoming,
    this.local,
  });

  final String table;
  final String id;
  final ChangeKind kind;
  final RowMap incoming;
  final RowMap? local;

  @override
  bool operator ==(Object other) =>
      other is RowChange &&
      other.table == table &&
      other.id == id &&
      other.kind == kind &&
      mapEq(other.incoming, incoming) &&
      ((other.local == null && local == null) ||
          (other.local != null &&
              local != null &&
              mapEq(other.local!, local!)));

  @override
  int get hashCode => Object.hash(table, id, kind);

  @override
  String toString() => 'RowChange($table/$id ${kind.name})';
}

enum SummaryEntity {
  subjects,
  batches,
  schedule,
  students,
  enrollments,
  attendance,
  payments,
  settings,
}

/// Per-entity change counts plus up to 3 sample rows per bucket.
class EntityChange {
  const EntityChange({
    this.added = 0,
    this.updated = 0,
    this.deleted = 0,
    this.keptLocal = 0,
    this.addedSamples = const [],
    this.updatedSamples = const [],
    this.deletedSamples = const [],
  });

  final int added;

  /// Includes restored rows.
  final int updated;
  final int deleted;
  final int keptLocal;
  final List<RowMap> addedSamples;
  final List<RowMap> updatedSamples;
  final List<RowMap> deletedSamples;

  int get total => added + updated + deleted;

  @override
  bool operator ==(Object other) =>
      other is EntityChange &&
      other.added == added &&
      other.updated == updated &&
      other.deleted == deleted &&
      other.keptLocal == keptLocal &&
      _rowsEq(other.addedSamples, addedSamples) &&
      _rowsEq(other.updatedSamples, updatedSamples) &&
      _rowsEq(other.deletedSamples, deletedSamples);

  @override
  int get hashCode => Object.hash(added, updated, deleted, keptLocal,
      addedSamples.length, updatedSamples.length, deletedSamples.length);

  static bool _rowsEq(List<RowMap> a, List<RowMap> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!mapEq(a[i], b[i])) return false;
    }
    return true;
  }
}

class ChangeSummary {
  const ChangeSummary({
    this.entities = const {},
    this.winners = const [],
  });

  final Map<SummaryEntity, EntityChange> entities;

  /// The row changes to apply.
  final List<RowChange> winners;

  /// Added + updated + deleted over all entities (kept-local rows excluded).
  int get totalChanges =>
      entities.values.fold(0, (s, e) => s + e.added + e.updated + e.deleted);

  bool get isEmpty => totalChanges == 0;

  @override
  bool operator ==(Object other) =>
      other is ChangeSummary &&
      mapEq(other.entities, entities) &&
      listEq(other.winners, winners);

  @override
  int get hashCode => Object.hash(mapHash(entities), Object.hashAll(winners));
}
