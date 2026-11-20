// Android + Windows notifications over flutter_local_notifications 23.x
// (Arch 4B). Every instant is UTC: `TZDateTime.from(fireAtUtc, UTC)` needs no
// timezone database. Selected by the conditional import in
// notification_providers.dart for every non-web build (no dart:io here).

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

// Constants-only file (AUMID / toast GUID must never change, plan M0-A).
import 'package:attendance_alamin/app/app_info.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/data/notifications/notification_gateway.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';

NotificationGateway createNotificationGateway(Clock clock) {
  if (kIsWeb) return const UnsupportedNotificationGateway();
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => LocalNotificationGateway(android: true),
    TargetPlatform.windows => LocalNotificationGateway(android: false),
    _ => const UnsupportedNotificationGateway(),
  };
}

/// The plugin-backed gateway. Every call is safe before [init] and on hosts
/// without the platform plugin (unit tests): it then does nothing and reports
/// [ReminderPermission.unsupported].
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway({required this.android});

  /// Android (true) or Windows (false).
  final bool android;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const String _channelId = 'class_reminders';
  static const String _smallIcon = 'ic_stat_class';
  static const String _actionId = 'rollcall';

  /// Id of the Settings test notification (outside typical fnv1a31 use).
  static const int _testId = 0x7FFFFFF0;

  String _channelName = kAppDisplayNameBn;
  String? _channelDescription;

  AndroidFlutterLocalNotificationsPlugin? get _androidImpl => android
      ? _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      : null;

  @override
  Future<void> init({required void Function(String payload) onTap}) async {
    if (_ready) return;
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings(_smallIcon),
      windows: WindowsInitializationSettings(
        appName: kAppDisplayNameBn,
        appUserModelId: kWindowsAumid,
        guid: kWindowsToastGuid,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    _ready = true;
  }

  @override
  Future<String?> launchPayload() async {
    if (!_ready) return null;
    try {
      final NotificationAppLaunchDetails? details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return details.notificationResponse?.payload;
    } on Object {
      return null;
    }
  }

  @override
  Future<ReminderPermission> permission() async {
    if (!android) return ReminderPermission.granted;
    try {
      final AndroidFlutterLocalNotificationsPlugin? impl = _androidImpl;
      if (impl == null) return ReminderPermission.unsupported;
      final bool enabled = await impl.areNotificationsEnabled() ?? false;
      if (!enabled) return ReminderPermission.denied;
      final bool exact = await impl.canScheduleExactNotifications() ?? false;
      return exact ? ReminderPermission.granted : ReminderPermission.exactDenied;
    } on Object {
      return ReminderPermission.unsupported;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!android) return true;
    try {
      return await _androidImpl?.requestNotificationsPermission() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> requestExact() async {
    if (!android) return true;
    try {
      return await _androidImpl?.requestExactAlarmsPermission() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> setChannel({required String name, required String description}) async {
    _channelName = name;
    _channelDescription = description;
    if (!android || !_ready) return;
    try {
      // Re-creating a channel with the same id only updates its name and
      // description (the user's own channel choices are kept).
      await _androidImpl?.createNotificationChannel(AndroidNotificationChannel(
        _channelId,
        name,
        description: description,
        importance: Importance.high,
      ));
    } on Object {
      // The plugin creates the channel itself on the first notification.
    }
  }

  NotificationDetails _details({String? actionLabel}) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
          actions: actionLabel == null || actionLabel.isEmpty
              ? null
              : <AndroidNotificationAction>[
                  AndroidNotificationAction(_actionId, actionLabel, showsUserInterface: true),
                ],
        ),
      );

  /// Exact when Android allows it, else inexact (may be a few minutes late;
  /// Settings discloses this). Ignored on Windows.
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!android) return AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      final bool exact = await _androidImpl?.canScheduleExactNotifications() ?? false;
      return exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    } on Object {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  @override
  Future<void> replaceAll(List<ScheduledNotice> notices) async {
    if (!_ready) return;
    await cancelAll();
    if (notices.isEmpty) return;
    final AndroidScheduleMode mode = await _scheduleMode();
    for (final ScheduledNotice n in notices) {
      try {
        await _plugin.zonedSchedule(
          id: n.id,
          scheduledDate: tz.TZDateTime.from(n.fireAtUtc, tz.UTC),
          notificationDetails: _details(actionLabel: n.actionLabel),
          androidScheduleMode: mode,
          title: n.title,
          body: n.body,
          payload: n.payload,
        );
      } on Object {
        // One bad notice (e.g. its time passed a moment ago) never blocks the rest.
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    if (android) {
      // Pending alarms only: a reminder already in the shade stays visible.
      await _plugin.cancelAllPendingNotifications();
    } else {
      // Windows: removes the scheduled toasts (history APIs need MSIX).
      await _plugin.cancelAll();
    }
  }

  @override
  Future<void> showNow({required String title, required String body}) async {
    if (!_ready) throw StateError('Notifications are not initialised');
    await _plugin.show(
      id: _testId,
      title: title,
      body: body,
      notificationDetails: _details(),
    );
  }
}
