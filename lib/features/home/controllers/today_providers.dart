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
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

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

// ---- place filter (2+ places) -------------------------------------------------

/// [plan] with only the classes of batches at [placeId] ([batchPlaces]: batch
/// id -> place id, for the classes moved away).
DayPlan planAtPlace(DayPlan plan, String placeId, Map<String, String> batchPlaces) => DayPlan(
      date: plan.date,
      classes: <DayClass>[
        for (final DayClass c in plan.classes)
          if (c.batch.placeId == placeId) c,
      ],
      movedAway: <MovedAway>[
        for (final MovedAway m in plan.movedAway)
          if ((batchPlaces[m.batchId] ?? kDefaultPlaceId) == placeId) m,
      ],
    );

/// The day plan of [date] narrowed to the place filter (as is with no
/// place picked).
final todayDayPlanProvider = Provider.family<AsyncValue<DayPlan>, LocalDate>((ref, date) {
  final AsyncValue<DayPlan> plan = ref.watch(dayPlanProvider(date));
  final String? place = ref.watch(placeFilterProvider);
  if (place == null) return plan;
  final Map<String, String> batchPlaces = ref.watch(placeOfBatchProvider);
  return plan.whenData((DayPlan p) => planAtPlace(p, place, batchPlaces));
});

/// The week of [weekStart] narrowed to the place filter.
final todayWeekPlanProvider = Provider.family<AsyncValue<List<DayPlan>>, LocalDate>((ref, weekStart) {
  final AsyncValue<List<DayPlan>> plans = ref.watch(weekPlanProvider(weekStart));
  final String? place = ref.watch(placeFilterProvider);
  if (place == null) return plans;
  final Map<String, String> batchPlaces = ref.watch(placeOfBatchProvider);
  return plans.whenData((List<DayPlan> ps) => <DayPlan>[
        for (final DayPlan p in ps) planAtPlace(p, place, batchPlaces),
      ]);
});

/// Payments of batches at the place filter (all with no place picked).
final todayPlacePaymentsProvider = Provider<AsyncValue<List<Payment>>>((ref) {
  final AsyncValue<List<Payment>> all = ref.watch(todayPaymentsProvider);
  final String? place = ref.watch(placeFilterProvider);
  if (place == null) return all;
  final Map<String, String> batchPlaces = ref.watch(placeOfBatchProvider);
  return all.whenData((List<Payment> ps) => <Payment>[
        for (final Payment p in ps)
          if ((batchPlaces[p.batchId] ?? kDefaultPlaceId) == place) p,
      ]);
});

// ---- derived -----------------------------------------------------------------

/// The hero card of [date].
final todayHeroProvider =
    Provider.family<AsyncValue<HeroState>, LocalDate>((ref, date) {
  final LocalDate today = ref.watch(todayProvider);
  final int nowMin = ref.watch(nowMinutesProvider);
  return combine2(
    ref.watch(todayBatchesProvider),
    ref.watch(todayDayPlanProvider(date)),
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
            .watch(todayDayPlanProvider(date))
            .whenData((DayPlan p) => buildDayAttendance(p.classes)));

/// This month's collection (of the filtered place, if any).
final todayCollectionProvider = Provider<AsyncValue<MonthCollection>>((ref) {
  final LocalDate today = ref.watch(todayProvider);
  final String? place = ref.watch(placeFilterProvider);
  return combine3(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    ref.watch(todayPlacePaymentsProvider),
    (List<EnrollmentTerms> terms, List<PaymentFact> facts, List<Payment> payments) => buildMonthCollection(
      today: today,
      terms: termsAtPlace(terms, place),
      facts: facts,
      payments: payments,
    ),
  );
});

/// The last five receipts (of the filtered place, if any).
final todayRecentReceiptsProvider =
    Provider<AsyncValue<List<RecentReceipt>>>((ref) => ref
        .watch(todayPlacePaymentsProvider)
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
