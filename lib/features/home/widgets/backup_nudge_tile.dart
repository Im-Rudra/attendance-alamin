// Backup tile / nudge (Product F18): the age of the last export and a button to
// make a new one. It turns info-coloured once the nudge is due. Wide windows
// always show it; phones show it only when the nudge is due.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
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
    final BhorThemeData b = context.bhor;
    final BackupStatus? s = ref.watch(todayBackupProvider).value;

    final Widget header = TileHeader(
      icon: BhorIcons.backupUp,
      title: l10n.todayBackupTitle,
    );
    if (s == null) {
      return onlyWhenDue
          ? const SizedBox.shrink()
          : TileFrame(header: header, child: const BhorSkeleton(height: 96, radius: 12));
    }
    if (onlyWhenDue && !s.due) return const SizedBox.shrink();

    final Color chipBg = s.due ? b.colors.accentTint : b.colors.surface2;
    final Color chipFg = s.due ? b.colors.accent : b.colors.text;

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
                  borderRadius: BorderRadius.circular(BhorRadius.control),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12, vertical: BhorSpace.s8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(s.due ? BhorIcons.info : BhorIcons.checkCircle,
                          size: 20, color: chipFg),
                      const SizedBox(width: BhorSpace.s8),
                      Flexible(
                        child: Text(
                          _statusText(l10n, fmt, s),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: b.type.label.copyWith(color: chipFg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: BhorSpace.s8),
              Text(
                s.due ? l10n.todayBackupDueHint : l10n.todayBackupOkHint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: b.type.meta,
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BhorButton(
              label: l10n.todayBackupButton,
              variant: s.due ? BhorButtonVariant.primary : BhorButtonVariant.secondary,
              onPressed: () => runExportBackup(context),
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
