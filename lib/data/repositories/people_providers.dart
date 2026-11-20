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
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
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
/// `ScheduleRepository.addExtra` (same database, so it joins the caller's
/// transaction).
final addExtraClassProvider = Provider<AddExtraClass>(
    (ref) => ref.watch(scheduleRepositoryProvider).addExtra);
