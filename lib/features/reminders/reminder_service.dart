// Keeps the OS's class reminders in step with the schedule (Product 3.11,
// Arch 4B, plan M8-D).
//
// The service plans the next 7 days with the M2-C planner over the live
// schedules, the per-batch leads, the default lead, the global switch and the
// app language, then hands the localised notices to the gateway
// (cancel-all + reschedule, idempotent, <= 200 items). It replans 2 s after
// any of those inputs changes (debounced), when the date rolls over, and when
// the app comes back to the foreground. It is created and kept alive by
// `initRemindersAndGetLaunchRoute` (app/services/reminder_bootstrap.dart).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/notifications/notification_providers.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/domain/reminders/reminder_planner.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_engine.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/reminders/reminder_texts.dart';

/// Reminder horizon in days (plan section 1 #2).
const int kReminderHorizonDays = 7;

/// At most this many reminders are handed to the OS (OEM alarm caps).
const int kReminderMaxCount = 200;

/// Quiet time after the last change before replanning.
const Duration kReminderReplanDebounce = Duration(seconds: 2);

/// `local_meta` key: JSON `{occ: batchId}` of recently planned reminders, so a
/// tap on a reminder whose extra class was deleted after it fired still finds
/// its batch.
const String kReminderPlannedMetaKey = 'reminders_planned_occs';

/// How many occurrence -> batch entries [kReminderPlannedMetaKey] keeps.
const int _kPlannedMemory = 400;

/// Version text the priming screen is remembered against ("1.0.0+12");
/// `unknown` when the platform can't tell.
final reminderAppVersionProvider = FutureProvider<String>((Ref ref) async {
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    final String build = info.buildNumber.trim();
    return build.isEmpty ? info.version : '${info.version}+$build';
  } on Object {
    return 'unknown';
  }
});

final remindersEnabledSettingProvider = StreamProvider<bool>(
    (Ref ref) => ref.watch(settingsRepositoryProvider).watch(SettingKeys.remindersEnabled));

final reminderDefaultLeadProvider = StreamProvider<int>(
    (Ref ref) => ref.watch(settingsRepositoryProvider).watch(SettingKeys.defaultReminderLead));

/// The running service (kept alive by the reminder bootstrap).
final reminderServiceProvider = Provider<ReminderService>((Ref ref) {
  final ReminderService service = ReminderService(ref);
  ref.onDispose(service.dispose);
  service.start();
  return service;
});

/// Localised notices for the reminders of the next [kReminderHorizonDays]
/// days: cancels, reschedules and extras applied, archived batches skipped,
/// lead `null` = [defaultLeadMin], lead 0 = off, fire times in the past
/// skipped, soonest [kReminderMaxCount] kept.
List<ScheduledNotice> buildReminderNotices({
  required List<BatchSchedule> schedules,
  required int defaultLeadMin,
  required Lang lang,
  required CenterTime center,
  required DateTime nowUtc,
}) {
  final LocalDate today = LocalDate.fromUtc(nowUtc, center.offsetMin);
  final List<Occurrence> occurrences = ScheduleEngine.expand(
    range: DateRange(today, today.addDays(kReminderHorizonDays)),
    batches: schedules,
  ).occurrences;
  final Map<String, BatchSchedule> byBatch = <String, BatchSchedule>{
    for (final BatchSchedule s in schedules) s.batch.id: s,
  };
  final List<PlannedReminder> planned = ReminderPlanner.plan(
    occurrences: occurrences,
    leadByBatch: <String, int?>{
      for (final BatchSchedule s in schedules) s.batch.id: s.batch.reminderLeadMin,
    },
    defaultLeadMin: defaultLeadMin,
    center: center,
    nowUtc: nowUtc,
    windowDays: kReminderHorizonDays,
    maxCount: kReminderMaxCount,
  );
  final ReminderTexts texts = ReminderTexts(lang);
  return <ScheduledNotice>[
    for (final PlannedReminder r in planned)
      if (byBatch[r.batchId] case final BatchSchedule bs)
        texts.notice(r, subject: bs.subjectName, batch: bs.batch.name),
  ];
}

class ReminderService {
  ReminderService(this._ref);

  final Ref _ref;
  Timer? _debounce;
  AppLifecycleListener? _lifecycle;
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;

  /// The notices handed to the gateway by the last replan.
  List<ScheduledNotice> lastNotices = const <ScheduledNotice>[];

  void start() {
    _ref.listen<AsyncValue<List<BatchSchedule>>>(schedulesProvider, (_, __) => requestReplan());
    _ref.listen<AsyncValue<bool>>(remindersEnabledSettingProvider, (_, __) => requestReplan());
    _ref.listen<AsyncValue<int>>(reminderDefaultLeadProvider, (_, __) => requestReplan());
    _ref.listen<Lang>(langProvider, (Lang? a, Lang b) {
      if (a != b) requestReplan();
    });
    // Roll the 7-day window forward once a day.
    _ref.listen<LocalDate>(todayProvider, (LocalDate? a, LocalDate b) {
      if (a != b) requestReplan();
    });
    try {
      _lifecycle = AppLifecycleListener(onResume: requestReplan);
    } on Object {
      _lifecycle = null; // no binding (pure unit tests)
    }
    requestReplan();
  }

  /// Replans [kReminderReplanDebounce] after the last call.
  void requestReplan() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(kReminderReplanDebounce, () => unawaited(replanNow()));
  }

  /// Replans at once (a replan already running is followed by one more).
  Future<void> replanNow() {
    if (_disposed) return Future<void>.value();
    _debounce?.cancel();
    final Future<void>? running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final Future<void> f = _loop();
    _running = f;
    return f.whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      try {
        await _replanOnce();
      } on Object {
        // Never crash the app over reminders; the next change replans.
      }
    } while (_again && !_disposed);
  }

  Future<void> _replanOnce() async {
    final settings = _ref.read(settingsRepositoryProvider);
    final NotificationGateway gateway = _ref.read(notificationGatewayProvider);
    final bool enabled = await settings.get(SettingKeys.remindersEnabled);
    if (_disposed) return;
    if (!enabled) {
      lastNotices = const <ScheduledNotice>[];
      await gateway.cancelAll();
      if (_disposed) return;
      await settings.set<int?>(SettingKeys.remindersPlannedUntil, null);
      return;
    }
    final List<BatchSchedule> schedules = await _ref.read(schedulesProvider.future);
    final int defaultLead = await settings.get(SettingKeys.defaultReminderLead);
    if (_disposed) return;
    final Lang lang = _ref.read(langProvider);
    final DateTime now = _ref.read(clockProvider).nowUtc();
    final List<ScheduledNotice> notices = buildReminderNotices(
      schedules: schedules,
      defaultLeadMin: defaultLead,
      lang: lang,
      center: _ref.read(centerTimeProvider),
      nowUtc: now,
    );
    final ReminderTexts texts = ReminderTexts(lang);
    await gateway.setChannel(
        name: texts.l10n.remindChannelName, description: texts.l10n.remindChannelDescription);
    await gateway.replaceAll(notices);
    lastNotices = List<ScheduledNotice>.unmodifiable(notices);
    if (_disposed) return;
    await settings.set<int?>(SettingKeys.remindersPlannedUntil,
        now.add(const Duration(days: kReminderHorizonDays)).millisecondsSinceEpoch);
    if (_disposed) return;
    await _rememberPlanned(_ref.read(localMetaRepositoryProvider), notices, schedules);
  }

  Future<void> _rememberPlanned(
      LocalMetaRepository meta, List<ScheduledNotice> notices, List<BatchSchedule> schedules) async {
    final Map<String, String> map = await readPlannedOccs(meta);
    final _OccBatchLookup lookup = _OccBatchLookup(schedules);
    for (final ScheduledNotice n in notices) {
      final String? occ = ReminderPlanner.occFromPayload(n.payload);
      if (occ == null) continue;
      final String? batchId = lookup.batchOf(occ);
      if (batchId == null) continue;
      map.remove(occ);
      map[occ] = batchId; // newest last
    }
    while (map.length > _kPlannedMemory) {
      map.remove(map.keys.first);
    }
    await meta.setRaw(kReminderPlannedMetaKey, jsonEncode(map));
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _debounce = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}

/// Batch of an occurrence id (Arch 3.2a), from the slots / exceptions.
class _OccBatchLookup {
  _OccBatchLookup(List<BatchSchedule> schedules) {
    for (final BatchSchedule s in schedules) {
      for (final Slot slot in s.slots) {
        _bySlot[slot.id] = s.batch.id;
      }
      for (final ScheduleException e in s.exceptions) {
        _byException[e.id] = s.batch.id;
      }
    }
  }

  final Map<String, String> _bySlot = <String, String>{};
  final Map<String, String> _byException = <String, String>{};

  String? batchOf(String occ) {
    try {
      return switch (OccId.parse(occ)) {
        RegularOccRef(:final String slotId) => _bySlot[slotId],
        ExtraOccRef(:final String exceptionId) => _byException[exceptionId],
      };
    } on FormatException {
      return null;
    }
  }
}

/// The remembered `{occ: batchId}` map (empty when missing or unreadable).
Future<Map<String, String>> readPlannedOccs(LocalMetaRepository meta) async {
  try {
    final String? raw = await meta.getRaw(kReminderPlannedMetaKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, String>{};
    return <String, String>{
      for (final MapEntry<Object?, Object?> e in decoded.entries)
        if (e case MapEntry<Object?, Object?>(key: final String k, value: final String v)) k: v,
    };
  } on Object {
    return <String, String>{};
  }
}

/// Where a reminder tap leads.
class ReminderTapTarget {
  const ReminderTapTarget(this.route, {this.cancelled = false});

  final String route;

  /// The class was cancelled (or deleted) after the reminder fired: show
  /// "এই ক্লাস বাতিল" on arrival.
  final bool cancelled;

  @override
  bool operator ==(Object other) =>
      other is ReminderTapTarget && other.route == route && other.cancelled == cancelled;

  @override
  int get hashCode => Object.hash(route, cancelled);

  @override
  String toString() => 'ReminderTapTarget($route, cancelled: $cancelled)';
}

/// Resolves a notification payload (`rollcall|<occ>`): the occurrence's roll
/// call when it still takes place, else its batch (schedule) with the
/// cancelled note, else Today with the note. Null for a payload that is not a
/// reminder.
Future<ReminderTapTarget?> resolveReminderTap(
  String payload, {
  required ScheduleRepository schedule,
  required LocalMetaRepository meta,
}) async {
  final String? occ = ReminderPlanner.occFromPayload(payload);
  if (occ == null) return null;
  OccurrenceInfo? info;
  try {
    info = await schedule.resolve(occ);
  } on Object {
    info = null;
  }
  if (info != null && !info.cancelled && info.occurrence != null) {
    return ReminderTapTarget(Routes.rollCall(occ));
  }
  final String? batchId = info?.batch.id ?? (await readPlannedOccs(meta))[occ];
  return ReminderTapTarget(batchId == null ? Routes.today : Routes.batch(batchId), cancelled: true);
}
