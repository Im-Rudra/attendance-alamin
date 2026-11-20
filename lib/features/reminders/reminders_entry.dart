// Public surface of the reminders feature (plan section 1 #32). Signatures
// frozen by M5-A; bodies by M8-D.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/notifications/notification_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/features/reminders/reminder_service.dart';
import 'package:attendance_alamin/features/reminders/ui/reminder_priming_screen.dart';

/// Current notification permission on this device (`unsupported` on web and
/// wherever the plugin is missing).
final reminderPermissionProvider = FutureProvider<ReminderPermission>((ref) async {
  try {
    return await ref.watch(notificationGatewayProvider).permission();
  } on Object {
    return ReminderPermission.unsupported;
  }
});

/// Priming screen before the system permission prompt; true when
/// notifications are allowed.
///
/// The explaining screen appears at most once per app version
/// (`SettingKeys.notifPromptedVersion`). After that, this call (always a tap:
/// the reminders switch or the Settings "ঠিক করুন" chip) goes straight to the
/// system prompt, which Android itself stops showing after two refusals.
Future<bool> showReminderPriming(BuildContext context) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final NotificationGateway gateway = container.read(notificationGatewayProvider);
  final ReminderPermission perm = await _permissionOf(gateway);
  switch (perm) {
    case ReminderPermission.granted:
    case ReminderPermission.exactDenied:
      return true;
    case ReminderPermission.unsupported:
      return false;
    case ReminderPermission.denied:
      break;
  }
  final String version = await container.read(reminderAppVersionProvider.future);
  final String prompted = await container.read(settingsRepositoryProvider).get(SettingKeys.notifPromptedVersion);
  if (!context.mounted) return false;
  if (prompted == version) {
    bool granted = false;
    try {
      granted = await gateway.requestPermission();
    } on Object {
      granted = false;
    }
    container.invalidate(reminderPermissionProvider);
    return granted;
  }
  final bool? granted = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (BuildContext _) => const ReminderPrimingScreen(),
    ),
  );
  container.invalidate(reminderPermissionProvider);
  return granted ?? false;
}

/// Shows a test reminder now.
Future<void> sendTestReminder(BuildContext context) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final NotificationGateway gateway = container.read(notificationGatewayProvider);
  final l10n = context.l10n;
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  bool ok;
  try {
    final ReminderPermission perm = await gateway.permission();
    if (perm == ReminderPermission.denied) {
      ok = false;
    } else {
      await gateway.setChannel(name: l10n.remindChannelName, description: l10n.remindChannelDescription);
      await gateway.showNow(title: l10n.remindTestTitle, body: l10n.remindTestBody);
      ok = true;
    }
  } on Object {
    ok = false;
  }
  messenger?.showSnackBar(SnackBar(content: Text(ok ? l10n.remindTestSent : l10n.remindTestFailed)));
}

/// Opens the Android "alarms & reminders" setting (exact alarms). The
/// reminders are replanned when the app comes back (lifecycle resume).
Future<void> requestExactAlarms(BuildContext context) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  await requestExactAlarmsFor(container);
}

/// [requestExactAlarms] without a widget (also used by the priming screen).
Future<bool> requestExactAlarmsFor(ProviderContainer container) async {
  final NotificationGateway gateway = container.read(notificationGatewayProvider);
  bool allowed;
  try {
    allowed = await gateway.requestExact();
  } on Object {
    allowed = false;
  }
  try {
    final String version = await container.read(reminderAppVersionProvider.future);
    await container.read(settingsRepositoryProvider).set(SettingKeys.exactPromptedVersion, version);
  } on Object {
    // Remembering the prompt is best effort.
  }
  container.invalidate(reminderPermissionProvider);
  if (container.exists(reminderServiceProvider)) {
    container.read(reminderServiceProvider).requestReplan();
  }
  return allowed;
}

Future<ReminderPermission> _permissionOf(NotificationGateway gateway) async {
  try {
    return await gateway.permission();
  } on Object {
    return ReminderPermission.unsupported;
  }
}
