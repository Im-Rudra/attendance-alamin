// The OS notification boundary (plan M8-D, Arch 4B). Features talk to it only
// through `notification_providers.dart`; only this folder imports
// flutter_local_notifications / timezone.

import 'package:attendance_alamin/domain/reminders/reminder_models.dart';

/// Schedules, cancels and shows class reminders on this device.
///
/// Implementations never throw for "not supported here": they quietly do
/// nothing and report [ReminderPermission.unsupported].
abstract interface class NotificationGateway {
  /// Registers the plugin (Android channel icon, Windows AUMID). [onTap] gets
  /// the payload of a notification tapped while the app runs.
  Future<void> init({required void Function(String payload) onTap});

  /// Payload of the notification that cold-started the app, else null.
  Future<String?> launchPayload();

  Future<ReminderPermission> permission();

  /// Android 13+ POST_NOTIFICATIONS prompt; true when granted.
  Future<bool> requestPermission();

  /// Android "Alarms & reminders" (exact alarms) setting; true when allowed.
  Future<bool> requestExact();

  /// Localised channel name / description (Android settings). Called before
  /// every [replaceAll] / [showNow] so a language change reaches it.
  Future<void> setChannel({required String name, required String description});

  /// Cancels every pending reminder and schedules [notices] instead.
  Future<void> replaceAll(List<ScheduledNotice> notices);

  /// Cancels every pending reminder.
  Future<void> cancelAll();

  /// Shows a notification now (Settings test button).
  Future<void> showNow({required String title, required String body});
}

/// One reminder, fully localised, ready for the OS.
class ScheduledNotice {
  const ScheduledNotice({
    required this.id,
    required this.fireAtUtc,
    required this.title,
    required this.body,
    required this.payload,
    required this.actionLabel,
  });

  /// `fnv1a31(occ)` (31-bit, stable per occurrence).
  final int id;
  final DateTime fireAtUtc;
  final String title;
  final String body;

  /// `rollcall|<occ>`; empty for the test notification.
  final String payload;

  /// Notification button that opens the roll call ("হাজিরা নিন").
  final String actionLabel;

  @override
  bool operator ==(Object other) =>
      other is ScheduledNotice &&
      other.id == id &&
      other.fireAtUtc == fireAtUtc &&
      other.title == title &&
      other.body == body &&
      other.payload == payload &&
      other.actionLabel == actionLabel;

  @override
  int get hashCode => Object.hash(id, fireAtUtc, title, body, payload, actionLabel);

  @override
  String toString() => 'ScheduledNotice($id @ $fireAtUtc: $title / $body)';
}

/// A gateway that cannot hand reminders to the OS (web): it emits each notice
/// when it comes due while the app is open, for an in-app banner.
abstract interface class InAppReminderSource {
  Stream<ScheduledNotice> get dueNotices;

  void dispose();
}

/// Platforms without notifications (Linux, macOS, iOS builds we don't ship).
class UnsupportedNotificationGateway implements NotificationGateway {
  const UnsupportedNotificationGateway();

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
  Future<void> replaceAll(List<ScheduledNotice> notices) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> showNow({required String title, required String body}) async {}
}
