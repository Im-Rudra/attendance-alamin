import 'package:attendance_alamin/domain/sync/sync_models.dart';

/// Backup export / merge-import (Product 4, Arch 3.3-3.6).
///
/// Typical flows (M9-A):
/// - export: `buildSnapshot` → `SnapshotCodec.encode` → `BackupFiles.save`;
///   when save returns true, record `SettingKeys.lastExportAt =
///   snapshot.createdAtMs` through the settings repository (a cancelled save
///   must not count as a backup, so [buildSnapshot] does not record it).
/// - import: `BackupFiles.pick` → `SnapshotCodec.decode` (ImportException) →
///   [preview] → show the summary → [apply] only when `!summary.isEmpty`.
abstract interface class BackupRepository {
  /// All synced tables INCLUDING tombstones (blobs as base64), stamped with
  /// this device's id and name. Device-only settings are never included.
  Future<Snapshot> buildSnapshot({required String appVersion});

  /// Validates every incoming row of the synced tables (known columns, column
  /// types, required values, dates/months, CHECKs and parent rows, via a
  /// rolled-back trial apply) and returns the LWW merge summary against the
  /// current data. Throws [ImportException] (`importCorrupt`,
  /// `importMissingParent`) for an unusable backup; never changes data.
  Future<ChangeSummary> preview(Snapshot incoming);

  /// Applies the merge in ONE transaction: safety copy of the current data
  /// (last 3 kept), `PRAGMA defer_foreign_keys`, upserts of the winners in
  /// their order, `import_log`, `PRAGMA foreign_key_check` + `quick_check`.
  /// All or nothing. The diff is recomputed inside the transaction so edits
  /// made after [preview] are respected. An empty [summary] (or an empty
  /// recomputed diff) applies nothing and returns `applied: 0` with an empty
  /// `safetyCopyId`.
  Future<ApplyOutcome> apply(Snapshot incoming, ChangeSummary summary);

  /// Safety copies, newest first (at most 3).
  Stream<List<SafetyCopyInfo>> watchSafetyCopies();

  /// Replaces every synced table with the safety copy's content (the only
  /// sanctioned hard delete). The current data is first kept as a new safety
  /// copy (reason `restore`), so a restore can itself be undone. Throws
  /// [NotFoundException] (`notFound`) for an unknown id.
  Future<void> restoreSafetyCopy(String id);

  /// (Enrollment, month) pairs whose live payments exceed that month's fee
  /// (waived months excluded): "N টি মাসে বেশি টাকা জমা" after a merge.
  Future<int> countOverfilledMonths();
}

class ApplyOutcome {
  const ApplyOutcome({required this.applied, required this.safetyCopyId});

  /// Rows written (winners, invisible tombstone updates included).
  final int applied;

  /// Id of the safety copy taken before the merge ('' when nothing applied).
  final String safetyCopyId;
}

class SafetyCopyInfo {
  const SafetyCopyInfo({required this.id, required this.createdAtMs, required this.reason});

  final String id;
  final int createdAtMs;

  /// [SafetyCopyReason] value.
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is SafetyCopyInfo &&
      other.id == id &&
      other.createdAtMs == createdAtMs &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(id, createdAtMs, reason);
}

/// `safety_snapshots.reason` values.
abstract final class SafetyCopyReason {
  static const beforeImport = 'import';
  static const beforeRestore = 'restore';

  /// Written by a schema migration (`kSafetyReasonMigration`).
  static const beforeMigration = 'migration';
}

/// How many safety copies are kept (plan section 1 #15).
const kSafetyCopiesKept = 3;
