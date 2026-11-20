// Web fallback: no OS scheduling; the ReminderTicker emits each reminder when
// it comes due while the tab is open.

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/data/notifications/notification_gateway.dart';
import 'package:attendance_alamin/data/notifications/notification_gateway_web.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';

class _Clock implements Clock {
  _Clock(this.now);

  DateTime now;

  @override
  DateTime nowUtc() => now;
}

/// [start] plus the real time elapsed since construction.
class _RunningClock implements Clock {
  _RunningClock(this.start) : _watch = Stopwatch()..start();

  final DateTime start;
  final Stopwatch _watch;

  @override
  DateTime nowUtc() => start.add(_watch.elapsed);
}

ScheduledNotice _notice(int id, DateTime at) => ScheduledNotice(
      id: id,
      fireAtUtc: at,
      title: 't$id',
      body: 'b$id',
      payload: 'rollcall|x.$id',
      actionLabel: 'go',
    );

void main() {
  final DateTime t0 = DateTime.utc(2026, 11, 21, 4);

  // Real (short) timers against a clock that follows a stopwatch.
  test('emits each reminder when due, in order, and skips past ones', () async {
    final _RunningClock clock = _RunningClock(t0);
    final WebNotificationGateway g = WebNotificationGateway(clock);
    addTearDown(g.dispose);
    final List<int> due = <int>[];
    g.dueNotices.listen((ScheduledNotice n) => due.add(n.id));

    await g.replaceAll(<ScheduledNotice>[
      _notice(2, t0.add(const Duration(milliseconds: 600))),
      _notice(1, t0.add(const Duration(milliseconds: 200))),
      _notice(9, t0.subtract(const Duration(seconds: 1))),
    ]);
    expect(g.ticker.pending.map((ScheduledNotice n) => n.id), <int>[1, 2]);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(due, <int>[1]);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(due, <int>[1, 2]);
    expect(g.ticker.pending, isEmpty);
  });

  test('replacing or cancelling drops what was pending', () async {
    final WebNotificationGateway g = WebNotificationGateway(_RunningClock(t0));
    addTearDown(g.dispose);
    final List<int> due = <int>[];
    g.dueNotices.listen((ScheduledNotice n) => due.add(n.id));
    await g.replaceAll(<ScheduledNotice>[_notice(1, t0.add(const Duration(milliseconds: 100)))]);
    await g.cancelAll();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(due, isEmpty);
    expect(g.ticker.pending, isEmpty);
  });

  test('web has no OS permission, launch payload or exact alarms', () async {
    final WebNotificationGateway g = WebNotificationGateway(_Clock(t0));
    expect(await g.permission(), ReminderPermission.unsupported);
    expect(await g.requestPermission(), isFalse);
    expect(await g.requestExact(), isFalse);
    expect(await g.launchPayload(), isNull);
    g.dispose();
  });

  test('showNow surfaces at once as an in-app notice', () async {
    final WebNotificationGateway g = WebNotificationGateway(_Clock(t0));
    final Future<ScheduledNotice> first = g.dueNotices.first;
    await g.showNow(title: 'T', body: 'B');
    final ScheduledNotice n = await first;
    expect((n.title, n.body, n.payload), ('T', 'B', ''));
    g.dispose();
  });
}
