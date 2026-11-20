import 'dart:async';

import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the center's minute-of-day (0..1439) now and again at every
/// wall-clock minute boundary of [clockProvider]. Tests that must not leave a
/// timer behind override it with a plain `Stream.value`.
final minuteTickProvider = StreamProvider<int>((ref) {
  final clock = ref.watch(clockProvider);
  final center = ref.watch(centerTimeProvider);
  final controller = StreamController<int>();
  Timer? timer;

  void schedule() {
    final ms = clock.nowUtc().millisecondsSinceEpoch;
    final wait = 60000 - (ms % 60000);
    timer = Timer(Duration(milliseconds: wait), () {
      if (controller.isClosed) return;
      controller.add(center.minutesNow(clock));
      schedule();
    });
  }

  controller.add(center.minutesNow(clock));
  schedule();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// The center's date. Always read "today" from here (plan 2.9); it follows the
/// [clockProvider] and re-evaluates every minute, so it rolls over at midnight.
final todayProvider = Provider<LocalDate>((ref) {
  ref.watch(minuteTickProvider);
  return ref.watch(centerTimeProvider).today(ref.watch(clockProvider));
});

/// The center's minute of day (0..1439), updated every minute.
final nowMinutesProvider = Provider<int>((ref) {
  ref.watch(minuteTickProvider);
  return ref.watch(centerTimeProvider).minutesNow(ref.watch(clockProvider));
});

/// ISO weekday (6 Sat, 7 Sun, 1 Mon) the week starts on (`SettingKeys.weekStart`).
final weekStartProvider = StreamProvider<int>(
    (ref) => ref.watch(settingsRepositoryProvider).watch(SettingKeys.weekStart));
