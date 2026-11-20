// Scenario 23 routing: a reminder tap opens that exact occurrence's roll call
// (cold start via the launch route, warm via the tap callback); a class
// cancelled after its reminder fired opens the batch with "এই ক্লাস বাতিল".

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/services/reminder_bootstrap.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/reminders/reminder_planner.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/features/reminders/reminder_service.dart';

import '../../features/reminders/reminder_test_support.dart';
import '../../helpers/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final String physMon = OccId.regular(kSlotPhysMon, const LocalDate(2026, 11, 23));

  late SeededFakes fakes;
  late FakeNotificationGateway gateway;
  late List<String> routes;
  late List<String> notes;

  ProviderContainer boot({String? launch, Lang lang = Lang.bn}) {
    fakes = seedFakes(withAttendance: false);
    gateway = FakeNotificationGateway()..launch = launch;
    routes = <String>[];
    notes = <String>[];
    final ProviderContainer c = reminderContainer(<Override>[
      ...reminderOverrides(fakes, gateway, lang: lang),
      reminderNavigatorProvider.overrideWithValue(routes.add),
      reminderNoteProvider.overrideWithValue(notes.add),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('cold start', () {
    test('the launching reminder opens its roll call', () async {
      final ProviderContainer c = boot(launch: ReminderPlanner.payloadFor(physMon));
      final String? route = await initRemindersAndGetLaunchRoute(c);
      expect(route, Routes.rollCall(physMon));
      expect(route, '/rollcall/s.$kSlotPhysMon.20261123');
      expect(gateway.initCalls, 1);
      expect(notes, isEmpty);
      expect(c.exists(reminderServiceProvider), isTrue, reason: 'service kept alive');
    });

    test('no launching notification: no route', () async {
      final ProviderContainer c = boot();
      expect(await initRemindersAndGetLaunchRoute(c), isNull);
    });

    test('cancelled after it fired: the batch with a note', () async {
      final ProviderContainer c = boot(launch: ReminderPlanner.payloadFor(physMon));
      await fakes.schedule.cancel(physMon);
      expect(await initRemindersAndGetLaunchRoute(c), Routes.batch(kBatPhysA));
      expect(notes, <String>['এই ক্লাস বাতিল']);
    });

    test('a payload that is not a reminder is ignored', () async {
      final ProviderContainer c = boot(launch: 'something-else');
      expect(await initRemindersAndGetLaunchRoute(c), isNull);
    });
  });

  group('warm tap', () {
    test('opens the roll call of that occurrence', () async {
      final ProviderContainer c = boot();
      await initRemindersAndGetLaunchRoute(c);
      gateway.onTap!(ReminderPlanner.payloadFor(physMon));
      await flush();
      expect(routes, <String>[Routes.rollCall(physMon)]);
      expect(notes, isEmpty);
    });

    test('cancelled after it fired: batch schedule + note (English)', () async {
      final ProviderContainer c = boot(lang: Lang.en);
      await initRemindersAndGetLaunchRoute(c);
      await fakes.schedule.cancel(physMon);
      gateway.onTap!(ReminderPlanner.payloadFor(physMon));
      await flush();
      expect(routes, <String>[Routes.batch(kBatPhysA)]);
      expect(notes, <String>['This class was cancelled']);
    });

    test('a deleted extra class still finds its batch through the remembered plan', () async {
      final ProviderContainer c = boot();
      await initRemindersAndGetLaunchRoute(c);
      final String extra = await fakes.schedule.addExtra(
          batchId: kBatChemB, date: const LocalDate(2026, 11, 25), startMin: 1080, endMin: 1140);
      await c.read(reminderServiceProvider).replanNow();
      expect(gateway.forOcc(extra), isNotNull);
      // It fires, then the teacher deletes the extra class, then taps.
      await fakes.schedule.cancel(extra);
      gateway.onTap!(ReminderPlanner.payloadFor(extra));
      await flush();
      expect(routes, <String>[Routes.batch(kBatChemB)]);
      expect(notes, <String>['এই ক্লাস বাতিল']);
    });
  });

  group('resolveReminderTap', () {
    test('an unknown occurrence goes to Today with the note', () async {
      boot();
      final ReminderTapTarget? t = await resolveReminderTap(
        ReminderPlanner.payloadFor('x.gone'),
        schedule: fakes.schedule,
        meta: fakes.localMeta,
      );
      expect(t, const ReminderTapTarget(Routes.today, cancelled: true));
    });
  });
}
