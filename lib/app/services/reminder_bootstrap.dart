// Reminder start-up hook (stub by M5-A; body by M8-D, Arch 4B).
//
// 1. Initialise the notification gateway; a tap on a reminder while the app
//    runs (warm) opens that occurrence's roll call.
// 2. Keep the reminder service alive (it replans on every change).
// 3. Web: show each due reminder as an in-app banner while the tab is open.
// 4. Cold start: return the route of the notification that launched the app.
// A reminder whose class was cancelled after it fired opens the batch (its
// schedule tab) with an "এই ক্লাস বাতিল" note instead of the roll call.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/router.dart';
import 'package:attendance_alamin/data/notifications/notification_providers.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/schedule_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/features/reminders/reminder_service.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Moves the app to a location (overridden in tests).
final reminderNavigatorProvider = Provider<void Function(String location)>(
    (Ref ref) => (String location) => ref.read(routerProvider).go(location));

/// Shows a short note (snackbar) once the app's navigator is up (overridden
/// in tests).
final reminderNoteProvider = Provider<void Function(String text)>((Ref ref) => _showNoteWhenReady);

/// Web: turns each due reminder into an in-app banner (kept alive by
/// [initRemindersAndGetLaunchRoute]).
final _inAppBannerProvider = Provider<void>((Ref ref) {
  final NotificationGateway gateway = ref.watch(notificationGatewayProvider);
  if (gateway case final InAppReminderSource source) {
    final StreamSubscription<ScheduledNotice> sub =
        source.dueNotices.listen((ScheduledNotice n) => _showBanner(ref, n));
    ref.onDispose(sub.cancel);
  }
});

Future<String?> initRemindersAndGetLaunchRoute(ProviderContainer container) async {
  final NotificationGateway gateway = container.read(notificationGatewayProvider);
  try {
    await gateway.init(onTap: (String payload) => unawaited(openReminderPayload(container, payload)));
  } on Object {
    // No OS notifications on this device: the app still starts.
  }
  container.listen<ReminderService>(reminderServiceProvider, (_, __) {});
  container.listen<void>(_inAppBannerProvider, (_, __) {});

  String? payload;
  try {
    payload = await gateway.launchPayload();
  } on Object {
    payload = null;
  }
  if (payload == null || payload.isEmpty) return null;
  final ReminderTapTarget? target = await _targetOf(container, payload);
  if (target == null) return null;
  if (target.cancelled) container.read(reminderNoteProvider)(_l10n(container).remindCancelledNote);
  return target.route;
}

/// A reminder tapped while the app runs: roll call, or the batch with a note.
Future<void> openReminderPayload(ProviderContainer container, String payload) async {
  try {
    final ReminderTapTarget? target = await _targetOf(container, payload);
    if (target == null) return;
    container.read(reminderNavigatorProvider)(target.route);
    if (target.cancelled) container.read(reminderNoteProvider)(_l10n(container).remindCancelledNote);
  } on Object {
    // A disposed container (app restarted) or a bad payload: ignore the tap.
  }
}

Future<ReminderTapTarget?> _targetOf(ProviderContainer container, String payload) => resolveReminderTap(
      payload,
      schedule: container.read(scheduleRepositoryProvider),
      meta: container.read(localMetaRepositoryProvider),
    );

AppLocalizations _l10n(ProviderContainer container) =>
    lookupAppLocalizations(Locale(container.read(langProvider).code));

/// Runs [show] with the app's ScaffoldMessenger as soon as the router's
/// navigator is mounted (cold start: after the first frames).
void _whenMessengerReady(void Function(ScaffoldMessengerState messenger) show, [int attempt = 0]) {
  final BuildContext? context = rootNavigatorKey.currentContext;
  final ScaffoldMessengerState? messenger = context == null ? null : ScaffoldMessenger.maybeOf(context);
  if (messenger != null) {
    show(messenger);
    return;
  }
  if (attempt >= 1200) return; // ~20 s of frames: give up quietly
  final WidgetsBinding binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((Duration _) => _whenMessengerReady(show, attempt + 1));
  binding.scheduleFrame();
}

void _showNoteWhenReady(String text) => _whenMessengerReady(
    (ScaffoldMessengerState m) => m.showSnackBar(SnackBar(content: Text(text))));

void _showBanner(Ref ref, ScheduledNotice notice) {
  final AppLocalizations l10n = lookupAppLocalizations(Locale(ref.read(langProvider).code));
  final void Function(String location) navigate = ref.read(reminderNavigatorProvider);
  final void Function(String text) note = ref.read(reminderNoteProvider);
  final ScheduleRepository schedule = ref.read(scheduleRepositoryProvider);
  final LocalMetaRepository meta = ref.read(localMetaRepositoryProvider);

  Future<void> open() async {
    try {
      final ReminderTapTarget? target =
          await resolveReminderTap(notice.payload, schedule: schedule, meta: meta);
      if (target == null) return;
      navigate(target.route);
      if (target.cancelled) note(l10n.remindCancelledNote);
    } on Object {
      // The app was restarted meanwhile: ignore the tap.
    }
  }

  _whenMessengerReady((ScaffoldMessengerState m) {
    m.clearMaterialBanners();
    m.showMaterialBanner(MaterialBanner(
      leading: const Icon(Icons.notifications_active_outlined),
      content: Text('${notice.title}\n${notice.body}'),
      actions: <Widget>[
        if (notice.payload.isNotEmpty)
          TextButton(
            onPressed: () {
              m.hideCurrentMaterialBanner();
              unawaited(open());
            },
            child: Text(notice.actionLabel),
          ),
        TextButton(
          onPressed: m.hideCurrentMaterialBanner,
          child: Text(l10n.remindBannerDismiss),
        ),
      ],
    ));
  });
}

