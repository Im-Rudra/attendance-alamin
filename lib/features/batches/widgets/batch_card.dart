// One batch on the Batches tab (UX table: name, days + time, student count,
// today's attendance %, dues mini-badge). Right-click / long-press opens the
// context menu on desktop.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';

class BatchCard extends ConsumerWidget {
  const BatchCard({
    super.key,
    required this.data,
    required this.selected,
    required this.onTap,
    this.onSecondaryTap,
  });

  final BatchCardData data;
  final bool selected;
  final VoidCallback onTap;

  /// Right-click (desktop) with the global pointer position.
  final ValueChanged<Offset>? onSecondaryTap;

  /// Today's attendance percent of this batch, or null when no class was
  /// taken yet.
  static int? todayPercent(DayPlan? plan, String batchId) {
    if (plan == null) return null;
    for (final DayClass c in plan.classes) {
      if (c.batch.id != batchId) continue;
      final int? p = c.tally?.percent;
      if (p != null) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final LocalDate today = ref.watch(todayProvider);
    final int? pct = todayPercent(ref.watch(dayPlanProvider(today)).value, data.batch.id);
    final String schedule = scheduleSummary(fmt, data.slots);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: onSecondaryTap == null
          ? null
          : (TapUpDetails d) => onSecondaryTap!(d.globalPosition),
      child: Semantics(
        button: true,
        selected: selected,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected ? Border.all(color: tokens.accent, width: 2) : null,
          ),
          child: GlassCard(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        data.batch.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BillingPill(type: data.batch.billingType),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  schedule.isEmpty ? l10n.batchNoSlots : schedule,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      l10n.batchStudentCount(fmt.number(data.studentCount)),
                      style: tt.labelLarge?.copyWith(color: tokens.textPrimary),
                    ),
                    if (pct != null)
                      Text(
                        l10n.batchTodayPercent(fmt.percent(pct)),
                        style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                      ),
                    BatchDuesBadge(batchId: data.batch.id),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
