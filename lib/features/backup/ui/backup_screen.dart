// Backup screen (UX 2f, 3b): the last-backup line, "take a backup", "add a
// backup" and the safety copies (last 3) with a one-tap way back. On wide
// windows the three cards stand side by side and fill the height.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/data/backup/backup_providers.dart';
import 'package:attendance_alamin/data/backup/backup_repository.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/features/backup/backup_entry.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_state.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_text.dart';
import 'package:attendance_alamin/features/reminders/reminders_entry.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
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
    final double g = WindowClass.of(context).gutter;
    final bool embedded = PaneScope.isEmbedded(context);
    final List<SafetyCopyInfo> copies =
        ref.watch(safetyCopiesProvider).value ?? const <SafetyCopyInfo>[];

    final Widget status = const _LastBackupCard();
    Widget exportCard(bool fill) => _ActionCard(
      key: const Key('backup-export-card'),
      fill: fill,
      icon: Icons.save_alt_outlined,
      title: l10n.backupExportTitle,
      body: l10n.backupExportBody,
      button: l10n.backupExportButton,
      buttonKey: const Key('backup-export-button'),
      onPressed: () => runExportBackup(context),
    );
    Widget importCard(bool fill) => _ActionCard(
      key: const Key('backup-import-card'),
      fill: fill,
      icon: Icons.upload_file_outlined,
      title: l10n.backupImportTitle,
      body: l10n.backupImportBody,
      button: l10n.backupImportButton,
      buttonKey: const Key('backup-import-button'),
      outlined: true,
      onPressed: () => runImportBackup(context),
    );

    return BhorScaffold(
      header: BhorHeader(
        title: l10n.shellTitleBackup,
        showBack: embedded ? false : null,
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double w = c.maxWidth;
          if (w >= WindowClass.expandedMin && c.hasBoundedHeight) {
            // Three columns that fill the height; the copies list scrolls.
            return Padding(
              padding: EdgeInsets.fromLTRB(g, 8, g, g),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  status,
                  SizedBox(height: g),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(flex: 5, child: exportCard(true)),
                        SizedBox(width: g),
                        Expanded(flex: 5, child: importCard(true)),
                        SizedBox(width: g),
                        Expanded(
                          flex: 6,
                          child: _SafetyCard(copies: copies, restoring: _restoring, onRestore: _restore, fill: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          final bool twoUp = w >= WindowClass.mediumMin;
          return ListView(
            padding: EdgeInsets.fromLTRB(g, 8, g, g),
            children: <Widget>[
              status,
              SizedBox(height: g),
              if (twoUp)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: exportCard(false)),
                      SizedBox(width: g),
                      Expanded(child: importCard(false)),
                    ],
                  ),
                )
              else ...<Widget>[
                exportCard(false),
                SizedBox(height: g),
                importCard(false),
              ],
              SizedBox(height: g),
              _SafetyCard(copies: copies, restoring: _restoring, onRestore: _restore, fill: false),
            ],
          );
        },
      ),
    );
  }
}

/// "শেষ ব্যাকআপ: ১২ দিন আগে"; an info chip when it is stale or missing.
class _LastBackupCard extends ConsumerWidget {
  const _LastBackupCard();

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
      child: Row(
        children: <Widget>[
          Icon(stale ? Icons.info_outline : Icons.check_circle_outline, color: b.colors.accent),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.button,
    required this.buttonKey,
    required this.onPressed,
    required this.fill,
    this.outlined = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String button;
  final Key buttonKey;
  final VoidCallback onPressed;

  /// On a tall pane the content sits in the middle of the card.
  final bool fill;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final Widget action = BhorButton(
      key: buttonKey,
      variant: outlined ? BhorButtonVariant.secondary : BhorButtonVariant.primary,
      label: button,
      expand: true,
      onPressed: onPressed,
    );
    return BhorCard(
      padding: const EdgeInsets.all(BhorSpace.s20),
      child: Builder(
        builder: (BuildContext context) {
          final Widget column = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, color: b.colors.accent, size: 28),
                  const SizedBox(width: BhorSpace.s12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: b.type.title),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BhorSpace.s12),
              Text(body, style: b.type.body.copyWith(color: b.colors.text2)),
              const SizedBox(height: BhorSpace.s20),
              action,
            ],
          );
          if (fill) return Center(child: SingleChildScrollView(child: column));
          return column;
        },
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({
    required this.copies,
    required this.restoring,
    required this.onRestore,
    required this.fill,
  });

  final List<SafetyCopyInfo> copies;
  final bool restoring;
  final void Function(SafetyCopyInfo copy) onRestore;

  /// True on a bounded-height pane: the list takes the remaining height.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;

    final Widget list = copies.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: BhorSpace.s16),
            child: Text(
              l10n.backupSafetyEmpty,
              key: const Key('backup-safety-empty'),
              style: b.type.body.copyWith(color: b.colors.text2),
            ),
          )
        : Column(
            children: <Widget>[
              for (int i = 0; i < copies.length; i++) ...<Widget>[
                if (i > 0) Container(height: 1, color: b.colors.line),
                _SafetyRow(copy: copies[i], enabled: !restoring, onRestore: () => onRestore(copies[i])),
              ],
            ],
          );

    return BhorCard(
      key: const Key('backup-safety-card'),
      padding: const EdgeInsets.all(BhorSpace.s20),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.restore, color: b.colors.accent, size: 28),
              const SizedBox(width: BhorSpace.s12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.backupSafetyTitle, style: b.type.title),
                ),
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s8),
          Text(l10n.backupSafetyBody, style: b.type.body.copyWith(color: b.colors.text2)),
          const SizedBox(height: BhorSpace.s8),
          if (fill) Expanded(child: SingleChildScrollView(child: list)) else list,
        ],
      ),
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
