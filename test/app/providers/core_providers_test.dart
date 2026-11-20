import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import '../../helpers/pump_app.dart';

class _MutableClock implements Clock {
  _MutableClock(this.now);

  DateTime now;

  @override
  DateTime nowUtc() => now;
}

void main() {
  test('todayProvider and nowMinutesProvider follow the fixed clock', () {
    final c = makeContainer(nowUtc: at('2026-11-05', '10:15').fixedUtc);
    expect(c.read(todayProvider), const LocalDate(2026, 11, 5));
    expect(c.read(nowMinutesProvider), 10 * 60 + 15);
  });

  test('the date is the center date, not the UTC date (UTC+6)', () {
    // 18:30 UTC on the 21st is 00:30 on the 22nd in Dhaka.
    final c = makeContainer(nowUtc: DateTime.utc(2026, 11, 21, 18, 30));
    expect(c.read(todayProvider), const LocalDate(2026, 11, 22));
    expect(c.read(nowMinutesProvider), 30);
  });

  test('default harness clock is 2026-11-21 10:00', () {
    final c = makeContainer();
    expect(c.read(todayProvider), const LocalDate(2026, 11, 21));
    expect(c.read(nowMinutesProvider), 600);
  });

  testWidgets('minuteTickProvider emits at each wall-clock minute', (tester) async {
    // 10:00:30 center time.
    final clock = _MutableClock(DateTime.utc(2026, 11, 21, 4, 0, 30));
    final c = ProviderContainer(
      retry: (_, __) => null,
      overrides: [clockProvider.overrideWithValue(clock)],
    );
    try {
      final seen = <int>[];
      c.listen<AsyncValue<int>>(minuteTickProvider, (_, next) {
        final v = next.value;
        if (v != null) seen.add(v);
      }, fireImmediately: true);
      await tester.pump();
      expect(seen, [600]);

      // The timer fires 30 s later, when the wall clock reads 10:01:00.
      clock.now = DateTime.utc(2026, 11, 21, 4, 1);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(seen, [600, 601]);
      expect(c.read(nowMinutesProvider), 601);
    } finally {
      c.dispose();
    }
  });

  test('weekStartProvider reads the setting and follows changes', () async {
    final settings = FakeSettingsRepository();
    final c = makeContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)]);
    expect(await readData(c, weekStartProvider), 6);
    await settings.set(SettingKeys.weekStart, 7);
    expect(await readData(c, weekStartProvider), 7);
  });
}
