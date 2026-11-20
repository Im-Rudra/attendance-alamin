// Backup tile / nudge (Product F18): the age of the last export and a button to
// make a new one. It turns info-coloured once the nudge is due. Wide windows
// always show it; phones show it only when the nudge is due.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/features/backup/backup_entry.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
import 'package:attendance_alamin/features/home/widgets/tile_frame.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class BackupNudgeTile extends ConsumerWidget {
  const BackupNudgeTile({super.key, this.onlyWhenDue = false, this.gapBelow = 0});

  /// Render nothing unless the nudge is due (phone and medium pages).
  final bool onlyWhenDue;

  /// Space under the tile, only added when it is shown.
  final double gapBelow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final BackupStatus? s = ref.watch(todayBackupProvider).value;

    final Widget header = TileHeader(
      icon: Icons.cloud_upload_outlined,
      title: l10n.todayBackupTitle,
    );
    if (s == null) {
      return onlyWhenDue
          ? const SizedBox.shrink()
          : TileFrame(header: header, child: const SizedBox(height: 96));
    }
    if (onlyWhenDue && !s.due) return const SizedBox.shrink();

    final Color chipBg = s.due ? tokens.infoContainer : tokens.track;
    final Color chipFg = s.due ? tokens.info : tokens.textPrimary;

    final Widget tile = TileFrame(
      header: header,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(s.due ? Icons.info_outline : Icons.verified_outlined,
                          size: 20, color: chipFg),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _statusText(l10n, fmt, s),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelLarge?.copyWith(color: chipFg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.due ? l10n.todayBackupDueHint : l10n.todayBackupOkHint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: s.due
                ? FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => runExportBackup(context),
                    child: Text(l10n.todayBackupButton),
                  )
                : FilledButton.tonal(
                    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => runExportBackup(context),
                    child: Text(l10n.todayBackupButton),
                  ),
          ),
        ],
      ),
    );
    return gapBelow == 0
        ? tile
        : Padding(padding: EdgeInsets.only(bottom: gapBelow), child: tile);
  }

  String _statusText(AppLocalizations l10n, AppFormat fmt, BackupStatus s) {
    final int? days = s.daysAgo;
    if (days == null) return l10n.todayBackupNever;
    if (days == 0) return l10n.todayBackupToday;
    return l10n.todayBackupAge(fmt.number(days));
  }
}
