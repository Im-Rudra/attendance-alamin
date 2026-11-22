// One batch on the Batches tab (UX table: name, days + time, student count,
// today's attendance %, dues mini-badge). Right-click / long-press opens the
// context menu on desktop.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
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
    final BhorThemeData th = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final LocalDate today = ref.watch(todayProvider);
    final int? pct = todayPercent(ref.watch(dayPlanProvider(today)).value, data.batch.id);
    final String schedule = scheduleSummary(fmt, data.slots);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: onSecondaryTap == null
          ? null
          : (TapUpDetails d) => onSecondaryTap!(d.globalPosition),
      // The one selection style (review B2): accent-tint fill + leading bar,
      // text keeps its normal colours in both themes.
      child: BhorCard(
        selected: selected,
        onTap: onTap,
        semanticLabel: data.batch.name,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BatchAvatar(name: data.batch.name, size: 40),
            const SizedBox(width: BhorSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Full-width title (2-line clamp); the pill moved down so it
                  // never squeezes the title into awkward wraps (B1).
                  Text(
                    batchLabel(l10n, data.subjectName, data.batch.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: th.type.heading,
                  ),
                  const SizedBox(height: BhorSpace.s4),
                  Text(
                    schedule.isEmpty ? l10n.batchNoSlots : schedule,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: th.type.body.copyWith(color: th.colors.text2),
                  ),
                  const SizedBox(height: BhorSpace.s8),
                  Wrap(
                    spacing: BhorSpace.s12,
                    runSpacing: BhorSpace.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      BillingPill(type: data.batch.billingType),
                      Text(l10n.batchStudentCount(fmt.number(data.studentCount)), style: th.type.label),
                      if (pct != null)
                        Text(
                          l10n.batchTodayPercent(fmt.percent(pct)),
                          style: th.type.label.copyWith(color: th.colors.text2),
                        ),
                      BatchDuesBadge(batchId: data.batch.id),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
