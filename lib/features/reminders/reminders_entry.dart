// Public surface of the reminders feature (plan section 1 #32). STUB by
// M5-A; bodies by M8-D. Signatures are frozen.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/domain/reminders/reminder_models.dart';

/// Current notification permission on this device.
final reminderPermissionProvider =
    FutureProvider<ReminderPermission>((ref) async => ReminderPermission.unsupported);

/// Priming screen before the system permission prompt; true when granted.
Future<bool> showReminderPriming(BuildContext context) async => false;

/// Shows a test reminder now.
Future<void> sendTestReminder(BuildContext context) async {}

/// Opens the Android "alarms & reminders" setting (exact alarms).
Future<void> requestExactAlarms(BuildContext context) async {}
