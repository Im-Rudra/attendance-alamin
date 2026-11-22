// The groups of the More screen (Product 3.12 / UX 3a): each group is a list of
// cards of two-line rows. Changes save instantly; no Save button.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/features/backup/backup_entry.dart';
import 'package:attendance_alamin/features/reminders/reminders_entry.dart';
import 'package:attendance_alamin/features/settings/controllers/settings_providers.dart';
import 'package:attendance_alamin/features/settings/data/template_logic.dart';
import 'package:attendance_alamin/features/extras/ui/holiday_screen.dart';
import 'package:attendance_alamin/features/settings/ui/diagnostics_screen.dart';
import 'package:attendance_alamin/features/settings/ui/help_screen.dart';
import 'package:attendance_alamin/features/settings/ui/payment_methods_screen.dart';
import 'package:attendance_alamin/features/settings/ui/template_editor_screen.dart';
import 'package:attendance_alamin/features/settings/widgets/int_choice_sheet.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_text_field.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';
import 'package:attendance_alamin/features/settings/widgets/theme_swatches.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Reminder lead presets (minutes); anything 1..180 is allowed via "another".
const List<int> kLeadOptions = <int>[5, 10, 15, 20, 30, 60];

/// Billing cutoff presets (day of month); 1..28 allowed via "another".
const List<int> kCutoffOptions = <int>[10, 15, 20, 25];

enum SettingsGroup {
  general,
  center,
  reminders,
  fees,
  backup,
  holidays,
  archive,
  about;

  String title(AppLocalizations l10n) => switch (this) {
        SettingsGroup.general => l10n.shellAppearance,
        SettingsGroup.center => l10n.setGroupCenter,
        SettingsGroup.reminders => l10n.setGroupReminders,
        SettingsGroup.fees => l10n.setGroupFees,
        SettingsGroup.backup => l10n.setGroupBackup,
        SettingsGroup.holidays => l10n.shellTitleHolidays,
        SettingsGroup.archive => l10n.setGroupArchive,
        SettingsGroup.about => l10n.setGroupAbout,
      };

  IconData get icon => switch (this) {
        SettingsGroup.general => BhorIcons.sliders,
        SettingsGroup.center => BhorIcons.batches,
        SettingsGroup.reminders => BhorIcons.bell,
        SettingsGroup.fees => BhorIcons.fees,
        SettingsGroup.backup => BhorIcons.storage,
        SettingsGroup.holidays => BhorIcons.calendar,
        SettingsGroup.archive => BhorIcons.archive,
        SettingsGroup.about => BhorIcons.info,
      };
}

/// A sub-page of the Archive section (it shows a crumb back to its section).
enum MoreSub {
  archivedBatches,
  leftStudents;

  String title(AppLocalizations l10n) => switch (this) {
        MoreSub.archivedBatches => l10n.shellTitleArchived,
        MoreSub.leftStudents => l10n.shellTitleLeft,
      };

  String get route => switch (this) {
        MoreSub.archivedBatches => Routes.moreArchived,
        MoreSub.leftStudents => Routes.moreLeft,
      };
}

/// "আজ" / "৩ দিন আগে" / "no backup yet".
String backupAgeText(AppLocalizations l10n, AppFormat fmt, int? days) {
  if (days == null) return l10n.setBackupNever;
  if (days <= 0) return l10n.setBackupToday;
  return l10n.setBackupAgo(fmt.digits(days.toString()));
}

/// Opens a settings sub-page: on desktop it floats over the settings layout
/// as a side panel (never a popover hanging off the row, M5), so the teacher
/// never leaves More; on phones it is a normal push.
Future<void> openSettingsSubPage(
  BuildContext context, {
  required String route,
  required String title,
  required WidgetBuilder builder,
  BhorPanelKind kind = BhorPanelKind.form,
  double? width,
}) async {
  if (context.bhorIsWide) {
    await showBhorPanel<void>(context, kind: kind, title: title, width: width, builder: builder);
  } else {
    context.go(route);
  }
}

/// The cards of one group. [wide]: the settings layout (section nav + one
/// column): Holidays shows its form right here and Archive opens its
/// sub-pages in place ([onOpenSub]); on phones both are rows that open a page.
class SettingsGroupBody extends ConsumerWidget {
  const SettingsGroupBody({super.key, required this.group, this.wide = false, this.onOpenSub});

  final SettingsGroup group;
  final bool wide;

  /// Wide More: an Archive sub-page opens in the same column via this.
  final ValueChanged<MoreSub>? onOpenSub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Widget> cards = switch (group) {
      SettingsGroup.general => _general(context, ref),
      SettingsGroup.center => _center(context),
      SettingsGroup.reminders => _reminders(context, ref),
      SettingsGroup.fees => _fees(context, ref),
      SettingsGroup.backup => const <Widget>[BackupSection()],
      SettingsGroup.holidays => _holidays(context),
      SettingsGroup.archive => _archive(context),
      SettingsGroup.about => _about(context, ref),
    };
    return SettingsColumns(children: cards);
  }

  void _openSub(BuildContext context, MoreSub sub) {
    final ValueChanged<MoreSub>? open = onOpenSub;
    if (open != null) {
      open(sub);
    } else {
      context.go(sub.route);
    }
  }

  // ---- holidays ----
  List<Widget> _holidays(BuildContext context) {
    final l10n = context.l10n;
    if (wide) return const <Widget>[HolidayScreen(embedded: true)];
    return <Widget>[
      SettingsCard(children: <Widget>[
        SettingRow(
          icon: BhorIcons.calendar,
          title: l10n.shellTitleHolidays,
          value: l10n.setHolidaysValue,
          onTap: () => context.go(Routes.moreHolidays),
        ),
      ]),
    ];
  }

  // ---- archive ----
  List<Widget> _archive(BuildContext context) {
    final l10n = context.l10n;
    return <Widget>[
      SettingsCard(children: <Widget>[
        SettingRow(
          key: const Key('more-archived'),
          icon: BhorIcons.archive,
          title: l10n.shellTitleArchived,
          value: l10n.setArchivedValue,
          onTap: () => _openSub(context, MoreSub.archivedBatches),
        ),
        SettingRow(
          key: const Key('more-left'),
          icon: BhorIcons.leftStudents,
          title: l10n.shellTitleLeft,
          value: l10n.setLeftValue,
          onTap: () => _openSub(context, MoreSub.leftStudents),
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
          child: BhorSegmented<Lang>(
            key: const Key('more-language'),
            segments: <BhorSegment<Lang>>[
              for (final Lang v in Lang.values)
                BhorSegment<Lang>(v, v == Lang.bn ? l10n.shellLangBangla : l10n.shellLangEnglish),
            ],
            value: lang,
            onChanged: (Lang v) => ref.read(langProvider.notifier).set(v),
          ),
        ),
        SettingControlRow(
          title: l10n.shellTheme,
          value: l10n.setThemeCurrent(themeName(mode)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ThemeSwatches(
                selected: mode,
                labelOf: themeName,
                onChanged: (ThemeMode v) => ref.read(themeModeProvider.notifier).set(v),
              ),
            ],
          ),
        ),
      ]),
      SettingsCard(children: <Widget>[
        SettingControlRow(
          title: l10n.setWeekStart,
          value: fmt.weekdayName(weekStart),
          child: BhorSegmented<int>(
            key: const Key('more-week-start'),
            segments: <BhorSegment<int>>[
              for (final int v in const <int>[6, 7, 1]) BhorSegment<int>(v, fmt.weekdayShort(v)),
            ],
            value: weekStart,
            onChanged: (int v) => saveSetting<int>(context, ref, SettingKeys.weekStart, v),
          ),
        ),
        SettingSwitchRow(
          key: const Key('more-reduced-effects'),
          icon: BhorIcons.sparkle,
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
    final BhorThemeData b = context.bhor;
    Widget pad(Widget child) =>
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: child);
    return <Widget>[
      SettingsCard(dividers: false, children: <Widget>[
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
              Icon(BhorIcons.checkCircle, size: 18, color: b.colors.text3),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.setAutoSaved, style: b.type.meta),
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
        icon: BhorIcons.info,
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
        icon: BhorIcons.remind,
        title: l10n.setTestReminder,
        value: l10n.setTestReminderValue,
        onTap: () => sendTestReminder(context),
      ));
    }

    return <Widget>[
      SettingsCard(children: <Widget>[
        SettingSwitchRow(
          key: const Key('more-reminders-switch'),
          icon: BhorIcons.bell,
          title: l10n.setRemindersSwitch,
          subtitle: enabled ? l10n.setRemindersOnValue : l10n.setRemindersOffValue,
          value: enabled,
          onChanged: (bool on) => _toggleReminders(context, ref, on),
        ),
        Builder(
          builder: (BuildContext rowContext) => SettingRow(
          key: const Key('more-default-lead'),
          icon: BhorIcons.clock,
          title: l10n.setDefaultLead,
          value: l10n.setLeadValue(fmt.digits(lead.toString())),
          onTap: () async {
            final int? v = await showIntChoiceSheet(
              rowContext,
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
        )),
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
        Builder(
          builder: (BuildContext rowContext) => SettingRow(
          key: const Key('more-cutoff-day'),
          icon: BhorIcons.calendar,
          title: l10n.setCutoffDay,
          value: l10n.setCutoffValue(fmt.digits(cutoff.toString())),
          onTap: () async {
            final int? v = await showIntChoiceSheet(
              rowContext,
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
        )),
        SettingRow(
          key: const Key('more-payment-methods'),
          icon: BhorIcons.fees,
          title: l10n.shellTitlePaymentMethods,
          value: l10n.setPaymentMethodsValue(fmt.digits(methods.toString())),
          onTap: () => openSettingsSubPage(
            context,
            route: Routes.morePaymentMethods,
            title: l10n.shellTitlePaymentMethods,
            width: 480,
            builder: (BuildContext _) => const PaymentMethodsScreen(embedded: true),
          ),
        ),
      ]),
      SettingsCard(children: <Widget>[
        SettingRow(
          key: const Key('more-template-reminder'),
          icon: BhorIcons.edit,
          title: l10n.shellTitleTemplateReminder,
          value: _templateValue(l10n, ref, TemplateKind.reminder, lang),
          onTap: () => openSettingsSubPage(
            context,
            route: Routes.moreTemplate(TemplateKind.reminder.code),
            title: l10n.shellTitleTemplateReminder,
            width: TemplateEditorScreen.panelWidth,
            builder: (BuildContext _) => TemplateEditorScreen(kind: TemplateKind.reminder.code, embedded: true),
          ),
        ),
        SettingRow(
          key: const Key('more-template-receipt'),
          icon: BhorIcons.receipt,
          title: l10n.shellTitleTemplateReceipt,
          value: _templateValue(l10n, ref, TemplateKind.receipt, lang),
          onTap: () => openSettingsSubPage(
            context,
            route: Routes.moreTemplate(TemplateKind.receipt.code),
            title: l10n.shellTitleTemplateReceipt,
            width: TemplateEditorScreen.panelWidth,
            builder: (BuildContext _) => TemplateEditorScreen(kind: TemplateKind.receipt.code, embedded: true),
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
          icon: BhorIcons.info,
          title: l10n.setVersion,
          value: version,
        ),
        SettingExpandRow(
          key: const Key('more-font-credit'),
          icon: BhorIcons.notes,
          title: l10n.setFontCredit,
          value: l10n.setFontCreditValue,
          body: l10n.setFontCreditBody,
        ),
        SettingRow(
          key: const Key('more-help'),
          icon: BhorIcons.info,
          title: l10n.shellTitleHelp,
          value: l10n.setHelpValue,
          onTap: () => openSettingsSubPage(
            context,
            route: Routes.moreHelp,
            title: l10n.shellTitleHelp,
            width: 560,
            builder: (BuildContext _) => const HelpScreen(embedded: true),
          ),
        ),
        SettingRow(
          key: const Key('more-diagnostics'),
          icon: BhorIcons.chart,
          title: l10n.shellTitleDiagnostics,
          value: l10n.setDiagnosticsValue,
          onTap: () => openSettingsSubPage(
            context,
            route: Routes.moreDiagnostics,
            title: l10n.shellTitleDiagnostics,
            width: 560,
            builder: (BuildContext _) => const DiagnosticsScreen(embedded: true),
          ),
        ),
      ]),
    ];
  }
}
