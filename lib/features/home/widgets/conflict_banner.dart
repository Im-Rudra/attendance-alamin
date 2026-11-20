// "সময়ের সংঘাত" banner (scenario 21): classes in the next four weeks that
// overlap (legacy data, an unarchive that was accepted with clashes, an
// import). It lists the first pairs and opens the slot editor of one batch.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/home/widgets/today_actions.dart';

/// One recurring (or one-off) overlap, with how often it shows up.
class _Overlap {
  const _Overlap(this.a, this.b);

  final Occurrence a;
  final Occurrence b;
}

/// Collapses the weekly repeats of the same overlap into one entry.
List<_Overlap> _overlaps(List<Clash> clashes) {
  final Set<String> seen = <String>{};
  final List<_Overlap> out = <_Overlap>[];
  for (final Clash c in clashes) {
    final String lo = c.candidate.batchId.compareTo(c.existing.batchId) <= 0
        ? c.candidate.batchId
        : c.existing.batchId;
    final String hi = lo == c.candidate.batchId ? c.existing.batchId : c.candidate.batchId;
    final String key =
        '$lo|$hi|${c.candidate.date.isoWeekday}|${c.candidate.startMin}|${c.existing.startMin}';
    if (seen.add(key)) out.add(_Overlap(c.candidate, c.existing));
  }
  return out;
}

class ConflictBanner extends ConsumerWidget {
  const ConflictBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Clash>? clashes = ref.watch(legacyConflictsProvider).value;
    if (clashes == null || clashes.isEmpty) return const SizedBox.shrink();
    final List<BatchSchedule> schedules =
        ref.watch(schedulesProvider).value ?? const <BatchSchedule>[];
    final List<_Overlap> overlaps = _overlaps(clashes);
    if (overlaps.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final Color on = tokens.onErrorContainer;

    String label(String batchId) {
      for (final BatchSchedule s in schedules) {
        if (s.batch.id == batchId) return l10n.clsClassLabel(s.subjectName, s.batch.name);
      }
      return '';
    }

    final List<_Overlap> shown = overlaps.take(2).toList();
    final int more = overlaps.length - shown.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.errorContainer,
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
          border: Border.all(color: tokens.errorContainerBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, color: on, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.todayConflictTitle,
                          style: tt.titleSmall?.copyWith(color: on, fontWeight: FontWeight.w700),
                        ),
                        for (final _Overlap o in shown)
                          Text(
                            l10n.todayConflictLine(
                              label(o.a.batchId),
                              label(o.b.batchId),
                              '${fmt.weekdayName(o.a.date.isoWeekday)} ${fmt.timeRange(o.a.startMin, o.a.endMin)}',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(color: on),
                          ),
                        if (more > 0)
                          Text(
                            l10n.uiConflictMore(fmt.number(more)),
                            style: tt.labelMedium?.copyWith(color: on),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: tokens.error,
                    foregroundColor: tokens.onError,
                  ),
                  onPressed: () => pushRoute(context, Routes.batchSlots(shown.first.a.batchId)),
                  child: Text(l10n.todayConflictFix),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
