// The groups of the More screen (Product 3.12 / UX 3a): each group is a list of
// glass cards of two-line rows. Changes save instantly; no Save button.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/features/backup/backup_entry.dart';
import 'package:attendance_alamin/features/extras/extras_entry.dart';
import 'package:attendance_alamin/features/reminders/reminders_entry.dart';
import 'package:attendance_alamin/features/settings/controllers/settings_providers.dart';
import 'package:attendance_alamin/features/settings/data/template_logic.dart';
import 'package:attendance_alamin/features/settings/widgets/int_choice_sheet.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_text_field.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';
import 'package:attendance_alamin/features/settings/widgets/theme_swatches.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Backups older than this many days turn the last-backup row into an info chip.
const int kBackupStaleDays = 7;

/// Reminder lead presets (minutes); anything 1..180 is allowed via "another".
const List<int> kLeadOptions = <int>[5, 10, 15, 20, 30, 60];

/// Billing cutoff presets (day of month); 1..28 allowed via "another".
const List<int> kCutoffOptions = <int>[10, 15, 20, 25];

/// Backup reminder presets (days); 0 = off.
const List<int> kBackupReminderOptions = <int>[0, 3, 7, 14, 30];

enum SettingsGroup {
  archive,
  general,
  center,
  reminders,
  fees,
  backup,
  about;

  String title(AppLocalizations l10n) => switch (this) {
        SettingsGroup.archive => l10n.setGroupArchive,
        SettingsGroup.general => l10n.shellAppearance,
        SettingsGroup.center => l10n.setGroupCenter,
        SettingsGroup.reminders => l10n.setGroupReminders,
        SettingsGroup.fees => l10n.setGroupFees,
        SettingsGroup.backup => l10n.setGroupBackup,
        SettingsGroup.about => l10n.setGroupAbout,
      };

  IconData get icon => switch (this) {
        SettingsGroup.archive => Icons.inventory_2_outlined,
        SettingsGroup.general => Icons.palette_outlined,
        SettingsGroup.center => Icons.storefront_outlined,
        SettingsGroup.reminders => Icons.notifications_outlined,
        SettingsGroup.fees => Icons.account_balance_wallet_outlined,
        SettingsGroup.backup => Icons.save_alt_outlined,
        SettingsGroup.about => Icons.info_outline,
      };
}

/// "আজ" / "৩ দিন আগে" / "no backup yet".
String backupAgeText(AppLocalizations l10n, AppFormat fmt, int? days) {
  if (days == null) return l10n.setBackupNever;
  if (days <= 0) return l10n.setBackupToday;
  return l10n.setBackupAgo(fmt.digits(days.toString()));
}

/// The cards of one group, in one column or two (wide content pane).
class SettingsGroupBody extends ConsumerWidget {
  const SettingsGroupBody({super.key, required this.group, this.twoUp = false});

  final SettingsGroup group;
  final bool twoUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Widget> cards = switch (group) {
      SettingsGroup.archive => _archive(context),
      SettingsGroup.general => _general(context, ref),
      SettingsGroup.center => _center(context),
      SettingsGroup.reminders => _reminders(context, ref),
      SettingsGroup.fees => _fees(context, ref),
      SettingsGroup.backup => _backup(context, ref),
      SettingsGroup.about => _about(context, ref),
    };
    return SettingsColumns(twoUp: twoUp, children: cards);
  }

  // ---- archive ----
  List<Widget> _archive(BuildContext context) {
    final l10n = context.l10n;
    return <Widget>[
      SettingsCard(children: <Widget>[
        SettingRow(
          icon: Icons.inventory_2_outlined,
          title: l10n.shellTitleArchived,
          value: l10n.setArchivedValue,
          onTap: () => context.go(Routes.moreArchived),
        ),
        SettingRow(
          icon: Icons.person_off_outlined,
          title: l10n.shellTitleLeft,
          value: l10n.setLeftValue,
          onTap: () => context.go(Routes.moreLeft),
        ),
        SettingRow(
          icon: Icons.beach_access_outlined,
          title: l10n.shellTitleHolidays,
          value: l10n.setHolidaysValue,
          onTap: () => context.go(Routes.moreHolidays),
        ),
        SettingRow(
          icon: Icons.help_outline,
          title: l10n.shellTitleHelp,
          value: l10n.setHelpValue,
          onTap: () => context.go(Routes.moreHelp),
        ),
      ]),
    ];
  }

  // ---- general ----
  List<Widget> _general(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final Lang lang = ref.watch(langProvider);
    final ThemeMode mode = ref.watch(themeModeProvider);
    final String? effects = ref.watch(reducedEffectsSettingProvider).value;
    final int weekStart = ref.watch(weekStartProvider).value ?? SettingKeys.weekStart.defaultValue;
    final fmt = context.fmt;

    String themeName(ThemeMode m) => switch (m) {
          ThemeMode.system => l10n.shellThemeSystem,
          ThemeMode.light => l10n.shellThemeLight,
          ThemeMode.dark => l10n.shellThemeDark,
        };

    return <Widget>[
      SettingsCard(children: <Widget>[
        SettingControlRow(
          title: l10n.shellLanguage,
          value: l10n.setLanguageCurrent(
              lang == Lang.bn ? l10n.shellLangBangla : l10n.shellLangEnglish),
          child: SegmentedChoice<Lang>(
            key: const Key('more-language'),
            options: Lang.values,
            selected: lang,
            onChanged: (Lang v) => ref.read(langProvider.notifier).set(v),
            labelOf: (Lang v) => v == Lang.bn ? l10n.shellLangBangla : l10n.shellLangEnglish,
          ),
        ),
        SettingControlRow(
          title: l10n.shellTheme,
          value: l10n.setThemeCurrent(themeName(mode)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ThemeSwatches(selected: mode),
              const SizedBox(height: 10),
              SegmentedChoice<ThemeMode>(
                key: const Key('more-theme'),
                options: const <ThemeMode>[ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                selected: mode,
                onChanged: (ThemeMode v) => ref.read(themeModeProvider.notifier).set(v),
                labelOf: themeName,
              ),
            ],
          ),
        ),
      ]),
      SettingsCard(children: <Widget>[
        SettingControlRow(
          title: l10n.setWeekStart,
          value: fmt.weekdayName(weekStart),
          child: SegmentedChoice<int>(
            key: const Key('more-week-start'),
            options: const <int>[6, 7, 1],
            selected: weekStart,
            onChanged: (int v) => saveSetting<int>(context, ref, SettingKeys.weekStart, v),
            labelOf: fmt.weekdayShort,
          ),
        ),
        SettingSwitchRow(
          key: const Key('more-reduced-effects'),
          icon: Icons.blur_off_outlined,
          title: l10n.setReducedEffects,
          subtitle: effects == 'on' ? l10n.setReducedEffectsOn : l10n.setReducedEffectsAuto,
          value: effects == 'on',
          onChanged: (bool on) => ref.read(reducedEffectsProvider.notifier).set(on),
        ),
      ]),
    ];
  }

  // ---- center ----
  List<Widget> _center(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    Widget pad(Widget child) =>
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: child);
    return <Widget>[
      SettingsCard(children: <Widget>[
        pad(SettingTextField(
          key: const Key('more-center-name'),
          settingKey: SettingKeys.centerName,
          label: l10n.setCenterName,
          helper: l10n.setCenterNameHint,
        )),
        pad(SettingTextField(
          key: const Key('more-center-phone'),
          settingKey: SettingKeys.centerPhone,
          label: l10n.setCenterPhone,
          hint: l10n.setCenterPhoneHint,
          isPhone: true,
          maxLength: 20,
        )),
      ]),
      SettingsCard(children: <Widget>[
        pad(SettingTextField(
          key: const Key('more-center-address'),
          settingKey: SettingKeys.centerAddress,
          label: l10n.setCenterAddress,
          helper: l10n.setCenterAddressHint,
          maxLength: 120,
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: <Widget>[
              Icon(Icons.check_circle_outline, size: 18, color: tokens.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.setAutoSaved,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: tokens.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ]),
    ];
  }

  // ---- reminders ----
  Future<void> _toggleReminders(BuildContext context, WidgetRef ref, bool on) async {
    await saveSetting<bool>(context, ref, SettingKeys.remindersEnabled, on);
    if (!on || kIsWeb || !context.mounted) return;
    final ReminderPermission perm = await ref.read(reminderPermissionProvider.future);
    if (perm == ReminderPermission.denied && context.mounted) {
      await showReminderPriming(context);
      ref.invalidate(reminderPermissionProvider);
    }
  }

  List<Widget> _reminders(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final bool enabled =
        ref.watch(remindersEnabledProvider).value ?? SettingKeys.remindersEnabled.defaultValue;
    final int lead =
        ref.watch(defaultLeadProvider).value ?? SettingKeys.defaultReminderLead.defaultValue;
    final ReminderPermission? perm = ref.watch(reminderPermissionProvider).value;

    final List<Widget> second = <Widget>[];
    if (kIsWeb) {
      second.add(SettingRow(
        icon: Icons.info_outline,
        title: l10n.setRemindersWebNote,
      ));
    } else {
      if (enabled && perm == ReminderPermission.denied) {
        second.add(SettingInfoChip(
          message: l10n.setPermMissing,
          actionLabel: l10n.setPermFix,
          onAction: () async {
            await showReminderPriming(context);
            ref.invalidate(reminderPermissionProvider);
          },
        ));
      }
      if (enabled && perm == ReminderPermission.exactDenied) {
        second.add(SettingInfoChip(
          message: l10n.setPermExact,
          actionLabel: l10n.setPermFix,
          onAction: () async {
            await requestExactAlarms(context);
            ref.invalidate(reminderPermissionProvider);
          },
        ));
      }
      second.add(SettingRow(
        key: const Key('more-test-reminder'),
        icon: Icons.notifications_active_outlined,
        title: l10n.setTestReminder,
        value: l10n.setTestReminderValue,
        onTap: () => sendTestReminder(context),
      ));
    }

    return <Widget>[
      SettingsCard(children: <Widget>[
        SettingSwitchRow(
          key: const Key('more-reminders-switch'),
          icon: Icons.notifications_outlined,
          title: l10n.setRemindersSwitch,
          subtitle: enabled ? l10n.setRemindersOnValue : l10n.setRemindersOffValue,
          value: enabled,
          onChanged: (bool on) => _toggleReminders(context, ref, on),
        ),
        SettingRow(
          key: const Key('more-default-lead'),
          icon: Icons.timer_outlined,
          title: l10n.setDefaultLead,
          value: l10n.setLeadValue(fmt.digits(lead.toString())),
          onTap: () async {
            final int? v = await showIntChoiceSheet(
              context,
              title: l10n.setLeadSheetTitle,
              options: kLeadOptions,
              current: lead,
              labelOf: (int n) => l10n.setLeadValue(fmt.digits(n.toString())),
              customMin: 1,
              customMax: 180,
            );
            if (v != null && context.mounted) {
              await saveSetting<int>(context, ref, SettingKeys.defaultReminderLead, v);
            }
          },
        ),
      ]),
      SettingsCard(children: second),
    ];
  }

  // ---- fees ----
  String _templateValue(AppLocalizations l10n, WidgetRef ref, TemplateKind kind, Lang lang) {
    final String? raw = switch ((kind, lang)) {
      (TemplateKind.reminder, Lang.bn) => ref.watch(reminderTemplateBnProvider).value,
      (TemplateKind.reminder, Lang.en) => ref.watch(reminderTemplateEnProvider).value,
      (TemplateKind.receipt, Lang.bn) => ref.watch(receiptTemplateBnProvider).value,
      (TemplateKind.receipt, Lang.en) => ref.watch(receiptTemplateEnProvider).value,
    };
    final String stored = raw ?? '';
    return isCustomTemplate(stored) ? l10n.setTemplateCustom : l10n.setTemplateDefault;
  }

  List<Widget> _fees(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final Lang lang = context.lang;
    final int cutoff =
        ref.watch(cutoffDayProvider).value ?? SettingKeys.billingCutoffDay.defaultValue;
    final int methods = ref.watch(paymentMethodsConfigProvider).visibleCount;
    return <Widget>[
      SettingsCard(children: <Widget>[
        SettingRow(
          key: const Key('more-cutoff-day'),
          icon: Icons.event_outlined,
          title: l10n.setCutoffDay,
          value: l10n.setCutoffValue(fmt.digits(cutoff.toString())),
          onTap: () async {
            final int? v = await showIntChoiceSheet(
              context,
              title: l10n.setCutoffSheetTitle,
              options: kCutoffOptions,
              current: cutoff,
              labelOf: (int n) => fmt.digits(n.toString()),
              customMin: 1,
              customMax: 28,
            );
            if (v != null && context.mounted) {
              await saveSetting<int>(context, ref, SettingKeys.billingCutoffDay, v);
            }
          },
        ),
        SettingRow(
          key: const Key('more-payment-methods'),
          icon: Icons.account_balance_wallet_outlined,
          title: l10n.shellTitlePaymentMethods,
          value: l10n.setPaymentMethodsValue(fmt.digits(methods.toString())),
          onTap: () => context.go(Routes.morePaymentMethods),
        ),
      ]),
      SettingsCard(children: <Widget>[
        SettingRow(
          key: const Key('more-template-reminder'),
          icon: Icons.edit_note,
          title: l10n.shellTitleTemplateReminder,
          value: _templateValue(l10n, ref, TemplateKind.reminder, lang),
          onTap: () => context.go(Routes.moreTemplate(TemplateKind.reminder.code)),
        ),
        SettingRow(
          key: const Key('more-template-receipt'),
          icon: Icons.receipt_long_outlined,
          title: l10n.shellTitleTemplateReceipt,
          value: _templateValue(l10n, ref, TemplateKind.receipt, lang),
          onTap: () => context.go(Routes.moreTemplate(TemplateKind.receipt.code)),
        ),
      ]),
    ];
  }

  // ---- backup ----
  List<Widget> _backup(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final int? days = ref.watch(daysSinceBackupProvider);
    final int remindDays =
        ref.watch(backupReminderDaysProvider).value ?? SettingKeys.backupReminderDays.defaultValue;
    final bool stale = days == null || days > kBackupStaleDays;

    String remindText(int n) =>
        n == 0 ? l10n.setBackupReminderOff : l10n.setBackupReminderEvery(fmt.digits(n.toString()));

    return <Widget>[
      SettingsCard(children: <Widget>[
        SettingRow(
          key: const Key('more-last-backup'),
          icon: Icons.history,
          title: l10n.setBackupLast,
          value: backupAgeText(l10n, fmt, days),
        ),
        if (stale)
          SettingInfoChip(
            message: l10n.setBackupOverdue,
            actionLabel: l10n.setBackupNow,
            onAction: () => runExportBackup(context),
          ),
        SettingRow(
          key: const Key('more-backup-now'),
          icon: Icons.save_alt_outlined,
          title: l10n.setBackupNow,
          value: l10n.setBackupNowValue,
          onTap: () => runExportBackup(context),
        ),
        SettingRow(
          key: const Key('more-restore'),
          icon: Icons.upload_file_outlined,
          title: l10n.setRestore,
          value: l10n.setRestoreValue,
          onTap: () => runImportBackup(context),
        ),
        SettingRow(
          key: const Key('more-csv-export'),
          icon: Icons.table_view_outlined,
          title: l10n.setCsvExport,
          value: l10n.setCsvExportValue,
          onTap: () => runCsvExport(context, month: ref.read(todayProvider).yearMonth),
        ),
      ]),
      SettingsCard(children: <Widget>[
        SettingRow(
          key: const Key('more-safety-copy'),
          icon: Icons.restore,
          title: l10n.setSafetyCopy,
          value: l10n.setSafetyCopyValue,
          onTap: () => context.go(Routes.moreBackup),
        ),
        SettingRow(
          key: const Key('more-backup-reminder'),
          icon: Icons.alarm_outlined,
          title: l10n.setBackupReminder,
          value: remindText(remindDays),
          onTap: () async {
            final int? v = await showIntChoiceSheet(
              context,
              title: l10n.setBackupReminderSheetTitle,
              options: kBackupReminderOptions,
              current: remindDays,
              labelOf: remindText,
            );
            if (v != null && context.mounted) {
              await saveSetting<int>(context, ref, SettingKeys.backupReminderDays, v);
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SettingTextField(
            key: const Key('more-device-name'),
            settingKey: SettingKeys.deviceName,
            label: l10n.setDeviceName,
            hint: l10n.setDeviceNameHint,
            helper: l10n.setDeviceNameHelper,
          ),
        ),
      ]),
    ];
  }

  // ---- about ----
  List<Widget> _about(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final String version = ref.watch(appVersionProvider).value ?? l10n.setVersionUnknown;
    return <Widget>[
      SettingsCard(children: <Widget>[
        SettingRow(
          key: const Key('more-version'),
          icon: Icons.info_outline,
          title: l10n.setVersion,
          value: version,
        ),
        SettingRow(
          key: const Key('more-font-credit'),
          icon: Icons.font_download_outlined,
          title: l10n.setFontCredit,
          value: l10n.setFontCreditValue,
          onTap: () => showDialog<void>(
            context: context,
            builder: (BuildContext ctx) => AlertDialog(
              title: Text(l10n.setFontCredit),
              content: Text(l10n.setFontCreditBody),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(l10n.commonClose),
                ),
              ],
            ),
          ),
        ),
        SettingRow(
          key: const Key('more-diagnostics'),
          icon: Icons.monitor_heart_outlined,
          title: l10n.shellTitleDiagnostics,
          value: l10n.setDiagnosticsValue,
          onTap: () => context.go(Routes.moreDiagnostics),
        ),
      ]),
    ];
  }
}
