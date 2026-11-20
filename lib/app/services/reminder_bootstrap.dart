// Reminder start-up hook (stub by M5-A; body by M8-D).
//
// M8-D: initialise the notification gateway, keep the reminder service alive
// with `container.listen(reminderServiceProvider, (_, __) {})`, and return the
// route of the notification that launched the app (cold start), or null.

import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<String?> initRemindersAndGetLaunchRoute(ProviderContainer container) async => null;
