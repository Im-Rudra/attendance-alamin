import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/batches_repository.dart';
import 'package:attendance_alamin/data/repositories/drift/batches_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/schedule_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/subjects_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/data/repositories/subjects_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final subjectsRepositoryProvider = Provider<SubjectsRepository>(
  (ref) => DriftSubjectsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncStamperProvider),
    center: ref.watch(centerTimeProvider),
  ),
);

final batchesRepositoryProvider = Provider<BatchesRepository>(
  (ref) => DriftBatchesRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncStamperProvider),
    center: ref.watch(centerTimeProvider),
  ),
);

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => DriftScheduleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncStamperProvider),
    center: ref.watch(centerTimeProvider),
  ),
);
