// Phone day strip (UX 2g): the seven days of the selected date's week with a
// class-count dot, week arrows (or a swipe) and an [আজ] chip back to today.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/classes/controllers/class_controller.dart';

/// 7-day strip with class-count dots.
class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.selected, required this.onSelected});

  final LocalDate selected;
  final ValueChanged<LocalDate> onSelected;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        final l10n = context.l10n;
        final fmt = context.fmt;
        final tokens = context.aurora;
        final TextTheme tt = Theme.of(context).textTheme;
        final int weekStart = ref.watch(weekStartProvider).value ?? 6;
        final LocalDate today = ref.watch(todayProvider);
        final LocalDate first = weekStartOf(selected, weekStart);
        final List<DayPlan>? plans = ref.watch(weekPlanProvider(first)).value;
        final bool atToday = selected == today;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (DragEndDetails d) {
            final double v = d.primaryVelocity ?? 0;
            if (v < -250) {
              onSelected(selected.addDays(7));
            } else if (v > 250) {
              onSelected(selected.addDays(-7));
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: l10n.clsPrevWeek,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => onSelected(selected.addDays(-7)),
                  ),
                  Expanded(
                    child: Text(
                      '${fmt.dateShort(first)} – ${fmt.dateShort(first.addDays(6))}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelLarge?.copyWith(color: tokens.textSecondary),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.clsNextWeek,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => onSelected(selected.addDays(7)),
                  ),
                  if (!atToday)
                    TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: () => onSelected(today),
                      child: Text(l10n.commonToday),
                    ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < 7; i++)
                    Expanded(
                      child: _DayChip(
                        date: first.addDays(i),
                        count: plans == null || i >= plans.length
                            ? 0
                            : plans[i].classes.where((DayClass c) => !c.cancelled).length,
                        selected: first.addDays(i) == selected,
                        isToday: first.addDays(i) == today,
                        onTap: () => onSelected(first.addDays(i)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.count,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final LocalDate date;
  final int count;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final Color fg = selected ? tokens.onAccentContainer : (isToday ? tokens.accent : tokens.textPrimary);
    final int dots = math.min(count, 3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Semantics(
        button: true,
        selected: selected,
        label: context.l10n.clsDayChip(fmt.weekdayName(date.isoWeekday), fmt.digits('$count')),
        excludeSemantics: true,
        child: Material(
          color: selected ? tokens.accentContainer : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
            side: isToday && !selected ? BorderSide(color: tokens.accent) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56, minWidth: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      fmt.weekdayShort(date.isoWeekday),
                      maxLines: 1,
                      style: tt.labelMedium?.copyWith(color: fg),
                    ),
                    Text(
                      fmt.digits('${date.day}'),
                      style: tt.titleMedium?.copyWith(
                        color: fg,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    SizedBox(
                      height: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (int k = 0; k < dots; k++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1.5),
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: tokens.accent, shape: BoxShape.circle),
                                child: const SizedBox(width: 6, height: 6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
