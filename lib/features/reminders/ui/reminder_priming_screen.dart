// Reminder permission priming (UX 2h, Product 3.11, plan section 1 #26).
// Explains in plain words why the phone is about to ask for permission, then
// asks; if Android still blocks exact alarms, a second short card offers the
// "Alarms & reminders" setting and confirms "সব ঠিক আছে" on return.
// Pops with `true` when notifications are allowed. Shown at most once per app
// version (it records `SettingKeys.notifPromptedVersion` when it opens).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/notifications/notification_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/features/reminders/reminder_service.dart';
import 'package:attendance_alamin/features/reminders/reminders_entry.dart';

enum _Stage { intro, exact, allSet, denied }

class ReminderPrimingScreen extends ConsumerStatefulWidget {
  const ReminderPrimingScreen({super.key});

  @override
  ConsumerState<ReminderPrimingScreen> createState() => _ReminderPrimingScreenState();
}

class _ReminderPrimingScreenState extends ConsumerState<ReminderPrimingScreen> {
  _Stage _stage = _Stage.intro;
  bool _busy = false;
  bool _granted = false;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    unawaited(_rememberShown());
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _rememberShown() async {
    try {
      final String version = await ref.read(reminderAppVersionProvider.future);
      if (!mounted) return;
      await ref.read(settingsRepositoryProvider).set(SettingKeys.notifPromptedVersion, version);
    } on Object {
      // Best effort: at worst the screen may show once more.
    }
  }

  NotificationGateway get _gateway => ref.read(notificationGatewayProvider);

  Future<ReminderPermission> _permission() async {
    try {
      return await _gateway.permission();
    } on Object {
      return ReminderPermission.unsupported;
    }
  }

  /// Back from the system "Alarms & reminders" page.
  Future<void> _onResume() async {
    if (_stage != _Stage.exact) return;
    final ReminderPermission perm = await _permission();
    if (!mounted) return;
    if (perm == ReminderPermission.granted) setState(() => _stage = _Stage.allSet);
  }

  Future<void> _allow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _gateway.requestPermission();
    } on Object {
      // The permission check below tells what happened.
    }
    final ReminderPermission perm = await _permission();
    if (!mounted) return;
    ref.invalidate(reminderPermissionProvider);
    _Stage next;
    switch (perm) {
      case ReminderPermission.granted:
      case ReminderPermission.unsupported:
        _granted = perm == ReminderPermission.granted;
        _finish(_granted);
        return;
      case ReminderPermission.denied:
        next = _Stage.denied;
      case ReminderPermission.exactDenied:
        _granted = true;
        final String version = await ref.read(reminderAppVersionProvider.future);
        final String asked = await ref.read(settingsRepositoryProvider).get(SettingKeys.exactPromptedVersion);
        if (!mounted) return;
        if (asked == version) {
          _finish(true);
          return;
        }
        next = _Stage.exact;
    }
    setState(() {
      _busy = false;
      _stage = next;
    });
  }

  Future<void> _openExactSettings() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bool allowed = await requestExactAlarmsFor(ProviderScope.containerOf(context, listen: false));
    if (!mounted) return;
    final ReminderPermission perm = allowed ? ReminderPermission.granted : await _permission();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (perm == ReminderPermission.granted) _stage = _Stage.allSet;
    });
  }

  void _finish(bool result) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
    } else {
      GoRouter.maybeOf(context)?.go(Routes.today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonClose,
          icon: const Icon(Icons.close),
          onPressed: () => _finish(_granted),
        ),
        title: Text(l10n.shellTitleReminderPriming),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: switch (_stage) {
                  _Stage.intro => _intro(context),
                  _Stage.exact => _exact(context),
                  _Stage.allSet => _allSet(context),
                  _Stage.denied => _denied(context),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _illustration(BuildContext context, IconData icon) {
    final tokens = context.aurora;
    return ExcludeSemantics(
      child: Container(
        width: 88,
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tokens.accentContainer, shape: BoxShape.circle),
        child: Icon(icon, size: 44, color: tokens.onAccentContainer),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: context.aurora.textPrimary),
      );

  Widget _paragraph(BuildContext context, String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.aurora.textSecondary),
      );

  Widget _point(BuildContext context, IconData icon, String text) {
    final tokens = context.aurora;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: tokens.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context,
      {required String primary, required VoidCallback onPrimary, String? secondary, VoidCallback? onSecondary}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton(
          key: const Key('remind-priming-primary'),
          onPressed: _busy ? null : onPrimary,
          child: Text(primary),
        ),
        if (secondary != null) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(
            key: const Key('remind-priming-secondary'),
            onPressed: _busy ? null : onSecondary,
            child: Text(secondary),
          ),
        ],
      ],
    );
  }

  Widget _intro(BuildContext context) {
    final l10n = context.l10n;
    final int lead =
        ref.watch(reminderDefaultLeadProvider).value ?? SettingKeys.defaultReminderLead.defaultValue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(child: _illustration(context, Icons.notifications_active_outlined)),
        const SizedBox(height: 16),
        _heading(context, l10n.remindPrimingTitle),
        const SizedBox(height: 16),
        _point(context, Icons.alarm, l10n.remindPrimingPoint1(context.fmt.number(lead))),
        _point(context, Icons.touch_app_outlined, l10n.remindPrimingPoint2),
        _point(context, Icons.tune, l10n.remindPrimingPoint3),
        const SizedBox(height: 12),
        _paragraph(context, l10n.remindPrimingWhy),
        const SizedBox(height: 20),
        _buttons(
          context,
          primary: l10n.remindPrimingYes,
          onPrimary: () => unawaited(_allow()),
          secondary: l10n.remindPrimingNotNow,
          onSecondary: () => _finish(false),
        ),
      ],
    );
  }

  Widget _exact(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(child: _illustration(context, Icons.alarm_on_outlined)),
        const SizedBox(height: 16),
        _heading(context, l10n.remindPrimingExactTitle),
        const SizedBox(height: 12),
        _paragraph(context, l10n.remindPrimingExactBody),
        const SizedBox(height: 20),
        _buttons(
          context,
          primary: l10n.remindPrimingOpenSettings,
          onPrimary: () => unawaited(_openExactSettings()),
          secondary: l10n.remindPrimingNotNow,
          onSecondary: () => _finish(true),
        ),
      ],
    );
  }

  Widget _allSet(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(child: _illustration(context, Icons.check_circle_outline)),
        const SizedBox(height: 16),
        _heading(context, l10n.remindPrimingAllSet),
        const SizedBox(height: 12),
        _paragraph(context, l10n.remindPrimingAllSetBody),
        const SizedBox(height: 20),
        _buttons(context, primary: l10n.remindPrimingContinue, onPrimary: () => _finish(true)),
      ],
    );
  }

  Widget _denied(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(child: _illustration(context, Icons.notifications_off_outlined)),
        const SizedBox(height: 16),
        _paragraph(context, l10n.remindPrimingDenied),
        const SizedBox(height: 20),
        _buttons(context, primary: l10n.remindPrimingContinue, onPrimary: () => _finish(false)),
      ],
    );
  }
}
