// "সময়ের সংঘাত" banner (scenario 21): classes in the next four weeks that
// overlap (legacy data, an unarchive that was accepted with clashes, an
// import). It lists the first pairs and opens the slot editor of one batch.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
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
    final BhorThemeData b = context.bhor;
    final Color on = b.colors.danger;

    String label(String batchId) {
      for (final BatchSchedule s in schedules) {
        if (s.batch.id == batchId) return batchLabel(l10n, s.subjectName, s.batch.name);
      }
      return '';
    }

    final List<_Overlap> shown = overlaps.take(2).toList();
    final int more = overlaps.length - shown.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: BhorSpace.s12),
      child: Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: b.colors.dangerBg,
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(color: b.colors.danger.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(BhorIcons.warningFill, color: on, size: 24),
                  const SizedBox(width: BhorSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.todayConflictTitle,
                          style: b.type.heading.copyWith(color: on),
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
                            style: b.type.body.copyWith(color: on),
                          ),
                        if (more > 0)
                          Text(
                            l10n.uiConflictMore(fmt.number(more)),
                            style: b.type.label.copyWith(color: on),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BhorSpace.s8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: BhorButton(
                  label: l10n.todayConflictFix,
                  variant: BhorButtonVariant.danger,
                  onPressed: () => pushRoute(context, Routes.batchSlots(shown.first.a.batchId)),
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
