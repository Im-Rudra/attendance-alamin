// The live clash card of the reschedule / extra sheets: names up to three
// clashing classes and offers the nearest free times (Product 3.10).

import 'package:flutter/material.dart' show Icons;
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

    final List<ClashFix> fixes = <ClashFix>[];
    final FreeSuggestion? s = result.suggestion;
    if (s != null) {
      final int? earlier = s.earlierStartMin;
      final int? later = s.laterStartMin;
      final int? primary = s.primaryStartMin;
      String range(int start) => fmt.timeRange(start, start + durationMin);
      if (primary != null) {
        fixes.add(ClashFix(
          label: l10n.clsFixUse(range(primary)),
          onTap: () => onPickStart(primary),
          primary: true,
        ));
      }
      if (earlier != null && earlier != primary) {
        fixes.add(ClashFix(
          label: l10n.clsFixEarlier(range(earlier)),
          onTap: () => onPickStart(earlier),
        ));
      }
      if (later != null && later != primary) {
        fixes.add(ClashFix(
          label: l10n.clsFixLater(range(later)),
          onTap: () => onPickStart(later),
        ));
      }
      if (earlier == null && later == null) lines.add(l10n.clsNoFreeTime);
    }

    return ClashCard(lines: lines, moreCount: more, fixes: fixes);
  }
}

/// One fix offered by a [ClashCard].
class ClashFix {
  const ClashFix({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;
}

/// The red "classes clash" card: the clashing lines and 1-3 fix buttons. A
/// live region, so it is announced when it appears.
class ClashCard extends StatelessWidget {
  const ClashCard({super.key, required this.lines, this.moreCount = 0, this.fixes = const <ClashFix>[]});

  final List<String> lines;
  final int moreCount;
  final List<ClashFix> fixes;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final Color on = b.colors.danger;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: b.colors.dangerBg,
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(color: on.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, color: on, size: 24),
                  const SizedBox(width: BhorSpace.s8),
                  Expanded(child: Text(l10n.uiConflictTitle, style: b.type.heading.copyWith(color: on))),
                ],
              ),
              const SizedBox(height: BhorSpace.s8),
              for (final String line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: BhorSpace.s4),
                  child: Text(line, style: b.type.body.copyWith(color: on)),
                ),
              if (moreCount > 0)
                Text(l10n.uiConflictMore(context.fmt.number(moreCount)), style: b.type.label.copyWith(color: on)),
              if (fixes.isNotEmpty) ...<Widget>[
                const SizedBox(height: BhorSpace.s8),
                Wrap(
                  spacing: BhorSpace.s8,
                  runSpacing: BhorSpace.s8,
                  children: <Widget>[
                    for (final ClashFix f in fixes)
                      BhorButton(
                        label: f.label,
                        variant: f.primary ? BhorButtonVariant.danger : BhorButtonVariant.secondary,
                        onPressed: f.onTap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
