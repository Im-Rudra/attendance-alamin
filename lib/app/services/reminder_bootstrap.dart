// Reminder start-up hook (stub by M5-A; body by M8-D, Arch 4B).
//
// 1. Initialise the notification gateway; a tap on a reminder while the app
//    runs (warm) opens that occurrence's roll call.
// 2. Keep the reminder service alive (it replans on every change).
// 3. Web: show each due reminder as an in-app banner (a top BhorToast that
//    stays until tapped) while the tab is open.
// 4. Cold start: return the route of the notification that launched the app.
// A reminder whose class was cancelled after it fired opens the batch (its
// schedule tab) with an "এই ক্লাস বাতিল" note instead of the roll call.

import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
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

/// Shows a short note (a BhorToast) once the app's navigator is up
/// (overridden in tests).
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

/// Runs [show] with a context that can hold a BhorToast as soon as the
/// router's navigator is mounted (cold start: after the first frames).
void _whenToastReady(void Function(BuildContext context) show, [int attempt = 0]) {
  final BuildContext? context = rootNavigatorKey.currentContext;
  if (context != null && context.mounted && BhorToast.canShowIn(context)) {
    show(context);
    return;
  }
  if (attempt >= 1200) return; // ~20 s of frames: give up quietly
  final WidgetsBinding binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((Duration _) => _whenToastReady(show, attempt + 1));
  binding.scheduleFrame();
}

void _showNoteWhenReady(String text) =>
    _whenToastReady((BuildContext context) => BhorToast.show(context, message: text));

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

  _whenToastReady((BuildContext context) {
    BhorToast.show(
      context,
      message: '${notice.title}\n${notice.body}',
      icon: Icons.notifications_active_outlined,
      tone: BhorTone.accent,
      top: true,
      // Like the old banner: stays until the teacher opens or dismisses it.
      duration: null,
      actions: <BhorToastAction>[
        if (notice.payload.isNotEmpty) BhorToastAction(label: notice.actionLabel, onPressed: () => unawaited(open())),
        BhorToastAction(label: l10n.remindBannerDismiss, onPressed: () {}),
      ],
    );
  });
}
