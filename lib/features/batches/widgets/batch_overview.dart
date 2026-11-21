// Desktop panes of the Batches tab: the "nothing selected" overview (never a
// blank area) and the context pane of the selected batch (UX 3b: week slots,
// dues by level, 8-week attendance trend).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_table.dart';

/// What the detail pane shows while no batch is selected.
class BatchesOverview extends ConsumerWidget {
  const BatchesOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData th = context.bhor;
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

    Widget tile(String label, String value) => BhorCard(child: BhorStatText(label: label, value: value));

    return BhorScaffold(
      header: BhorHeader(title: l10n.shellTitleOverview, showBack: false),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final int cols = c.maxWidth >= 560 ? 4 : 2;
          final double w = (c.maxWidth - 2 * g - BhorSpace.s12 * (cols - 1)) / cols;
          final Widget pickHint = BhorCard(
            child: Row(
              children: <Widget>[
                Icon(BhorIcons.sparkle, color: th.colors.accent),
                const SizedBox(width: BhorSpace.s12),
                Expanded(child: Text(l10n.batchOverviewPick, style: th.type.body)),
              ],
            ),
          );
          final Widget duesByBatch = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BhorSectionHeader(title: l10n.batchOverviewDuesByBatch),
              BhorCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < all.length; i++)
                      BhorListRow(
                        title: batchLabel(l10n, all[i].subjectName, all[i].batch.name),
                        divider: i != all.length - 1,
                        onTap: () => openPath(context, Routes.batch(all[i].batch.id)),
                        trailing: _DuesOrClear(batchId: all[i].batch.id),
                      ),
                  ],
                ),
              ),
            ],
          );
          final List<BatchCardData> bySize = <BatchCardData>[...all]
            ..sort((BatchCardData a, BatchCardData b) => b.studentCount.compareTo(a.studentCount));
          final Widget studentsByBatch = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BhorSectionHeader(title: l10n.batchOverviewByStudents),
              BatchBarList(
                entries: <BatchBarEntry>[
                  for (final BatchCardData b in bySize.take(8))
                    BatchBarEntry(
                      label: batchLabel(l10n, b.subjectName, b.batch.name),
                      value: b.studentCount,
                      valueText: fmt.number(b.studentCount),
                      onTap: () => openPath(context, Routes.batch(b.batch.id)),
                    ),
                ],
              ),
            ],
          );
          return ListView(
            padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, g),
            children: <Widget>[
              Wrap(
                spacing: BhorSpace.s12,
                runSpacing: BhorSpace.s12,
                children: <Widget>[
                  SizedBox(width: w, child: tile(l10n.batchOverviewBatches, fmt.number(all.length))),
                  SizedBox(width: w, child: tile(l10n.batchOverviewStudents, fmt.number(students))),
                  SizedBox(width: w, child: tile(l10n.batchOverviewClasses, fmt.number(classes))),
                  SizedBox(
                    width: w,
                    child: BhorCard(child: BhorStatText.money(label: l10n.batchOverviewDues, amount: due)),
                  ),
                ],
              ),
              const SizedBox(height: BhorSpace.s16),
              if (all.isNotEmpty && c.maxWidth >= 640)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: duesByBatch),
                    const SizedBox(width: BhorSpace.s12),
                    Expanded(child: studentsByBatch),
                  ],
                )
              else if (all.isNotEmpty) ...<Widget>[
                duesByBatch,
                const SizedBox(height: BhorSpace.s8),
                studentsByBatch,
              ],
              const SizedBox(height: BhorSpace.s12),
              pickHint,
            ],
          );
        },
      ),
    );
  }
}

class _DuesOrClear extends ConsumerWidget {
  const _DuesOrClear({required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BhorThemeData th = context.bhor;
    final BatchDuesSummary? d = ref.watch(batchDuesProvider(batchId)).value;
    if (d == null || d.count == 0) {
      return Text(context.l10n.batchAllPaid, style: th.type.label.copyWith(color: th.colors.text2));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BhorMoney(d.total, style: th.type.label),
        const SizedBox(width: BhorSpace.s8),
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
    final BhorThemeData th = context.bhor;
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
      padding: EdgeInsets.fromLTRB(g, BhorSpace.s12, g, g),
      children: <Widget>[
        BhorSectionHeader(title: l10n.batchContextWeek),
        BhorCard(
          child: slots.isEmpty
              ? Text(l10n.batchNoSlots, style: th.type.body.copyWith(color: th.colors.text2))
              : Column(
                  children: <Widget>[
                    for (final Slot s in slots)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: Text(fmt.weekdayName(s.weekday), style: th.type.body)),
                            Text(
                              fmt.timeRange(s.startMin, s.endMin),
                              style: th.type.body.copyWith(color: th.colors.text2),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: BhorSpace.s12),
        BhorSectionHeader(title: l10n.batchContextDues),
        BhorCard(
          child: levels.isEmpty
              ? Row(
                  children: <Widget>[
                    Icon(BhorIcons.checkCircle, color: th.colors.text2),
                    const SizedBox(width: BhorSpace.s8),
                    Expanded(
                      child: Text(
                        l10n.batchContextNoDues,
                        style: th.type.body.copyWith(color: th.colors.text2),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: <Widget>[
                    for (final DueLevel lv in levels)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: DueTag(level: lv),
                              ),
                            ),
                            Text(l10n.batchContextStudentsOne(fmt.number(byLevel[lv] ?? 0)), style: th.type.body),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: BhorSpace.s12),
        BhorSectionHeader(title: l10n.batchContextTrend),
        BhorCard(
          child: any
              ? _Trend(weeks: weeks)
              : Text(
                  l10n.batchContextNoAttendance,
                  style: th.type.body.copyWith(color: th.colors.text2),
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
    final BhorThemeData th = context.bhor;
    final fmt = context.fmt;
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
                          style: th.type.caption,
                        ),
                      const SizedBox(height: 2),
                      Container(
                        height: t.percent == null ? 4 : (4 + 60 * t.percent! / 100).toDouble(),
                        decoration: BoxDecoration(
                          color: t.percent == null ? th.colors.line : th.colors.accent,
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
