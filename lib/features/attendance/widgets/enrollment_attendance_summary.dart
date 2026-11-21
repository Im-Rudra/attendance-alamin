// Attendance of one enrolment on the student profile: this month's and the
// overall percent plus the latest marks. Shrink-wrapped (it sits inside the
// profile's own scroll view).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/attendance_providers.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_parts.dart';

class EnrollmentAttendanceSummary extends ConsumerWidget {
  const EnrollmentAttendanceSummary({super.key, required this.studentId, required this.batchId});

  final String studentId;
  final String batchId;

  static const int _latest = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final LocalDate today = ref.watch(todayProvider);
    final AttendanceTally? month = ref
        .watch(attendanceTallyProvider(
            (studentId: studentId, batchId: batchId, month: YearMonth(today.year, today.month))))
        .value;
    final AttendanceTally? all =
        ref.watch(attendanceTallyProvider((studentId: studentId, batchId: batchId, month: null))).value;
    final List<AttendanceRecord> records =
        ref.watch(studentBatchRecordsProvider((studentId: studentId, batchId: batchId))).value ??
            const <AttendanceRecord>[];

    if (all == null || month == null) return const SizedBox.shrink();
    if (all.held == 0) {
      return Row(
        children: <Widget>[
          Icon(BhorIcons.rollCall, size: 18, color: b.colors.text2),
          const SizedBox(width: BhorSpace.s8),
          Expanded(
            child: Text(
              l10n.rollSummaryNone,
              style: b.type.meta,
            ),
          ),
        ],
      );
    }

    String pct(AttendanceTally t) {
      final int? p = t.percent;
      return p == null ? '—' : fmt.percent(p);
    }

    final List<AttendanceRecord> latest = records.length <= _latest
        ? records.reversed.toList()
        : records.sublist(records.length - _latest).reversed.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: BhorSpace.s16,
          runSpacing: BhorSpace.s4,
          children: <Widget>[
            Text(l10n.rollSummaryMonth(pct(month)), style: b.type.heading),
            Text(l10n.rollSummaryAll(pct(all)), style: b.type.heading),
          ],
        ),
        if (latest.isNotEmpty) ...<Widget>[
          const SizedBox(height: BhorSpace.s8),
          Text(l10n.rollSummaryLast, style: b.type.label.copyWith(color: b.colors.text2)),
          const SizedBox(height: BhorSpace.s4),
          Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s8,
            children: <Widget>[
              for (final AttendanceRecord r in latest)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(fmt.dateShort(r.date), style: b.type.caption),
                    attendanceTag(context, r.status, short: true),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
