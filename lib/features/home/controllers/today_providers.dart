// Providers of the Today screen: the picked day and view, and the derived data
// of each tile (hero, collection, attendance, recent receipts, backup nudge,
// reminder-window hint). Data comes from the app-level providers and the
// repository stream providers only.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';

/// The date picked on the day strip; `null` follows today (so the screen rolls
/// over at midnight by itself).
class TodaySelectedDate extends Notifier<LocalDate?> {
  @override
  LocalDate? build() => null;

  void select(LocalDate? date) => state = date;
}

final todaySelectedDateProvider =
    NotifierProvider<TodaySelectedDate, LocalDate?>(TodaySelectedDate.new);

/// Day cards or the week grid (wide windows).
enum TodayView { day, week }

class TodayViewController extends Notifier<TodayView> {
  @override
  TodayView build() => TodayView.day;

  void set(TodayView view) => state = view;
}

final todayViewProvider =
    NotifierProvider<TodayViewController, TodayView>(TodayViewController.new);

// ---- raw streams -------------------------------------------------------------

final todayBatchesProvider = StreamProvider<List<Batch>>(
    (ref) => ref.watch(batchesRepositoryProvider).watchAll());

final todayStudentsProvider = StreamProvider<List<Student>>(
    (ref) => ref.watch(studentsRepositoryProvider).watchAll());

final todayPaymentsProvider = StreamProvider<List<Payment>>(
    (ref) => ref.watch(paymentsRepositoryProvider).watchAll());

final _lastExportProvider = StreamProvider<int?>((ref) =>
    ref.watch(settingsRepositoryProvider).watch(SettingKeys.lastExportAt));

final _backupDaysProvider = StreamProvider<int>((ref) => ref
    .watch(settingsRepositoryProvider)
    .watch(SettingKeys.backupReminderDays));

final _remindersEnabledProvider = StreamProvider<bool>((ref) => ref
    .watch(settingsRepositoryProvider)
    .watch(SettingKeys.remindersEnabled));

final _plannedUntilProvider = StreamProvider<int?>((ref) => ref
    .watch(settingsRepositoryProvider)
    .watch(SettingKeys.remindersPlannedUntil));

/// Epoch ms of now, refreshed every minute.
final todayNowMsProvider = Provider<int>((ref) {
  ref.watch(minuteTickProvider);
  return ref.watch(clockProvider).nowUtc().millisecondsSinceEpoch;
});

// ---- derived -----------------------------------------------------------------

/// The hero card of [date].
final todayHeroProvider =
    Provider.family<AsyncValue<HeroState>, LocalDate>((ref, date) {
  final LocalDate today = ref.watch(todayProvider);
  final int nowMin = ref.watch(nowMinutesProvider);
  return combine2(
    ref.watch(todayBatchesProvider),
    ref.watch(dayPlanProvider(date)),
    (List<Batch> batches, DayPlan plan) => buildHero(
      hasBatches: batches.isNotEmpty,
      date: date,
      today: today,
      nowMin: nowMin,
      classes: plan.classes,
    ),
  );
});

/// Attendance numbers of [date].
final todayAttendanceProvider =
    Provider.family<AsyncValue<DayAttendance>, LocalDate>((ref, date) =>
        ref
            .watch(dayPlanProvider(date))
            .whenData((DayPlan p) => buildDayAttendance(p.classes)));

/// This month's collection.
final todayCollectionProvider = Provider<AsyncValue<MonthCollection>>((ref) {
  final LocalDate today = ref.watch(todayProvider);
  return combine3(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    ref.watch(todayPaymentsProvider),
    (terms, facts, payments) => buildMonthCollection(
      today: today,
      terms: terms,
      facts: facts,
      payments: payments,
    ),
  );
});

/// The last five receipts.
final todayRecentReceiptsProvider =
    Provider<AsyncValue<List<RecentReceipt>>>((ref) => ref
        .watch(todayPaymentsProvider)
        .whenData((List<Payment> p) => recentReceipts(p)));

/// Backup nudge status (F18).
final todayBackupProvider = Provider<AsyncValue<BackupStatus>>((ref) {
  final int nowMs = ref.watch(todayNowMsProvider);
  return combine3(
    ref.watch(_lastExportProvider),
    ref.watch(_backupDaysProvider),
    ref.watch(todayStudentsProvider),
    (int? last, int days, List<Student> students) => backupStatus(
      lastExportMs: last,
      nowMs: nowMs,
      reminderDays: days,
      studentCount:
          students.where((Student s) => s.status == StudentStatus.active).length,
    ),
  );
});

/// Days of class reminders left when fewer than three remain, else `null`.
final todayReminderHintProvider = Provider<AsyncValue<int?>>((ref) {
  final int nowMs = ref.watch(todayNowMsProvider);
  return combine2(
    ref.watch(_remindersEnabledProvider),
    ref.watch(_plannedUntilProvider),
    (bool enabled, int? until) => reminderDaysLeft(
      enabled: enabled,
      plannedUntilMs: until,
      nowMs: nowMs,
    ),
  );
});
