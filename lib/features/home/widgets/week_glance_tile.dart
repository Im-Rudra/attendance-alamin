// Week at a glance (extra-large bento tile): seven mini columns with the
// number of classes of each day and a marker for cancelled / extra classes.
// Tapping it opens the full week grid.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
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
    final tokens = context.aurora;
    final LocalDate today = ref.watch(todayProvider);
    final int weekStart = ref.watch(weekStartProvider).value ?? 6;
    final LocalDate first = weekStartFor(today, weekStart);
    final List<DayPlan>? plans = ref.watch(weekPlanProvider(first)).value;

    final Widget header = TileHeader(
      icon: Icons.calendar_view_week_outlined,
      title: l10n.todayWeekTitle,
      trailing: Tooltip(
        message: l10n.todayWeekOpen,
        child: Icon(Icons.chevron_right, color: tokens.textSecondary),
      ),
    );
    if (plans == null) {
      return TileFrame(header: header, child: const SizedBox(height: 96));
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
              if (i > 0) const SizedBox(width: 6),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    int count = 0, cancelled = 0, extra = 0;
    for (final DayClass c in plan.classes) {
      if (c.cancelled) {
        cancelled++;
      } else {
        count++;
        if (c.state == ClassState.extra) extra++;
      }
    }
    final Color fg = isToday ? tokens.onAccentContainer : tokens.textPrimary;
    final Color sub = isToday ? tokens.onAccentContainer : tokens.textSecondary;
    Widget marker(IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: sub),
            const SizedBox(width: 2),
            Text(text, maxLines: 1, style: tt.labelSmall?.copyWith(color: sub)),
          ],
        );
    return Semantics(
      container: true,
      label: l10n.todayWeekDay(fmt.weekdayName(plan.date.isoWeekday), fmt.number(count)),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isToday ? tokens.accentContainer : tokens.surfaceDense,
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
          border: Border.all(color: tokens.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    fmt.weekdayShort(plan.date.isoWeekday),
                    maxLines: 1,
                    style: tt.labelMedium?.copyWith(color: sub),
                  ),
                  Text(
                    fmt.number(count),
                    maxLines: 1,
                    style: tt.headlineSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    fmt.digits('${plan.date.day}'),
                    maxLines: 1,
                    style: tt.labelSmall?.copyWith(color: sub),
                  ),
                  if (cancelled > 0) marker(Icons.block, fmt.number(cancelled)),
                  if (extra > 0) marker(Icons.add, fmt.number(extra)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
