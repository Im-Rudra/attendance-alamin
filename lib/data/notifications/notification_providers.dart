// The notification gateway for this platform (plan M8-D). Features import
// this file only; it re-exports the gateway types they need.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/notifications/notification_gateway.dart';
import 'package:attendance_alamin/data/notifications/notification_gateway_io.dart'
    if (dart.library.js_interop) 'package:attendance_alamin/data/notifications/notification_gateway_web.dart';

export 'package:attendance_alamin/data/notifications/notification_gateway.dart'
    show InAppReminderSource, NotificationGateway, ScheduledNotice;

/// Android / Windows: the OS schedules reminders (they fire with the app
/// closed). Web: an in-app ticker while the tab is open. Override with a fake
/// in tests.
final notificationGatewayProvider = Provider<NotificationGateway>((ref) {
  final NotificationGateway gateway = createNotificationGateway(ref.watch(clockProvider));
  if (gateway case final InAppReminderSource source) ref.onDispose(source.dispose);
  return gateway;
});
