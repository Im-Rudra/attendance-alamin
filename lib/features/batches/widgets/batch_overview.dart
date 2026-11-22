// Desktop panes of the Batches tab: the "nothing selected" overview (never a
// blank area, compact) and the context of the selected batch (dues by level,
// 8-week attendance trend). The weekly routine is shown once, in the
// Schedule tab; it is not repeated here (review B1).

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
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';

/// What the detail pane shows while no batch is selected: four stat tiles, one
/// compact per-batch list (students + dues) and a quiet prompt. Compact and
/// top aligned, never a big void (review B11).
class BatchesOverview extends ConsumerWidget {
  const BatchesOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
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
          final int cols = c.maxWidth - 2 * g >= 520 ? 4 : 2;
          final double w = (c.maxWidth - 2 * g - BhorSpace.s12 * (cols - 1)) / cols;
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
              if (all.isNotEmpty) ...<Widget>[
                const SizedBox(height: BhorSpace.s16),
                BhorSectionHeader(title: l10n.batchOverviewDuesByBatch),
                BhorCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < all.length; i++)
                        BhorListRow(
                          title: batchLabel(l10n, all[i].subjectName, all[i].batch.name),
                          subtitle: l10n.studentCountText(all[i].studentCount, fmt.number(all[i].studentCount)),
                          divider: i != all.length - 1,
                          onTap: () => openPath(context, Routes.batch(all[i].batch.id)),
                          trailing: _DuesOrClear(batchId: all[i].batch.id),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: BhorSpace.s16),
              BhorCard(
                child: BhorEmptyState(
                  size: BhorEmptySize.compact,
                  icon: BhorIcons.sparkle,
                  title: l10n.batchOverviewPick,
                ),
              ),
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

/// This batch's dues by level (worst level per open enrollment) and the
/// weekly attendance of the last 8 weeks.
typedef BatchInsights = ({
  Map<DueLevel, int> byLevel,
  List<DueLevel> levels,
  List<AttendanceTally> weeks,
  bool anyAttendance,
});

BatchInsights batchInsightsOf(WidgetRef ref, String batchId) {
  final LocalDate today = ref.watch(todayProvider);
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
  return (byLevel: byLevel, levels: levels, weeks: weeks, anyAttendance: any);
}

Widget _duesBody(BuildContext context, BatchInsights d) {
  final l10n = context.l10n;
  final fmt = context.fmt;
  final BhorThemeData th = context.bhor;
  if (d.levels.isEmpty) {
    return Row(
      children: <Widget>[
        Icon(BhorIcons.checkCircle, color: th.colors.text2),
        const SizedBox(width: BhorSpace.s8),
        Expanded(
          child: Text(l10n.batchContextNoDues, style: th.type.body.copyWith(color: th.colors.text2)),
        ),
      ],
    );
  }
  return Column(
    children: <Widget>[
      for (final DueLevel lv in d.levels)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Align(alignment: AlignmentDirectional.centerStart, child: DueTag(level: lv)),
              ),
              Text(l10n.batchContextStudentsOne(fmt.number(d.byLevel[lv] ?? 0)), style: th.type.body),
            ],
          ),
        ),
    ],
  );
}

Widget _trendBody(BuildContext context, BatchInsights d, {double height = 96}) {
  final BhorThemeData th = context.bhor;
  if (!d.anyAttendance) {
    return Text(context.l10n.batchContextNoAttendance, style: th.type.body.copyWith(color: th.colors.text2));
  }
  return _Trend(weeks: d.weeks, height: height);
}

/// Fourth column (>= 1600): this batch's dues by level and attendance trend.
class BatchContextPane extends ConsumerWidget {
  const BatchContextPane({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final BatchInsights d = batchInsightsOf(ref, batchId);
    return ListView(
      padding: EdgeInsets.fromLTRB(g, BhorSpace.s12, g, g),
      children: <Widget>[
        BhorSectionHeader(title: l10n.batchContextDues),
        BhorCard(child: _duesBody(context, d)),
        const SizedBox(height: BhorSpace.s12),
        BhorSectionHeader(title: l10n.batchContextTrend),
        BhorCard(child: _trendBody(context, d)),
      ],
    );
  }
}

/// The same content folded into the detail's overview when the rail has no
/// column of its own (BhorMasterDetailPage.foldedRailOf): two compact columns
/// (stacked when narrow), no card of their own.
class BatchInsightsPanel extends ConsumerWidget {
  const BatchInsightsPanel({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final BhorThemeData th = context.bhor;
    final BatchInsights d = batchInsightsOf(ref, batchId);
    Widget titled(String title, Widget body) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: th.type.label.copyWith(color: th.colors.text2)),
            const SizedBox(height: BhorSpace.s8),
            body,
          ],
        );
    final Widget dues = titled(l10n.batchContextDues, _duesBody(context, d));
    final Widget trend = titled(l10n.batchContextTrend, _trendBody(context, d, height: 72));
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[dues, const SizedBox(height: BhorSpace.s12), trend],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: dues),
            const SizedBox(width: BhorSpace.s24),
            Expanded(child: trend),
          ],
        );
      },
    );
  }
}

/// Eight weekly bars, oldest to newest; a missing week is a thin track.
class _Trend extends StatelessWidget {
  const _Trend({required this.weeks, this.height = 96});

  final List<AttendanceTally> weeks;
  final double height;

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
        height: height,
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
                        height: t.percent == null ? 4 : (4 + (height - 36) * t.percent! / 100).toDouble(),
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
