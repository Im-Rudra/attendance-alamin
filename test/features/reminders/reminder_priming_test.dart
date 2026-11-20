// Priming screen (UX 2h): 8-case matrix, asked at most once per app version,
// the exact-alarm second card, and the entry functions used by Settings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/features/reminders/reminders_entry.dart';
import 'package:attendance_alamin/features/reminders/ui/reminder_priming_screen.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';
import 'reminder_test_support.dart';

/// A button that runs [action] with a context under the app.
class _Launcher extends StatelessWidget {
  const _Launcher(this.action);

  final Future<void> Function(BuildContext context) action;

  @override
  Widget build(BuildContext context) => Center(
        child: ElevatedButton(
          key: const Key('launch'),
          onPressed: () => action(context),
          child: const Text('go'),
        ),
      );
}

void main() {
  testScreenMatrix(
    'ReminderPrimingScreen',
    () => const ReminderPrimingScreen(),
    overrides: () => reminderOverrides(
        seedFakes(withAttendance: false), FakeNotificationGateway(perm: ReminderPermission.denied)),
    verify: (WidgetTester tester) async {
      expect(find.byKey(const Key('remind-priming-primary')), findsOneWidget);
      expect(find.byKey(const Key('remind-priming-secondary')), findsOneWidget);
    },
  );

  group('showReminderPriming', () {
    late SeededFakes fakes;
    late FakeNotificationGateway gateway;
    late List<bool> results;

    Future<void> pump(WidgetTester tester, {ReminderPermission perm = ReminderPermission.denied}) async {
      fakes = seedFakes(withAttendance: false);
      gateway = FakeNotificationGateway(perm: perm);
      results = <bool>[];
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async => results.add(await showReminderPriming(c))),
        overrides: reminderOverrides(fakes, gateway),
      );
    }

    Future<void> launch(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('launch')));
      await tester.pumpAndSettle();
    }

    testWidgets('explains in Bangla, then asks; "yes" grants', (WidgetTester tester) async {
      await pump(tester);
      gateway.afterRequest = ReminderPermission.granted;
      await launch(tester);
      expect(find.byType(ReminderPrimingScreen), findsOneWidget);
      expect(find.text('ক্লাসের আগে মনে করিয়ে দেব'), findsOneWidget);
      expect(find.text('প্রতিটি ক্লাসের ১৫ মিনিট আগে ফোনে একটি নোটিফিকেশন আসবে'), findsOneWidget);
      expect(await fakes.settings.get(SettingKeys.notifPromptedVersion), '1.0.0+5');
      await tester.tap(find.text('হ্যাঁ, চালু করুন'));
      await tester.pumpAndSettle();
      expect(gateway.permissionRequests, 1);
      expect(find.byType(ReminderPrimingScreen), findsNothing);
      expect(results, <bool>[true]);
    });

    testWidgets('shown at most once per app version', (WidgetTester tester) async {
      await pump(tester);
      await launch(tester);
      expect(find.byType(ReminderPrimingScreen), findsOneWidget);
      await tester.tap(find.text('এখন না'));
      await tester.pumpAndSettle();
      expect(results, <bool>[false]);
      expect(gateway.permissionRequests, 0);

      // Same version: no priming screen again; a tap goes straight to the OS.
      await launch(tester);
      expect(find.byType(ReminderPrimingScreen), findsNothing);
      expect(gateway.permissionRequests, 1);
      expect(results, <bool>[false, false]);

      // A new app version may explain once more.
      await fakes.settings.set(SettingKeys.notifPromptedVersion, '1.0.0+4');
      await launch(tester);
      expect(find.byType(ReminderPrimingScreen), findsOneWidget);
    });

    testWidgets('already allowed or unsupported: no screen', (WidgetTester tester) async {
      await pump(tester, perm: ReminderPermission.granted);
      await launch(tester);
      expect(find.byType(ReminderPrimingScreen), findsNothing);
      expect(results, <bool>[true]);
      expect(await fakes.settings.get(SettingKeys.notifPromptedVersion), '');
    });

    testWidgets('denied in the OS prompt: plain message, no loop', (WidgetTester tester) async {
      await pump(tester);
      gateway.afterRequest = ReminderPermission.denied;
      await launch(tester);
      await tester.tap(find.byKey(const Key('remind-priming-primary')));
      await tester.pumpAndSettle();
      expect(find.textContaining('অনুমতি পাওয়া যায়নি'), findsOneWidget);
      await tester.tap(find.byKey(const Key('remind-priming-primary')));
      await tester.pumpAndSettle();
      expect(results, <bool>[false]);
      expect(gateway.permissionRequests, 1);
    });

    testWidgets('exact alarms blocked: second card opens the setting once', (WidgetTester tester) async {
      await pump(tester);
      gateway
        ..afterRequest = ReminderPermission.exactDenied
        ..afterExact = ReminderPermission.granted;
      await launch(tester);
      await tester.tap(find.byKey(const Key('remind-priming-primary')));
      await tester.pumpAndSettle();
      expect(find.text('আরেকটি অনুমতি'), findsOneWidget);
      await tester.tap(find.text('সেটিংস খুলুন'));
      await tester.pumpAndSettle();
      expect(gateway.exactRequests, 1);
      expect(await fakes.settings.get(SettingKeys.exactPromptedVersion), '1.0.0+5');
      expect(find.text('সব ঠিক আছে'), findsOneWidget);
      await tester.tap(find.byKey(const Key('remind-priming-primary')));
      await tester.pumpAndSettle();
      expect(results, <bool>[true]);
    });
  });

  group('entry functions', () {
    testWidgets('sendTestReminder shows a sample notification now', (WidgetTester tester) async {
      final SeededFakes fakes = seedFakes(withAttendance: false);
      final FakeNotificationGateway gateway = FakeNotificationGateway();
      await pumpApp(tester, _Launcher(sendTestReminder), overrides: reminderOverrides(fakes, gateway));
      await tester.tap(find.byKey(const Key('launch')));
      await tester.pump();
      await tester.pump();
      expect(gateway.shown, <(String, String)>[('ক্লাস রিমাইন্ডার', 'এটি একটি টেস্ট রিমাইন্ডার — সব ঠিক আছে')]);
      expect(find.text('টেস্ট রিমাইন্ডার পাঠানো হয়েছে'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('sendTestReminder without permission says so', (WidgetTester tester) async {
      final FakeNotificationGateway gateway = FakeNotificationGateway(perm: ReminderPermission.denied);
      await pumpApp(tester, _Launcher(sendTestReminder),
          overrides: reminderOverrides(seedFakes(withAttendance: false), gateway));
      await tester.tap(find.byKey(const Key('launch')));
      await tester.pump();
      await tester.pump();
      expect(gateway.shown, isEmpty);
      expect(find.text('টেস্ট রিমাইন্ডার পাঠানো গেল না — অনুমতি দেখুন'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('reminderPermissionProvider reads the gateway', (WidgetTester tester) async {
      final FakeNotificationGateway gateway = FakeNotificationGateway(perm: ReminderPermission.exactDenied);
      await pumpApp(tester, const SizedBox.shrink(),
          overrides: reminderOverrides(seedFakes(withAttendance: false), gateway));
      final ProviderContainer c = containerOf(tester);
      expect(await c.read(reminderPermissionProvider.future), ReminderPermission.exactDenied);
    });
  });
}
