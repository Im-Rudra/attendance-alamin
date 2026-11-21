// Backup screen (UX 2f, 3b): the last-backup line, "take a backup", "add a
// backup" and the safety copies (last 3) with a one-tap way back. On wide
// windows the three cards stand side by side and fill the height.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
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
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await showConfirmDialog(
      context,
      title: l10n.backupRestoreTitle,
      body: l10n.backupRestoreBody,
      confirmLabel: l10n.backupRestoreConfirm,
    );
    if (!ok || !mounted) return;
    setState(() => _restoring = true);
    try {
      await ref.read(backupRepositoryProvider).restoreSafetyCopy(copy.id);
      if (mounted) requestRemindersReplan(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupRestoreDone)));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Semantics(header: true, child: Text(l10n.shellTitleBackup)),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final int? days = ref.watch(backupDaysSinceProvider);
    final bool stale = days == null || days > kBackupStaleDays;
    final String line = days == null
        ? l10n.backupLastNever
        : l10n.backupLastLine(
            days == 0 ? l10n.backupLastToday : l10n.backupLastAgo(fmt.number(days)),
          );
    return GlassCard(
      key: const Key('backup-last-card'),
      dense: true,
      child: Row(
        children: <Widget>[
          Icon(stale ? Icons.info_outline : Icons.check_circle_outline,
              color: stale ? tokens.info : tokens.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(line, key: const Key('backup-last-line'), style: tt.titleMedium?.copyWith(color: tokens.textPrimary)),
                if (stale) ...<Widget>[
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.infoContainer,
                      borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(
                        l10n.backupStaleNote,
                        key: const Key('backup-stale-chip'),
                        style: tt.labelMedium?.copyWith(color: tokens.info),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final Widget action = outlined
        ? OutlinedButton(
            key: buttonKey,
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: Text(button),
          )
        : FilledButton(
            key: buttonKey,
            onPressed: onPressed,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: Text(button),
          );
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Builder(
        builder: (BuildContext context) {
          final Widget column = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, color: tokens.accent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: tt.titleLarge?.copyWith(color: tokens.textPrimary)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(body, style: tt.bodyLarge?.copyWith(color: tokens.textSecondary)),
              const SizedBox(height: 20),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;

    final Widget list = copies.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.backupSafetyEmpty,
              key: const Key('backup-safety-empty'),
              style: tt.bodyLarge?.copyWith(color: tokens.textSecondary),
            ),
          )
        : Column(
            children: <Widget>[
              for (int i = 0; i < copies.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, color: tokens.track),
                _SafetyRow(copy: copies[i], enabled: !restoring, onRestore: () => onRestore(copies[i])),
              ],
            ],
          );

    return GlassCard(
      key: const Key('backup-safety-card'),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.restore, color: tokens.accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.backupSafetyTitle, style: tt.titleLarge?.copyWith(color: tokens.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.backupSafetyBody, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
          const SizedBox(height: 8),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final CenterTime center = ref.watch(centerTimeProvider);
    final String reason = copy.reason == SafetyCopyReason.beforeRestore
        ? l10n.backupSafetyReasonRestore
        : l10n.backupSafetyReasonImport;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    backupWhenText(l10n, fmt, center, copy.createdAtMs),
                    style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
                  ),
                  Text(reason, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: Key('backup-restore-${copy.id}'),
              onPressed: enabled ? onRestore : null,
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(l10n.backupSafetyRestore),
            ),
          ],
        ),
      ),
    );
  }
}
