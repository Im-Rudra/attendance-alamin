// Desktop panes of the Batches tab: the "nothing selected" overview (never a
// blank area) and the context pane of the selected batch (UX 3b: week slots,
// dues by level, 8-week attendance trend).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';

/// What the detail pane shows while no batch is selected.
class BatchesOverview extends ConsumerWidget {
  const BatchesOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final double g = WindowClass.of(context).gutter;
    final LocalDate today = ref.watch(todayProvider);
    final List<SubjectGroup> groups = ref.watch(batchGroupsProvider).value ?? const <SubjectGroup>[];
    final List<BatchCardData> all = <BatchCardData>[for (final SubjectGroup s in groups) ...s.batches];
    final int students = all.fold(0, (int a, BatchCardData b) => a + b.studentCount);
    int due = 0;
    for (final BatchCardData b in all) {
      due += ref.watch(batchDuesProvider(b.batch.id)).value?.total ?? 0;
    }
    final int classes = ref.watch(dayPlanProvider(today)).value?.classes.length ?? 0;

    Widget tile(String label, String value) => StatTile(label: label, value: value);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Semantics(header: true, child: Text(l10n.shellTitleOverview)),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final int cols = c.maxWidth >= 560 ? 4 : 2;
            final double w = (c.maxWidth - 2 * g - 12 * (cols - 1)) / cols;
            return ListView(
              padding: EdgeInsets.fromLTRB(g, 4, g, g),
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(width: w, child: tile(l10n.batchOverviewBatches, fmt.number(all.length))),
                    SizedBox(width: w, child: tile(l10n.batchOverviewStudents, fmt.number(students))),
                    SizedBox(width: w, child: tile(l10n.batchOverviewClasses, fmt.number(classes))),
                    SizedBox(width: w, child: tile(l10n.batchOverviewDues, fmt.money(due))),
                  ],
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.touch_app_outlined, color: tokens.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.batchOverviewPick,
                          style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                if (all.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  SectionHeader(title: l10n.batchOverviewDuesByBatch),
                  for (final BatchCardData b in all)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        dense: true,
                        onTap: () => openPath(context, Routes.batch(b.batch.id)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                b.batch.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _DuesOrClear(batchId: b.batch.id),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DuesOrClear extends ConsumerWidget {
  const _DuesOrClear({required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BatchDuesSummary? d = ref.watch(batchDuesProvider(batchId)).value;
    if (d == null || d.count == 0) {
      return Text(
        context.l10n.batchAllPaid,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.aurora.textSecondary),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          context.fmt.money(d.total),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.aurora.textPrimary),
        ),
        const SizedBox(width: 8),
        BatchDuesBadge(batchId: batchId),
      ],
    );
  }
}

/// Third pane (≥ 1200): this batch's week, dues by level, attendance trend.
class BatchContextPane extends ConsumerWidget {
  const BatchContextPane({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final double g = WindowClass.of(context).gutter;
    final LocalDate today = ref.watch(todayProvider);

    final List<BatchSchedule> schedules = ref.watch(schedulesProvider).value ?? const <BatchSchedule>[];
    List<Slot> slots = const <Slot>[];
    for (final BatchSchedule s in schedules) {
      if (s.batch.id == batchId) slots = activeSlots(s.slots, today);
    }
    slots = <Slot>[...slots]..sort((Slot a, Slot b) {
        final int c = kWeekOrder.indexOf(a.weekday).compareTo(kWeekOrder.indexOf(b.weekday));
        return c != 0 ? c : a.startMin.compareTo(b.startMin);
      });

    // Dues by level for this batch.
    final Map<DueLevel, int> byLevel = <DueLevel, int>{};
    final DuesReport? report = ref.watch(duesReportProvider).value;
    if (report != null) {
      for (final StudentDues s in report.active) {
        for (final EnrollmentDues e in s.enrollments) {
          final DueLevel? w = e.worst;
          if (e.terms.batchId != batchId || e.openDue.isEmpty || w == null) continue;
          byLevel[w] = (byLevel[w] ?? 0) + 1;
        }
      }
    }
    final List<DueLevel> levels = DueLevel.values.reversed.where(byLevel.containsKey).toList();

    final DateSpan span = (from: today.addDays(-55), to: today);
    final List<SessionSummary> sessions = ref.watch(sessionSummariesProvider(span)).value ?? const <SessionSummary>[];
    final List<AttendanceTally> weeks = List<AttendanceTally>.filled(8, const AttendanceTally());
    var any = false;
    for (final SessionSummary s in sessions) {
      if (s.session.batchId != batchId) continue;
      final int back = s.session.date.daysUntil(today) ~/ 7;
      if (back < 0 || back > 7) continue;
      final AttendanceTally t = weeks[7 - back];
      weeks[7 - back] = AttendanceTally(
        present: t.present + s.tally.present,
        absent: t.absent + s.tally.absent,
        late: t.late + s.tally.late,
        leave: t.leave + s.tally.leave,
      );
      any = true;
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(g, 12, g, g),
      children: <Widget>[
        SectionHeader(title: l10n.batchContextWeek),
        GlassCard(
          dense: true,
          child: slots.isEmpty
              ? Text(l10n.batchNoSlots, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary))
              : Column(
                  children: <Widget>[
                    for (final Slot s in slots)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                fmt.weekdayName(s.weekday),
                                style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
                              ),
                            ),
                            Text(
                              fmt.timeRange(s.startMin, s.endMin),
                              style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        SectionHeader(title: l10n.batchContextDues),
        GlassCard(
          dense: true,
          child: levels.isEmpty
              ? Row(
                  children: <Widget>[
                    Icon(Icons.check_circle_outline, color: tokens.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.batchContextNoDues,
                        style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: <Widget>[
                    for (final DueLevel lv in levels)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: SeverityBadge(level: lv, compact: true),
                              ),
                            ),
                            Text(
                              l10n.batchContextStudentsOne(fmt.number(byLevel[lv] ?? 0)),
                              style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        SectionHeader(title: l10n.batchContextTrend),
        GlassCard(
          dense: true,
          child: any
              ? _Trend(weeks: weeks)
              : Text(
                  l10n.batchContextNoAttendance,
                  style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
        ),
      ],
    );
  }
}

/// Eight weekly bars, oldest to newest; a missing week is a thin track.
class _Trend extends StatelessWidget {
  const _Trend({required this.weeks});

  final List<AttendanceTally> weeks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final String summary = <String>[
      for (final AttendanceTally t in weeks) t.percent == null ? '-' : fmt.percent(t.percent!),
    ].join(', ');
    return Semantics(
      container: true,
      label: '${context.l10n.batchContextTrend}: $summary',
      excludeSemantics: true,
      child: SizedBox(
        height: 96,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (final AttendanceTally t in weeks)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (t.percent != null)
                        Text(
                          fmt.number(t.percent!),
                          maxLines: 1,
                          style: tt.labelSmall?.copyWith(color: tokens.textSecondary),
                        ),
                      const SizedBox(height: 2),
                      Container(
                        height: t.percent == null ? 4 : (4 + 60 * t.percent! / 100).toDouble(),
                        decoration: BoxDecoration(
                          color: t.percent == null ? tokens.track : tokens.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
