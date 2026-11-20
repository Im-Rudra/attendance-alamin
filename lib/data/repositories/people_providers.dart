import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/data/repositories/drift/attendance_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/enrollments_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/other_income_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/payments_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/students_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/enrollments_repository.dart';
import 'package:attendance_alamin/data/repositories/other_income_repository.dart';
import 'package:attendance_alamin/data/repositories/payments_repository.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final studentsRepositoryProvider = Provider<StudentsRepository>((ref) =>
    DriftStudentsRepository(
        ref.watch(appDatabaseProvider), ref.watch(syncStamperProvider),
        center: ref.watch(centerTimeProvider)));

final enrollmentsRepositoryProvider = Provider<EnrollmentsRepository>((ref) =>
    DriftEnrollmentsRepository(
        ref.watch(appDatabaseProvider), ref.watch(syncStamperProvider),
        center: ref.watch(centerTimeProvider)));

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) =>
    DriftPaymentsRepository(
        ref.watch(appDatabaseProvider), ref.watch(syncStamperProvider),
        center: ref.watch(centerTimeProvider)));

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) =>
    DriftAttendanceRepository(
        ref.watch(appDatabaseProvider), ref.watch(syncStamperProvider),
        addExtra: ref.watch(addExtraClassProvider),
        center: ref.watch(centerTimeProvider)));

final otherIncomeRepositoryProvider = Provider<OtherIncomeRepository>((ref) =>
    DriftOtherIncomeRepository(
        ref.watch(appDatabaseProvider), ref.watch(syncStamperProvider)));

/// How an ad-hoc roll call creates its extra class: M4-A's clash-checked
/// `ScheduleRepository.addExtra`. Wire it once both modules are merged:
/// `(ref) => ref.watch(scheduleRepositoryProvider).addExtra`. Until then an
/// ad-hoc roll call throws [UnsupportedError]; every other attendance call
/// works.
final addExtraClassProvider = Provider<AddExtraClass>((ref) => _addExtraNotWired);

Future<String> _addExtraNotWired({
  required String batchId,
  required LocalDate date,
  required int startMin,
  required int endMin,
  String? note,
}) async =>
    throw UnsupportedError('addExtraClassProvider is not wired to '
        'ScheduleRepository.addExtra');
