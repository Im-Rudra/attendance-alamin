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

  testWidgets('emits each reminder when due, in order, and skips past ones', (WidgetTester tester) async {
    final _Clock clock = _Clock(t0);
    final WebNotificationGateway g = WebNotificationGateway(clock);
    final List<int> due = <int>[];
    final sub = g.dueNotices.listen((ScheduledNotice n) => due.add(n.id));

    await g.replaceAll(<ScheduledNotice>[
      _notice(2, t0.add(const Duration(seconds: 3))),
      _notice(1, t0.add(const Duration(seconds: 1))),
      _notice(9, t0.subtract(const Duration(seconds: 1))),
    ]);
    expect(g.ticker.pending.map((ScheduledNotice n) => n.id), <int>[1, 2]);

    clock.now = t0.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(due, <int>[1]);

    clock.now = t0.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    expect(due, <int>[1, 2]);
    expect(g.ticker.pending, isEmpty);

    await sub.cancel();
    g.dispose();
  });

  testWidgets('replacing or cancelling drops what was pending', (WidgetTester tester) async {
    final _Clock clock = _Clock(t0);
    final WebNotificationGateway g = WebNotificationGateway(clock);
    final List<int> due = <int>[];
    final sub = g.dueNotices.listen((ScheduledNotice n) => due.add(n.id));
    await g.replaceAll(<ScheduledNotice>[_notice(1, t0.add(const Duration(seconds: 1)))]);
    await g.cancelAll();
    clock.now = t0.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(due, isEmpty);
    await sub.cancel();
    g.dispose();
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
