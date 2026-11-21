// Attendance today (UX 3b): classes with a roll call out of the classes held
// today, the overall present rate as a big number, and the weakest class.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
import 'package:attendance_alamin/features/home/widgets/tile_frame.dart';

class AttendanceTodayTile extends ConsumerWidget {
  const AttendanceTodayTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final DayAttendance? a =
        ref.watch(todayAttendanceProvider(ref.watch(todayProvider))).value;

    final Widget header = TileHeader(
      icon: BhorIcons.rollCall,
      title: l10n.todayAttendanceTitle,
    );
    if (a == null) {
      return TileFrame(header: header, child: const BhorSkeleton(height: 96, radius: 12));
    }
    if (a.total == 0) {
      return TileFrame(
        header: header,
        child: TileMessage(
          icon: BhorIcons.holiday,
          message: l10n.todayAttendanceNone,
        ),
      );
    }

    final int? percent = a.percent;
    final Color on = b.colors.ok;
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
                child: percent == null
                    ? Text('—', maxLines: 1, style: BhorType.tabular(b.type.display))
                    : BhorCountUp(
                        value: percent,
                        format: (num v) => fmt.percent(v.round()),
                        style: b.type.display,
                      ),
              ),
              Text(
                a.taken == 0 ? l10n.todayAttendanceNotYet : l10n.todayAttendanceRate,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: b.type.meta,
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  for (int i = 0; i < pips; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: BhorSpace.s4),
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: i < a.taken ? on : b.colors.surface2,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: i < a.taken
                                ? Icon(BhorIcons.check, size: 10, color: b.colors.surface)
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: BhorSpace.s8),
              Text(
                l10n.todayAttendanceTaken(fmt.number(a.taken), fmt.number(a.total)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: b.type.body,
              ),
              if (lowest != null && a.lowestPercent != null)
                Text(
                  l10n.todayAttendanceLowest(lowest.batch.name, fmt.percent(a.lowestPercent!)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: b.type.meta,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
