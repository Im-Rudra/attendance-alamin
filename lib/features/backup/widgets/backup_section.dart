// The one Backup UI (review M3): it lives inside the settings column (More >
// Backup) and, on phones, on its own page. A primary card on top (when the last
// backup was made, plus the "Create backup" primary button), then one card of
// rows: restore, safety copies, CSV export, the backup reminder and the device
// name. Safety copies open in a side panel (a sheet on phones).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/data/backup/backup_providers.dart';
import 'package:attendance_alamin/data/backup/backup_repository.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/features/backup/backup_entry.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_state.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_text.dart';
import 'package:attendance_alamin/features/extras/extras_entry.dart';
import 'package:attendance_alamin/features/reminders/reminders_entry.dart';
import 'package:attendance_alamin/features/settings/controllers/settings_providers.dart';
import 'package:attendance_alamin/features/settings/widgets/int_choice_sheet.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_text_field.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Backup reminder presets (days); 0 = off.
const List<int> kBackupReminderOptions = <int>[0, 3, 7, 14, 30];

class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final int remindDays =
        ref.watch(backupReminderDaysProvider).value ?? SettingKeys.backupReminderDays.defaultValue;

    String remindText(int n) =>
        n == 0 ? l10n.setBackupReminderOff : l10n.setBackupReminderEvery(fmt.digits(n.toString()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _PrimaryBackupCard(),
        const SizedBox(height: BhorSpace.s12),
        SettingsCard(children: <Widget>[
          SettingRow(
            key: const Key('more-restore'),
            icon: BhorIcons.backupDown,
            title: l10n.setRestore,
            value: l10n.setRestoreValue,
            onTap: () => runImportBackup(context),
          ),
          SettingRow(
            key: const Key('more-safety-copy'),
            icon: BhorIcons.undo,
            title: l10n.setSafetyCopy,
            value: l10n.setSafetyCopyValue,
            onTap: () => showSafetyCopiesPanel(context),
          ),
          SettingRow(
            key: const Key('more-csv-export'),
            icon: BhorIcons.chart,
            title: l10n.setCsvExport,
            value: l10n.setCsvExportValue,
            onTap: () => runCsvExport(context, month: ref.read(todayProvider).yearMonth),
          ),
          Builder(
            builder: (BuildContext rowContext) => SettingRow(
              key: const Key('more-backup-reminder'),
              icon: BhorIcons.clock,
              title: l10n.setBackupReminder,
              value: remindText(remindDays),
              onTap: () async {
                final int? v = await showIntChoiceSheet(
                  rowContext,
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s12, BhorSpace.s16, BhorSpace.s12),
            child: SettingTextField(
              key: const Key('more-device-name'),
              settingKey: SettingKeys.deviceName,
              label: l10n.setDeviceName,
              hint: l10n.setDeviceNameHint,
              helper: l10n.setDeviceNameHelper,
            ),
          ),
        ]),
      ],
    );
  }
}

/// "শেষ ব্যাকআপ: ১২ দিন আগে", an info chip when it is stale or missing, and
/// the primary "create backup" button, all on one card.
class _PrimaryBackupCard extends ConsumerWidget {
  const _PrimaryBackupCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final int? days = ref.watch(backupDaysSinceProvider);
    final bool stale = days == null || days > kBackupStaleDays;
    final String line = days == null
        ? l10n.backupLastNever
        : l10n.backupLastLine(
            days == 0 ? l10n.backupLastToday : l10n.backupLastAgo(fmt.number(days)),
          );
    return BhorCard(
      key: const Key('backup-last-card'),
      padding: const EdgeInsets.all(BhorSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(stale ? BhorIcons.info : BhorIcons.checkCircle, color: b.colors.accent),
              const SizedBox(width: BhorSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(line, key: const Key('backup-last-line'), style: b.type.heading),
                    if (stale) ...<Widget>[
                      const SizedBox(height: BhorSpace.s8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: b.colors.accentTint,
                          borderRadius: BorderRadius.circular(BhorRadius.chip),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(
                            l10n.backupStaleNote,
                            key: const Key('backup-stale-chip'),
                            style: b.type.label.copyWith(color: b.colors.accent),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: BhorSpace.s8),
                    Text(l10n.backupExportBody, style: b.type.body.copyWith(color: b.colors.text2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s16),
          BhorButton(
            key: const Key('backup-export-button'),
            label: l10n.backupExportButton,
            icon: BhorIcons.backupUp,
            expand: true,
            onPressed: () => runExportBackup(context),
          ),
        ],
      ),
    );
  }
}

/// The last safety copies (UX 2f) in a side panel (a sheet on phones), each
/// with a one-tap way back after a confirmation.
Future<void> showSafetyCopiesPanel(BuildContext context) => showBhorPanel<void>(
      context,
      title: context.l10n.backupSafetyTitle,
      width: 480,
      builder: (BuildContext _) => const SafetyCopiesList(),
    );

class SafetyCopiesList extends ConsumerStatefulWidget {
  const SafetyCopiesList({super.key});

  @override
  ConsumerState<SafetyCopiesList> createState() => _SafetyCopiesListState();
}

class _SafetyCopiesListState extends ConsumerState<SafetyCopiesList> {
  bool _restoring = false;

  Future<void> _restore(SafetyCopyInfo copy) async {
    final l10n = context.l10n;
    final bool ok = await showBhorConfirm(
      context,
      title: l10n.backupRestoreTitle,
      message: l10n.backupRestoreBody,
      confirmLabel: l10n.backupRestoreConfirm,
    );
    if (!ok || !mounted) return;
    setState(() => _restoring = true);
    try {
      await ref.read(backupRepositoryProvider).restoreSafetyCopy(copy.id);
      if (mounted) {
        requestRemindersReplan(context);
        BhorToast.show(context, message: l10n.backupRestoreDone, tone: BhorTone.ok);
      }
    } on Object catch (e) {
      if (mounted) BhorToast.show(context, message: errorText(l10n, e), tone: BhorTone.danger);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final List<SafetyCopyInfo> copies =
        ref.watch(safetyCopiesProvider).value ?? const <SafetyCopyInfo>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.backupSafetyBody, style: b.type.body.copyWith(color: b.colors.text2)),
        const SizedBox(height: BhorSpace.s8),
        if (copies.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BhorSpace.s16),
            child: Text(
              l10n.backupSafetyEmpty,
              key: const Key('backup-safety-empty'),
              style: b.type.body.copyWith(color: b.colors.text2),
            ),
          )
        else
          for (int i = 0; i < copies.length; i++) ...<Widget>[
            if (i > 0) Container(height: 1, color: b.colors.line),
            _SafetyRow(copy: copies[i], enabled: !_restoring, onRestore: () => _restore(copies[i])),
          ],
      ],
    );
  }
}

class _SafetyRow extends ConsumerWidget {
  const _SafetyRow({required this.copy, required this.enabled, required this.onRestore});

  final SafetyCopyInfo copy;
  final bool enabled;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final CenterTime center = ref.watch(centerTimeProvider);
    final String reason = copy.reason == SafetyCopyReason.beforeRestore
        ? l10n.backupSafetyReasonRestore
        : l10n.backupSafetyReasonImport;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BhorSpace.s8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(backupWhenText(l10n, fmt, center, copy.createdAtMs), style: b.type.body),
                  Text(reason, style: b.type.meta),
                ],
              ),
            ),
            const SizedBox(width: BhorSpace.s8),
            BhorButton(
              key: Key('backup-restore-${copy.id}'),
              variant: BhorButtonVariant.secondary,
              label: l10n.backupSafetyRestore,
              onPressed: enabled ? onRestore : null,
            ),
          ],
        ),
      ),
    );
  }
}
