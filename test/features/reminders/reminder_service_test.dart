// ReminderService over the seeded fakes and a fake gateway: scenario 22
// (lead fallback, default change, cancel, extra), scenario 23 (global off),
// scenario 16 (language), horizon + cap, debounce.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/notifications/notification_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/reminders/reminder_service.dart';

import '../../helpers/fixtures.dart';
import 'reminder_test_support.dart';

/// Dhaka wall time [hhmm] on [date] as a UTC instant.
DateTime dhaka(String date, String hhmm) => at(date, hhmm).fixedUtc;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SeededFakes fakes;
  late FakeNotificationGateway gateway;
  late ProviderContainer container;
  late ReminderService service;

  Future<void> boot({Lang lang = Lang.bn}) async {
    fakes = seedFakes(withAttendance: false);
    gateway = FakeNotificationGateway();
    container = reminderContainer(reminderOverrides(fakes, gateway, lang: lang));
    addTearDown(container.dispose);
    container.listen<ReminderService>(reminderServiceProvider, (_, __) {});
    service = container.read(reminderServiceProvider);
    await flush();
    await service.replanNow();
  }

  final String physSat = OccId.regular(kSlotPhysSat, const LocalDate(2026, 11, 21));
  final String chemSun = OccId.regular(kSlotChemSun, const LocalDate(2026, 11, 22));

  group('scenario 22: lead fallback', () {
    test('Physics A (lead null) at 15:45, Chem B (lead 30) at 09:30', () async {
      await boot();
      expect(gateway.forOcc(physSat)?.fireAtUtc, dhaka('2026-11-21', '15:45'));
      expect(gateway.forOcc(chemSun)?.fireAtUtc, dhaka('2026-11-22', '09:30'));
      // Bangla texts from the seed names.
      expect(gateway.forOcc(physSat)?.title, 'পদার্থবিজ্ঞান · ফিজিক্স এ');
      expect(gateway.forOcc(physSat)?.body, 'বিকাল ৪:০০–৫:০০ ক্লাস — ১৫ মিনিট পর');
      expect(gateway.forOcc(chemSun)?.body, 'সকাল ১০:০০–১১:০০ ক্লাস — ৩০ মিনিট পর');
      expect(gateway.channelName, 'ক্লাস রিমাইন্ডার');
      // Planned-until is stored for the Home hint.
      expect(await fakes.settings.get(SettingKeys.remindersPlannedUntil),
          kTestNowUtc.add(const Duration(days: 7)).millisecondsSinceEpoch);
    });

    test('default 10: Physics A moves to 15:50, Chem B stays 09:30', () async {
      await boot();
      await fakes.settings.set(SettingKeys.defaultReminderLead, 10);
      await service.replanNow();
      expect(gateway.forOcc(physSat)?.fireAtUtc, dhaka('2026-11-21', '15:50'));
      expect(gateway.forOcc(physSat)?.body, 'বিকাল ৪:০০–৫:০০ ক্লাস — ১০ মিনিট পর');
      expect(gateway.forOcc(chemSun)?.fireAtUtc, dhaka('2026-11-22', '09:30'));
    });

    test('cancelling the 11-21 class removes its notification', () async {
      await boot();
      await fakes.schedule.cancel(physSat);
      await service.replanNow();
      expect(gateway.forOcc(physSat), isNull);
      expect(gateway.forOcc(chemSun), isNotNull);
    });

    test('an extra Physics A class 11-26 18:00 gets one at 17:50 (default 10)', () async {
      await boot();
      await fakes.settings.set(SettingKeys.defaultReminderLead, 10);
      final String occ = await fakes.schedule.addExtra(
          batchId: kBatPhysA, date: const LocalDate(2026, 11, 26), startMin: 1080, endMin: 1140);
      await service.replanNow();
      final ScheduledNotice? n = gateway.forOcc(occ);
      expect(n?.fireAtUtc, dhaka('2026-11-26', '17:50'));
      expect(n?.body, 'সন্ধ্যা ৬:০০–৭:০০ ক্লাস — ১০ মিনিট পর (অতিরিক্ত ক্লাস)');
    });

    test('batch lead 0 means off for that batch only', () async {
      await boot();
      await fakes.batches.setReminderLead(kBatChemB, 0);
      await service.replanNow();
      expect(gateway.forOcc(chemSun), isNull);
      expect(gateway.forOcc(physSat), isNotNull);
    });
  });

  test('scenario 23: global off schedules nothing; on again restores', () async {
    await boot();
    expect(gateway.scheduled, isNotEmpty);
    await fakes.settings.set(SettingKeys.remindersEnabled, false);
    await service.replanNow();
    expect(gateway.scheduled, isEmpty);
    expect(gateway.cancelCalls, greaterThan(0));
    expect(await fakes.settings.get(SettingKeys.remindersPlannedUntil), isNull);
    await fakes.settings.set(SettingKeys.remindersEnabled, true);
    await service.replanNow();
    expect(gateway.forOcc(physSat), isNotNull);
  });

  test('scenario 16: switching the language re-texts the scheduled reminders', () async {
    await boot();
    expect(gateway.forOcc(physSat)?.body, 'বিকাল ৪:০০–৫:০০ ক্লাস — ১৫ মিনিট পর');
    await container.read(langProvider.notifier).set(Lang.en);
    await service.replanNow();
    expect(gateway.forOcc(physSat)?.body, 'Class 4:00–5:00 PM — in 15 min');
    expect(gateway.forOcc(physSat)?.actionLabel, 'Take attendance');
    expect(gateway.channelName, 'Class reminders');
    await container.read(langProvider.notifier).set(Lang.bn);
    await service.replanNow();
    expect(gateway.forOcc(physSat)?.body, 'বিকাল ৪:০০–৫:০০ ক্লাস — ১৫ মিনিট পর');
  });

  group('horizon and cap', () {
    test('only the next 7 days, fire times in the future, sorted', () async {
      await boot();
      final List<ScheduledNotice> s = gateway.scheduled;
      // Sat 21 Physics, Sun 22 Chem, Mon 23 Physics, Tue 24 Chem, Wed 25
      // Physics; Sat 28 16:00 is beyond now + 7 days (Sat 28 10:00).
      expect(s.length, 5);
      final DateTime horizon = kTestNowUtc.add(const Duration(days: 7));
      for (final ScheduledNotice n in s) {
        expect(n.fireAtUtc.isAfter(kTestNowUtc), isTrue);
        expect(n.fireAtUtc.isBefore(horizon), isTrue);
      }
      for (int i = 1; i < s.length; i++) {
        expect(s[i].fireAtUtc.isBefore(s[i - 1].fireAtUtc), isFalse);
      }
    });

    test('a class earlier today whose fire time passed is skipped', () {
      final List<ScheduledNotice> s = buildReminderNotices(
        schedules: <BatchSchedule>[_dense(1)],
        defaultLeadMin: 15,
        lang: Lang.en,
        center: CenterTime.dhaka,
        nowUtc: kTestNowUtc, // 10:00: the 06:00..10:10 classes are gone
      );
      final DateTime firstAllowed = kTestNowUtc;
      expect(s.every((ScheduledNotice n) => n.fireAtUtc.isAfter(firstAllowed)), isTrue);
    });

    test('capped at the soonest 200', () {
      final List<ScheduledNotice> s = buildReminderNotices(
        schedules: <BatchSchedule>[_dense(1), _dense(2)],
        defaultLeadMin: 15,
        lang: Lang.bn,
        center: CenterTime.dhaka,
        nowUtc: kTestNowUtc,
      );
      expect(s.length, kReminderMaxCount);
      for (int i = 1; i < s.length; i++) {
        expect(s[i].fireAtUtc.isBefore(s[i - 1].fireAtUtc), isFalse);
      }
      expect(s.map((ScheduledNotice n) => n.id).toSet().length, s.length);
    });

    test('archived batches get no reminders', () async {
      await boot();
      await fakes.batches.archive(kBatChemB, on: const LocalDate(2026, 11, 21), lastBillableMonth: _nov);
      await service.replanNow();
      expect(gateway.forOcc(chemSun), isNull);
    });
  });

  testWidgets('changes are debounced 2 s and coalesced', (WidgetTester tester) async {
    final SeededFakes f = seedFakes(withAttendance: false);
    final FakeNotificationGateway g = FakeNotificationGateway();
    final ProviderContainer c = reminderContainer(reminderOverrides(f, g));
    c.listen<ReminderService>(reminderServiceProvider, (_, __) {});
    await tester.pump(const Duration(milliseconds: 1500));
    expect(g.replaceCalls, 0, reason: 'still inside the 2 s quiet time');
    await tester.pump(const Duration(seconds: 1));
    expect(g.replaceCalls, 1, reason: 'start-up replan');

    await f.settings.set(SettingKeys.defaultReminderLead, 20);
    await tester.pump(const Duration(milliseconds: 500));
    await f.schedule.cancel(physSat);
    await tester.pump(const Duration(milliseconds: 500));
    expect(g.replaceCalls, 1);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(g.replaceCalls, 2, reason: 'two quick changes, one replan');
    expect(g.forOcc(physSat), isNull);
    expect(g.forOcc(chemSun)?.fireAtUtc, dhaka('2026-11-22', '09:30'));

    // Back in the foreground: replan.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(g.replaceCalls, 3, reason: 'onResume replans');

    c.dispose();
    await tester.pump();
  });
}

const YearMonth _nov = YearMonth(2026, 11);

/// A batch with a 20-minute class every half hour from 06:00 to 22:30 on
/// every weekday (34 a day, 238 a week).
BatchSchedule _dense(int n) {
  final String id = 'dense-$n';
  return BatchSchedule(
    batch: Batch(
      id: id,
      subjectId: 'sub-$n',
      name: 'D$n',
      billingType: BillingType.prepaid,
      createdOn: const LocalDate(2026, 1, 1),
      sortOrder: n,
    ),
    subjectName: 'S$n',
    slots: <Slot>[
      for (int wd = 1; wd <= 7; wd++)
        for (int start = 360 + (n - 1) * 5; start < 1380; start += 30)
          Slot(id: '$id-$wd-$start', batchId: id, weekday: wd, startMin: start, endMin: start + 20),
    ],
  );
}
