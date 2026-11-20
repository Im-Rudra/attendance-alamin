// Web: browsers cannot schedule notifications for a closed tab (Arch 4B,
// `zonedSchedule` throws on web). While the tab is open a [ReminderTicker]
// holds the planned reminders and emits each one when it comes due; the app
// shows it as an in-app banner. Selected by the conditional import in
// notification_providers.dart; plain Dart, so it is unit-tested on the VM.

import 'dart:async';

import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/data/notifications/notification_gateway.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';

NotificationGateway createNotificationGateway(Clock clock) => WebNotificationGateway(clock);

class WebNotificationGateway implements NotificationGateway, InAppReminderSource {
  WebNotificationGateway(Clock clock)
      : _clock = clock,
        ticker = ReminderTicker(clock);

  final Clock _clock;
  final ReminderTicker ticker;

  @override
  Stream<ScheduledNotice> get dueNotices => ticker.due;

  @override
  Future<void> init({required void Function(String payload) onTap}) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<ReminderPermission> permission() async => ReminderPermission.unsupported;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> requestExact() async => false;

  @override
  Future<void> setChannel({required String name, required String description}) async {}

  @override
  Future<void> replaceAll(List<ScheduledNotice> notices) async => ticker.replace(notices);

  @override
  Future<void> cancelAll() async => ticker.replace(const <ScheduledNotice>[]);

  @override
  Future<void> showNow({required String title, required String body}) async => ticker.emit(
        ScheduledNotice(
          id: 0,
          fireAtUtc: _clock.nowUtc(),
          title: title,
          body: body,
          payload: '',
          actionLabel: '',
        ),
      );

  @override
  void dispose() => ticker.dispose();
}

/// One `Timer`, re-armed to the next planned reminder (background tabs may
/// throttle it to about once a minute, which is fine for a class reminder).
class ReminderTicker {
  ReminderTicker(this._clock);

  final Clock _clock;
  final StreamController<ScheduledNotice> _due = StreamController<ScheduledNotice>.broadcast();
  List<ScheduledNotice> _pending = <ScheduledNotice>[];
  Timer? _timer;

  Stream<ScheduledNotice> get due => _due.stream;

  /// Reminders still to come, soonest first.
  List<ScheduledNotice> get pending => List<ScheduledNotice>.unmodifiable(_pending);

  void replace(List<ScheduledNotice> notices) {
    final DateTime now = _clock.nowUtc();
    _pending = <ScheduledNotice>[
      for (final ScheduledNotice n in notices)
        if (n.fireAtUtc.isAfter(now)) n,
    ]..sort((ScheduledNotice a, ScheduledNotice b) => a.fireAtUtc.compareTo(b.fireAtUtc));
    _arm();
  }

  void emit(ScheduledNotice notice) {
    if (!_due.isClosed) _due.add(notice);
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty || _due.isClosed) return;
    final Duration wait = _pending.first.fireAtUtc.difference(_clock.nowUtc());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, _fire);
  }

  void _fire() {
    final DateTime now = _clock.nowUtc();
    while (_pending.isNotEmpty && !_pending.first.fireAtUtc.isAfter(now)) {
      emit(_pending.removeAt(0));
    }
    _arm();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = <ScheduledNotice>[];
    unawaited(_due.close());
  }
}
