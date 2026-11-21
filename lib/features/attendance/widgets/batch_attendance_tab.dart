// Batch detail > হাজিরা tab: this month's average and class count, the buttons
// that open a roll call (today / another date) and the latest classes with
// their counts; tapping a class reopens its roll call. Shrink-wrapped: it
// scrolls by itself only when its parent gives it a bounded height.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_navigation.dart';

typedef _TabData = ({
  List<SessionSummary> sessions,
  List<AttendanceRecord> records,
  List<Enrollment> enrollments,
});

final _batchSessionsProvider =StreamProvider.autoDispose.family<List<SessionSummary>, String>(
    (Ref ref, String batchId) => ref.watch(attendanceRepositoryProvider).watchSummaries(batchId: batchId));

final _batchRecordsProvider = StreamProvider.autoDispose.family<List<AttendanceRecord>, String>(
    (Ref ref, String batchId) => ref.watch(attendanceRepositoryProvider).watchRecords(batchId: batchId));

final _batchEnrollmentsProvider = StreamProvider.autoDispose.family<List<Enrollment>, String>(
    (Ref ref, String batchId) => ref.watch(enrollmentsRepositoryProvider).watchForBatch(batchId));

/// Average attendance (mean of the students' percents, Product 3.6) and the
/// number of classes held in [month]; sessions and marks outside a student's
/// enrollment never count.
({int? percent, int held}) batchMonthStats({
  required YearMonth month,
  required List<SessionSummary> sessions,
  required List<AttendanceRecord> records,
  required List<Enrollment> enrollments,
}) {
  final LocalDate first = month.firstDay;
  final LocalDate last = month.lastDay;
  var held = 0;
  for (final SessionSummary s in sessions) {
    final LocalDate d = s.session.date;
    if (!d.isBefore(first) && !d.isAfter(last)) held++;
  }
  final Map<String, List<({LocalDate date, AttendanceStatus status})>> byStudent =
      <String, List<({LocalDate date, AttendanceStatus status})>>{};
  for (final AttendanceRecord r in records) {
    (byStudent[r.studentId] ??= <({LocalDate date, AttendanceStatus status})>[])
        .add((date: r.date, status: r.status));
  }
  final Map<String, AttendanceTally> perStudent = <String, AttendanceTally>{};
  for (final Enrollment e in enrollments) {
    final List<({LocalDate date, AttendanceStatus status})> marks =
        byStudent[e.studentId] ?? const <({LocalDate date, AttendanceStatus status})>[];
    LocalDate from = e.joinDate;
    if (first.isAfter(from)) from = first;
    LocalDate to = last;
    final LocalDate? end = e.endDate;
    if (end != null && end.isBefore(to)) to = end;
    final AttendanceTally t = AttendanceStats.tallyWithin(marks, from: from, to: to);
    final AttendanceTally old = perStudent[e.studentId] ?? const AttendanceTally();
    perStudent[e.studentId] = AttendanceTally(
      present: old.present + t.present,
      absent: old.absent + t.absent,
      late: old.late + t.late,
      leave: old.leave + t.leave,
    );
  }
  return (percent: AttendanceStats.meanPercent(perStudent.values), held: held);
}

class BatchAttendanceTab extends ConsumerWidget {
  const BatchAttendanceTab({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final LocalDate today = ref.watch(todayProvider);
    final AsyncValue<_TabData> data =
        combine3<List<SessionSummary>, List<AttendanceRecord>, List<Enrollment>, _TabData>(
      ref.watch(_batchSessionsProvider(batchId)),
      ref.watch(_batchRecordsProvider(batchId)),
      ref.watch(_batchEnrollmentsProvider(batchId)),
      (List<SessionSummary> s, List<AttendanceRecord> r, List<Enrollment> e) =>
          (sessions: s, records: r, enrollments: e),
    );
    final Batch? batch = ref.watch(rollBatchProvider(batchId)).value;

    if (data.hasError) {
      return EmptyState(icon: Icons.error_outline, message: errorText(l10n, data.error!), fill: false);
    }
    final value = data.value;
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final List<SessionSummary> sessions = <SessionSummary>[...value.sessions]..sort(
        (SessionSummary a, SessionSummary b) {
          final int d = b.session.date.compareTo(a.session.date);
          return d != 0 ? d : b.session.startMin.compareTo(a.session.startMin);
        },
      );
    final ({int? percent, int held}) stats = batchMonthStats(
      month: YearMonth(today.year, today.month),
      sessions: sessions,
      records: value.records,
      enrollments: value.enrollments,
    );
    final Widget content = _TabContent(
      batchId: batchId,
      today: today,
      archived: batch?.archived ?? false,
      sessions: sessions,
      stats: stats,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (!c.hasBoundedHeight) return content;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: content,
        );
      },
    );
  }
}

class _TabContent extends StatefulWidget {
  const _TabContent({
    required this.batchId,
    required this.today,
    required this.archived,
    required this.sessions,
    required this.stats,
  });

  final String batchId;
  final LocalDate today;
  final bool archived;
  final List<SessionSummary> sessions;
  final ({int? percent, int held}) stats;

  @override
  State<_TabContent> createState() => _TabContentState();
}

class _TabContentState extends State<_TabContent> {
  static const int _preview = 8;
  bool _all = false;

  Future<void> _pickDate() async {
    final LocalDate today = widget.today;
    final DateTime? picked = await showAppDatePicker(
      context: context,
      initialDate: DateTime(today.year, today.month, today.day),
      firstDate: DateTime(today.year - 2, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    await pushRollCallBatchDate(
        context, widget.batchId, LocalDate(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final int? percent = widget.stats.percent;
    final List<SessionSummary> shown =
        _all ? widget.sessions : widget.sessions.take(_preview).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: StatTile(
                label: l10n.rollTabMonthAvg,
                value: percent == null ? '—' : fmt.percent(percent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: l10n.rollTabMonthHeld,
                value: fmt.number(widget.stats.held),
              ),
            ),
          ],
        ),
        if (!widget.archived) ...<Widget>[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => pushRollCallBatchDate(context, widget.batchId, widget.today),
                icon: const Icon(Icons.how_to_reg_outlined),
                label: Text(l10n.rollTabTake),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(l10n.rollTabOtherDate),
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        SectionHeader(title: l10n.rollTabRecent),
        if (widget.sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.rollTabEmpty,
              style: tt.bodyLarge?.copyWith(color: tokens.textSecondary),
            ),
          )
        else
          GlassCard(
            dense: true,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < shown.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, color: tokens.hairline),
                  _SessionRow(summary: shown[i]),
                ],
              ],
            ),
          ),
        if (widget.sessions.length > _preview)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _all = !_all),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(_all ? l10n.rollTabShowLess : l10n.rollTabShowAll),
            ),
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final AttendanceSession s = summary.session;
    final AttendanceTally t = summary.tally;
    final int? percent = t.percent;
    final String line = l10n.rollTabSessionLine(fmt.number(t.present + t.late), fmt.number(t.held));
    final String dateText = fmt.weekdayDate(s.date);
    final String timeText = fmt.timeRange(s.startMin, s.endMin);
    return Semantics(
      container: true,
      button: true,
      label: '$dateText, $timeText, $line',
      excludeSemantics: true,
      onTap: () => pushRollCallOcc(context, s.occ),
      child: InkWell(
        onTap: () => pushRollCallOcc(context, s.occ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(dateText, style: tt.titleSmall?.copyWith(color: tokens.textPrimary)),
                      Text(timeText, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(line, style: tt.bodyMedium?.copyWith(color: tokens.textPrimary)),
                    if (percent != null)
                      Text(
                        l10n.rollTabPercent(fmt.percent(percent)),
                        style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: tokens.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
