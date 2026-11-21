// State of the backup feature: the import flow (pick, validate, preview,
// apply, undo) and the small providers the Backup screen reads. UI-free.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/backup/backup_providers.dart';
import 'package:attendance_alamin/data/backup/backup_repository.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/domain/sync/snapshot_codec.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_text.dart';
import 'package:attendance_alamin/features/backup/controllers/merge_clashes.dart';

/// A backup older than this many days turns the "last backup" line into an
/// info chip (UX 2f).
const int kBackupStaleDays = 7;

/// App version stored in the backup file ("1.0.0+12"); `unknown` when the
/// platform can't tell (tests).
final backupAppVersionProvider = FutureProvider<String>((Ref ref) async {
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    final String build = info.buildNumber.trim();
    return build.isEmpty ? info.version : '${info.version}+$build';
  } on Object {
    return 'unknown';
  }
});

/// Epoch ms of the last successful export; null = never.
final backupLastExportProvider = StreamProvider<int?>(
    (Ref ref) => ref.watch(settingsRepositoryProvider).watch(SettingKeys.lastExportAt));

/// Whole days since the last export in center time; null = never.
final backupDaysSinceProvider = Provider<int?>((Ref ref) {
  final int? at = ref.watch(backupLastExportProvider).value;
  if (at == null) return null;
  final int days = ref.watch(centerTimeProvider).dateOfEpochMs(at).daysUntil(ref.watch(todayProvider));
  return days < 0 ? 0 : days;
});

enum ImportPhase { idle, loading, ready, failed, applying, applied }

/// Everything the review screen shows. Immutable.
class ImportState {
  const ImportState({
    this.phase = ImportPhase.idle,
    this.snapshot,
    this.summary,
    this.names = const SnapshotNames(),
    this.clashes = const <MergeClash>[],
    this.older = false,
    this.errorCode,
    this.changes = 0,
    this.safetyCopyId = '',
    this.overfilled = 0,
  });

  final ImportPhase phase;
  final Snapshot? snapshot;
  final ChangeSummary? summary;
  final SnapshotNames names;

  /// Slot clashes the merge would create.
  final List<MergeClash> clashes;

  /// The backup is older than this device's data.
  final bool older;

  /// An `ErrorCodes` value: the file failed (phase failed) or the apply failed
  /// (phase ready, the teacher may retry).
  final String? errorCode;

  /// After apply: the changes applied.
  final int changes;

  /// After apply: the safety copy taken before the merge.
  final String safetyCopyId;

  /// After apply: months paid more than their fee.
  final int overfilled;

  /// Batch names of the clash lines (id -> name).
  String? batchName(String id) => names.batches[id];

  ImportState copyWith({ImportPhase? phase, String? errorCode, bool clearError = false}) => ImportState(
        phase: phase ?? this.phase,
        snapshot: snapshot,
        summary: summary,
        names: names,
        clashes: clashes,
        older: older,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        changes: changes,
        safetyCopyId: safetyCopyId,
        overfilled: overfilled,
      );
}

String _codeOf(Object e, {String fallback = ErrorCodes.unknown}) =>
    e is AppException ? e.code : fallback;

class ImportController extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportState();

  /// Lets the user pick a file, validates it and builds the change summary.
  /// Returns false when the picker was cancelled (nothing changes).
  Future<bool> pickAndPreview() async {
    Uint8List? bytes;
    try {
      bytes = await ref.read(backupFilesProvider).pick();
    } on Object catch (e) {
      if (!ref.mounted) return false;
      state = ImportState(phase: ImportPhase.failed, errorCode: _codeOf(e));
      return true;
    }
    if (!ref.mounted || bytes == null) return false;

    state = const ImportState(phase: ImportPhase.loading);
    try {
      final Snapshot snapshot = SnapshotCodec.decode(bytes);
      final ChangeSummary summary = await ref.read(backupRepositoryProvider).preview(snapshot);
      final List<BatchSchedule> schedules = await _schedules();
      final Map<String, String> localBatches = <String, String>{
        for (final BatchSchedule bs in schedules) bs.batch.id: bs.batch.name,
      };
      final int? lastExport = await _lastExport();
      if (!ref.mounted) return true;
      int kept = 0;
      for (final EntityChange e in summary.entities.values) {
        kept += e.keptLocal;
      }
      state = ImportState(
        phase: ImportPhase.ready,
        snapshot: snapshot,
        summary: summary,
        names: SnapshotNames.of(snapshot, extraBatches: localBatches),
        clashes: findMergeClashes(winners: summary.winners, local: schedules),
        older: kept > 0 || (lastExport != null && snapshot.createdAtMs < lastExport),
      );
    } on Object catch (e) {
      if (!ref.mounted) return true;
      state = ImportState(
        phase: ImportPhase.failed,
        errorCode: _codeOf(e, fallback: ErrorCodes.importCorrupt),
      );
    }
    return true;
  }

  /// Applies the previewed merge (only when it has changes).
  Future<void> apply() async {
    final ImportState s = state;
    final Snapshot? snapshot = s.snapshot;
    final ChangeSummary? summary = s.summary;
    if (s.phase != ImportPhase.ready || snapshot == null || summary == null || summary.isEmpty) return;
    state = s.copyWith(phase: ImportPhase.applying, clearError: true);
    try {
      final BackupRepository repo = ref.read(backupRepositoryProvider);
      final ApplyOutcome outcome = await repo.apply(snapshot, summary);
      if (!ref.mounted) return;
      if (outcome.safetyCopyId.isEmpty) {
        // The data already matches the backup (recomputed inside the
        // transaction): show the "nothing to do" view.
        state = ImportState(
          phase: ImportPhase.ready,
          snapshot: snapshot,
          summary: const ChangeSummary(),
          names: s.names,
          older: s.older,
        );
        return;
      }
      int overfilled = 0;
      try {
        overfilled = await repo.countOverfilledMonths();
      } on Object {
        overfilled = 0;
      }
      if (!ref.mounted) return;
      state = ImportState(
        phase: ImportPhase.applied,
        changes: summary.totalChanges,
        safetyCopyId: outcome.safetyCopyId,
        overfilled: overfilled,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = s.copyWith(phase: ImportPhase.ready, errorCode: _codeOf(e));
    }
  }

  /// "আগের অবস্থায় ফেরান": restores the safety copy taken before the apply.
  /// Returns true when the data is back.
  Future<bool> undo() async {
    final ImportState s = state;
    if (s.phase != ImportPhase.applied || s.safetyCopyId.isEmpty) return false;
    try {
      await ref.read(backupRepositoryProvider).restoreSafetyCopy(s.safetyCopyId);
      // The state is cleared when the review closes (backup_entry.dart), so
      // the result does not flash an empty view while the screen leaves.
      return true;
    } on Object catch (e) {
      if (ref.mounted) state = s.copyWith(errorCode: _codeOf(e));
      return false;
    }
  }

  void reset() => state = const ImportState();

  Future<List<BatchSchedule>> _schedules() async {
    try {
      return await ref
          .read(schedulesProvider.future)
          .timeout(const Duration(seconds: 3), onTimeout: () => const <BatchSchedule>[]);
    } on Object {
      return const <BatchSchedule>[];
    }
  }

  Future<int?> _lastExport() async {
    try {
      return await ref.read(settingsRepositoryProvider).get(SettingKeys.lastExportAt);
    } on Object {
      return null;
    }
  }
}

final importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);
