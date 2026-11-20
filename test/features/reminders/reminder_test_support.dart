// Shared test support for the reminders feature: a scriptable notification
// gateway and a container wired to the seeded fakes.

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/notifications/notification_providers.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/features/reminders/reminder_service.dart';

import '../../helpers/fixtures.dart';

class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway({this.perm = ReminderPermission.granted});

  ReminderPermission perm;

  /// Permission after [requestPermission] / [requestExact].
  ReminderPermission? afterRequest;
  ReminderPermission? afterExact;

  String? launch;
  void Function(String payload)? onTap;
  List<ScheduledNotice> scheduled = <ScheduledNotice>[];
  final List<(String, String)> shown = <(String, String)>[];
  String? channelName;
  int initCalls = 0;
  int replaceCalls = 0;
  int cancelCalls = 0;
  int permissionRequests = 0;
  int exactRequests = 0;

  @override
  Future<void> init({required void Function(String payload) onTap}) async {
    initCalls++;
    this.onTap = onTap;
  }

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<ReminderPermission> permission() async => perm;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    perm = afterRequest ?? perm;
    return perm == ReminderPermission.granted || perm == ReminderPermission.exactDenied;
  }

  @override
  Future<bool> requestExact() async {
    exactRequests++;
    perm = afterExact ?? perm;
    return perm == ReminderPermission.granted;
  }

  @override
  Future<void> setChannel({required String name, required String description}) async => channelName = name;

  @override
  Future<void> replaceAll(List<ScheduledNotice> notices) async {
    replaceCalls++;
    scheduled = List<ScheduledNotice>.of(notices);
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
    scheduled = <ScheduledNotice>[];
  }

  @override
  Future<void> showNow({required String title, required String body}) async => shown.add((title, body));

  /// The scheduled notice of [occ], if any.
  ScheduledNotice? forOcc(String occ) {
    for (final ScheduledNotice n in scheduled) {
      if (n.payload == 'rollcall|$occ') return n;
    }
    return null;
  }
}

/// Overrides for a container / pumpApp: seeded fakes, the fake gateway, the
/// app version and the device preferences.
List<Override> reminderOverrides(
  SeededFakes fakes,
  FakeNotificationGateway gateway, {
  Lang lang = Lang.bn,
  String version = '1.0.0+5',
}) =>
    <Override>[
      ...fakes.overrides,
      notificationGatewayProvider.overrideWithValue(gateway),
      reminderAppVersionProvider.overrideWith((Ref ref) async => version),
      initialPrefsProvider.overrideWithValue(AppPrefs(
        lang: lang,
        themeMode: ThemeMode.light,
        reducedEffects: true,
        onboardingDone: true,
      )),
    ];

/// A container at [nowUtc] (default 2026-11-21 10:00 Dhaka) whose minute
/// tick never starts a timer. Dispose it yourself (`container.dispose()`).
ProviderContainer reminderContainer(List<Override> overrides, {DateTime? nowUtc}) => ProviderContainer(
      retry: (int _, Object __) => null,
      overrides: <Override>[
        clockProvider.overrideWithValue(FixedClock(nowUtc ?? kTestNowUtc)),
        minuteTickProvider.overrideWith((Ref ref) => Stream<int>.value(
            ref.watch(centerTimeProvider).minutesNow(ref.watch(clockProvider)))),
        ...overrides,
      ],
    );

/// Lets pending microtasks / fake-stream events run.
Future<void> flush([int turns = 10]) async {
  for (int i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
