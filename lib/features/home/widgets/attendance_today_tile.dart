// Attendance today (UX 3b): classes with a roll call out of the classes held
// today, the overall present rate as a big number, and the weakest class.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
import 'package:attendance_alamin/features/home/widgets/tile_frame.dart';

class AttendanceTodayTile extends ConsumerWidget {
  const AttendanceTodayTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final DayAttendance? a =
        ref.watch(todayAttendanceProvider(ref.watch(todayProvider))).value;

    final Widget header = TileHeader(
      icon: Icons.fact_check_outlined,
      title: l10n.todayAttendanceTitle,
    );
    if (a == null) {
      return TileFrame(header: header, child: const SizedBox(height: 96));
    }
    if (a.total == 0) {
      return TileFrame(
        header: header,
        child: TileMessage(
          icon: Icons.weekend_outlined,
          message: l10n.todayAttendanceNone,
        ),
      );
    }

    final int? percent = a.percent;
    final present = AttendanceStatus.present.kind;
    final Color on = context.attendance.fill(present);
    final int pips = a.total > 12 ? 12 : a.total;
    final DayClass? lowest = a.lowest;

    return TileFrame(
      header: header,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  percent == null ? '—' : fmt.percent(percent),
                  maxLines: 1,
                  style: context.statNumber,
                ),
              ),
              Text(
                a.taken == 0 ? l10n.todayAttendanceNotYet : l10n.todayAttendanceRate,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  for (int i = 0; i < pips; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: i < a.taken ? on : tokens.track,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: i < a.taken
                                ? Icon(Icons.check, size: 10, color: context.attendance.text(present))
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.todayAttendanceTaken(fmt.number(a.taken), fmt.number(a.total)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(color: tokens.textPrimary),
              ),
              if (lowest != null && a.lowestPercent != null)
                Text(
                  l10n.todayAttendanceLowest(lowest.batch.name, fmt.percent(a.lowestPercent!)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
