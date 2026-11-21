// Week at a glance (extra-large bento tile): seven mini columns with the
// number of classes of each day and a marker for cancelled / extra classes.
// Tapping it opens the full week grid.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/widgets/state_pill.dart' show ClassState;
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
import 'package:attendance_alamin/features/home/widgets/tile_frame.dart';

class WeekGlanceTile extends ConsumerWidget {
  const WeekGlanceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final LocalDate today = ref.watch(todayProvider);
    final int weekStart = ref.watch(weekStartProvider).value ?? 6;
    final LocalDate first = weekStartFor(today, weekStart);
    final List<DayPlan>? plans = ref.watch(weekPlanProvider(first)).value;

    final Widget header = TileHeader(
      icon: BhorIcons.calendar,
      title: l10n.todayWeekTitle,
      trailing: BhorTooltip(
        message: l10n.todayWeekOpen,
        child: Icon(BhorIcons.chevronRight, color: b.colors.text2),
      ),
    );
    if (plans == null) {
      return TileFrame(header: header, child: const BhorSkeleton(height: 96, radius: 12));
    }
    return TileFrame(
      header: header,
      scroll: false,
      onTap: () => ref.read(todayViewProvider.notifier).set(TodayView.week),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < plans.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: BhorSpace.s4),
              Expanded(child: _DayColumn(plan: plans[i], isToday: plans[i].date == today)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.plan, required this.isToday});

  final DayPlan plan;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    int count = 0, cancelled = 0, extra = 0;
    for (final DayClass c in plan.classes) {
      if (c.cancelled) {
        cancelled++;
      } else {
        count++;
        if (c.state == ClassState.extra) extra++;
      }
    }
    final Color fg = isToday ? b.colors.accent : b.colors.text;
    final Color sub = isToday ? b.colors.accent : b.colors.text2;
    Widget marker(IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: sub),
            const SizedBox(width: BhorSpace.s4),
            Text(text, maxLines: 1, style: b.type.caption.copyWith(color: sub)),
          ],
        );
    return Semantics(
      container: true,
      label: l10n.todayWeekDay(fmt.weekdayName(plan.date.isoWeekday), fmt.number(count)),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isToday ? b.colors.accentTint : b.colors.surface2,
          borderRadius: BorderRadius.circular(BhorRadius.control),
          border: Border.all(color: isToday ? b.colors.accentLine : b.colors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: BhorSpace.s8, horizontal: BhorSpace.s4),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    fmt.weekdayShort(plan.date.isoWeekday),
                    maxLines: 1,
                    style: b.type.label.copyWith(color: sub),
                  ),
                  Text(
                    fmt.number(count),
                    maxLines: 1,
                    style: BhorType.tabular(b.type.display).copyWith(color: fg),
                  ),
                  Text(
                    fmt.digits('${plan.date.day}'),
                    maxLines: 1,
                    style: b.type.caption.copyWith(color: sub),
                  ),
                  if (cancelled > 0) marker(BhorIcons.absent, fmt.number(cancelled)),
                  if (extra > 0) marker(BhorIcons.add, fmt.number(extra)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
