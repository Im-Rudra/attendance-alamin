// Live clash card of the slot editor (UX 2g "Conflict UI"): names up to three
// clashing classes, then offers the nearest free time as one-tap fixes (later
// = primary, earlier = secondary). Never says "conflict" or "overlap".

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

class SlotClashCard extends ConsumerWidget {
  const SlotClashCard({
    super.key,
    required this.result,
    this.ownBatchId,
    this.onFix,
  });

  final SlotCheckResult result;

  /// The batch being edited; its own other classes read "another class of
  /// this batch" instead of repeating the batch name.
  final String? ownBatchId;

  /// Called with the chosen new start (minutes) when a suggestion is tapped.
  /// Null shows the clashes without fixes.
  final ValueChanged<int>? onFix;

  static const int _maxLines = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final List<BatchSchedule> schedules =
        ref.watch(schedulesProvider).value ?? const <BatchSchedule>[];
    final Map<String, BatchSchedule> byId = <String, BatchSchedule>{
      for (final BatchSchedule s in schedules) s.batch.id: s,
    };

    final List<String> lines = <String>[];
    for (final ClashGroup g in result.groups.take(_maxLines)) {
      final String when = g.everyWeek
          ? l10n.schedEveryWeekday(fmt.weekdayName(g.weekday))
          : fmt.dateShort(g.date!);
      final String range = fmt.timeRange(g.startMin, g.endMin);
      final BatchSchedule? bs = byId[g.batchId];
      if (bs == null || g.batchId == ownBatchId) {
        lines.add(l10n.schedClashSameBatch(when, range));
      } else {
        lines.add(l10n.schedClashLine(bs.subjectName, bs.batch.name, when, range));
      }
    }

    final FreeSuggestion? s = result.suggestion;
    final List<_Fix> fixes = <_Fix>[];
    final ValueChanged<int>? apply = onFix;
    if (s != null && apply != null) {
      final int? later = s.laterStartMin;
      final int? earlier = s.earlierStartMin;
      String range(int start) => fmt.timeRange(start, start + s.durationMin);
      if (later != null) {
        fixes.add(_Fix(
          label: l10n.schedFixTake(range(later)),
          primary: true,
          onTap: () => apply(later),
        ));
      }
      if (earlier != null) {
        fixes.add(_Fix(
          label: later == null
              ? l10n.schedFixTake(range(earlier))
              : l10n.schedFixEarlier(range(earlier)),
          primary: later == null,
          onTap: () => apply(earlier),
        ));
      }
    }
    if (s != null && s.laterStartMin == null && s.earlierStartMin == null) {
      lines.add(l10n.schedNoFreeSlot);
    }

    return _ClashPanel(
      lines: lines,
      moreCount: result.groups.length > _maxLines ? result.groups.length - _maxLines : 0,
      fixes: fixes,
    );
  }
}

class _Fix {
  const _Fix({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;
}

/// Danger-tinted hairline card (live region): title, the clashing lines and
/// one or two fix buttons.
class _ClashPanel extends StatelessWidget {
  const _ClashPanel({required this.lines, required this.moreCount, required this.fixes});

  final List<String> lines;
  final int moreCount;
  final List<_Fix> fixes;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.dangerBg,
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(color: c.danger),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(BhorIcons.warning, color: c.danger, size: 24),
                  const SizedBox(width: BhorSpace.s8),
                  Expanded(child: Text(l10n.uiConflictTitle, style: b.type.heading.copyWith(color: c.danger))),
                ],
              ),
              const SizedBox(height: BhorSpace.s8),
              for (final String line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: BhorSpace.s4),
                  child: Text(line, style: b.type.body.copyWith(color: c.danger)),
                ),
              if (moreCount > 0)
                Text(
                  l10n.uiConflictMore(context.fmt.number(moreCount)),
                  style: b.type.label.copyWith(color: c.danger),
                ),
              if (fixes.isNotEmpty) ...<Widget>[
                const SizedBox(height: BhorSpace.s8),
                Wrap(
                  spacing: BhorSpace.s8,
                  runSpacing: BhorSpace.s8,
                  children: <Widget>[
                    for (final _Fix f in fixes)
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
