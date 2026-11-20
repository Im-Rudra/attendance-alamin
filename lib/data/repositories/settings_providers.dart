import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/drift/local_meta_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/settings_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) =>
    DriftSettingsRepository(ref.watch(appDatabaseProvider), ref.watch(syncStamperProvider)));

final localMetaRepositoryProvider =
    Provider<LocalMetaRepository>((ref) => DriftLocalMetaRepository(ref.watch(appDatabaseProvider)));
