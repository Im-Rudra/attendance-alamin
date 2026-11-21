// The live clash card of the reschedule / extra sheets: names up to three
// clashing classes and offers the nearest free times (Product 3.10).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/classes/controllers/class_controller.dart';

class ClashPanel extends ConsumerWidget {
  const ClashPanel({super.key, required this.result, required this.durationMin, required this.onPickStart});

  final SlotCheckResult result;
  final int durationMin;

  /// Called with the start minute of a suggested free time.
  final ValueChanged<int> onPickStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final List<BatchSchedule> schedules = ref.watch(schedulesProvider).value ?? const <BatchSchedule>[];
    final Map<String, BatchSchedule> byBatch = <String, BatchSchedule>{
      for (final BatchSchedule s in schedules) s.batch.id: s,
    };

    final List<String> lines = <String>[
      for (final ClashGroup g in result.groups.take(3))
        clashLine(l10n: l10n, fmt: fmt, group: g, byBatch: byBatch),
    ];
    final int more = result.groups.length > 3 ? result.groups.length - 3 : 0;

    final List<BhorClashFix> fixes = <BhorClashFix>[];
    final FreeSuggestion? s = result.suggestion;
    if (s != null) {
      final int? earlier = s.earlierStartMin;
      final int? later = s.laterStartMin;
      final int? primary = s.primaryStartMin;
      String range(int start) => fmt.timeRange(start, start + durationMin);
      if (primary != null) {
        fixes.add(BhorClashFix(
          label: l10n.clsFixUse(range(primary)),
          onTap: () => onPickStart(primary),
          primary: true,
        ));
      }
      if (earlier != null && earlier != primary) {
        fixes.add(BhorClashFix(
          label: l10n.clsFixEarlier(range(earlier)),
          onTap: () => onPickStart(earlier),
        ));
      }
      if (later != null && later != primary) {
        fixes.add(BhorClashFix(
          label: l10n.clsFixLater(range(later)),
          onTap: () => onPickStart(later),
        ));
      }
      if (earlier == null && later == null) lines.add(l10n.clsNoFreeTime);
    }

    return BhorClashCard(lines: lines, moreCount: more, fixes: fixes);
  }
}
