// Batch detail > হাজিরা tab: this month's average and class count, the buttons
// that open a roll call (today / another date) and the latest classes with
// their counts; tapping a class reopens its roll call. Shrink-wrapped: it
// scrolls by itself only when its parent gives it a bounded height.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
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
      return BhorEmptyState(icon: BhorIcons.warning, title: errorText(l10n, data.error!));
    }
    final value = data.value;
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.all(BhorSpace.s24),
        child: Center(child: BhorSpinner(size: 28)),
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
    final int weekStart = ref.watch(weekStartProvider).value ?? DateTime.saturday;
    final Widget content = _TabContent(
      batchId: batchId,
      today: today,
      weekStart: weekStart,
      archived: batch?.archived ?? false,
      sessions: sessions,
      stats: stats,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (!c.hasBoundedHeight) return content;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s8, BhorSpace.s16, BhorSpace.s24),
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
    required this.weekStart,
    required this.archived,
    required this.sessions,
    required this.stats,
  });

  final String batchId;
  final LocalDate today;
  final int weekStart;
  final bool archived;
  final List<SessionSummary> sessions;
  final ({int? percent, int held}) stats;

  @override
  State<_TabContent> createState() => _TabContentState();
}

class _TabContentState extends State<_TabContent> {
  static const int _preview = 8;
  bool _all = false;

  Future<void> _pickDate(BuildContext anchor) async {
    final LocalDate today = widget.today;
    final DateTime? picked = await showBhorDatePicker(
      context,
      anchor: anchor,
      initialDate: DateTime(today.year, today.month, today.day),
      firstDate: DateTime(today.year - 2, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day),
      weekStart: widget.weekStart,
      today: DateTime(today.year, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    await pushRollCallBatchDate(
        context, widget.batchId, LocalDate(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
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
              child: BhorCard(
                child: BhorStatText(
                  label: l10n.rollTabMonthAvg,
                  value: percent == null ? '—' : fmt.percent(percent),
                ),
              ),
            ),
            const SizedBox(width: BhorSpace.s8),
            Expanded(
              child: BhorCard(
                child: BhorStatText.count(
                  label: l10n.rollTabMonthHeld,
                  count: widget.stats.held,
                ),
              ),
            ),
          ],
        ),
        if (!widget.archived) ...<Widget>[
          const SizedBox(height: BhorSpace.s12),
          Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s8,
            children: <Widget>[
              BhorButton(
                label: l10n.rollTabTake,
                icon: BhorIcons.rollCall,
                onPressed: () => pushRollCallBatchDate(context, widget.batchId, widget.today),
              ),
              Builder(
                builder: (BuildContext bc) => BhorButton(
                  label: l10n.rollTabOtherDate,
                  icon: BhorIcons.calendar,
                  variant: BhorButtonVariant.secondary,
                  onPressed: () => _pickDate(bc),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: BhorSpace.s8),
        BhorSectionHeader(title: l10n.rollTabRecent),
        if (widget.sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BhorSpace.s16),
            child: Text(l10n.rollTabEmpty, style: b.type.body.copyWith(color: b.colors.text2)),
          )
        else
          BhorList(
            children: <Widget>[
              for (var i = 0; i < shown.length; i++)
                _SessionRow(summary: shown[i], divider: i < shown.length - 1),
            ],
          ),
        if (widget.sessions.length > _preview)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BhorButton(
              label: _all ? l10n.rollTabShowLess : l10n.rollTabShowAll,
              variant: BhorButtonVariant.ghost,
              onPressed: () => setState(() => _all = !_all),
            ),
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.summary, required this.divider});

  final SessionSummary summary;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final AttendanceSession s = summary.session;
    final AttendanceTally t = summary.tally;
    final int? percent = t.percent;
    final String line = l10n.rollTabSessionLine(fmt.number(t.present + t.late), fmt.number(t.held));
    final String dateText = fmt.weekdayDate(s.date);
    final String timeText = fmt.timeRange(s.startMin, s.endMin);
    return BhorListRow(
      title: dateText,
      subtitle: timeText,
      divider: divider,
      semanticLabel: '$dateText, $timeText, $line',
      onTap: () => pushRollCallOcc(context, s.occ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(line, style: b.type.body),
              if (percent != null) Text(l10n.rollTabPercent(fmt.percent(percent)), style: b.type.meta),
            ],
          ),
          const SizedBox(width: BhorSpace.s4),
          Icon(BhorIcons.chevronRight, color: b.colors.text2),
        ],
      ),
    );
  }
}
