import 'package:attendance_alamin/data/backup/backup_files.dart';
import 'package:attendance_alamin/data/backup/backup_repository.dart';
import 'package:attendance_alamin/data/backup/backup_repository_drift.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backupRepositoryProvider = Provider<BackupRepository>((ref) => DriftBackupRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(syncStamperProvider),
      ref.watch(centerTimeProvider),
    ));

final backupFilesProvider = Provider<BackupFiles>((ref) => const PluginBackupFiles());

/// Safety copies, newest first (at most 3).
final safetyCopiesProvider = StreamProvider<List<SafetyCopyInfo>>(
    (ref) => ref.watch(backupRepositoryProvider).watchSafetyCopies());
