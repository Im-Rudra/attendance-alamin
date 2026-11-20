// Batch detail › শিক্ষার্থী: rows with dues badge and attendance %; a data
// table (sticky header) when the pane is wide enough (UX 3b, extra-large).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/attendance_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';

/// A student enrolled (open enrollment) in the batch.
class BatchStudentRow {
  const BatchStudentRow(this.student, this.enrollment);

  final Student student;
  final Enrollment enrollment;
}

/// Open enrollments joined with their students, roll order.
final batchStudentRowsProvider =
    Provider.family<AsyncValue<List<BatchStudentRow>>, String>((ref, batchId) {
  return combine2(
    ref.watch(batchEnrollmentsProvider(batchId)),
    ref.watch(batchAllStudentsProvider),
    (List<Enrollment> enrollments, List<Student> students) {
      final Map<String, Student> byId = <String, Student>{for (final s in students) s.id: s};
      final List<BatchStudentRow> rows = <BatchStudentRow>[
        for (final Enrollment e in enrollments)
          if (e.endDate == null && byId[e.studentId] != null) BatchStudentRow(byId[e.studentId]!, e),
      ]..sort((BatchStudentRow a, BatchStudentRow b) => compareByRoll(a.student, b.student));
      return rows;
    },
  );
});

class BatchStudentsTab extends ConsumerWidget {
  const BatchStudentsTab({super.key, required this.batchId, this.archived = false});

  final String batchId;

  /// An archived batch takes no new students.
  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<List<BatchStudentRow>> async = ref.watch(batchStudentRowsProvider(batchId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace s) => EmptyState(
        icon: Icons.error_outline,
        message: l10n.commonLoadingFailed,
        actionLabel: l10n.commonRetry,
        onAction: () => ref.invalidate(batchStudentRowsProvider(batchId)),
      ),
      data: (List<BatchStudentRow> rows) {
        if (rows.isEmpty) {
          return EmptyState(
            icon: Icons.person_add_alt_1_outlined,
            message: l10n.batchStudentsEmpty,
            actionLabel: archived ? null : l10n.batchAddStudent,
            onAction: archived
                ? null
                : () => showAddStudentToBatchSheet(context, batchId: batchId),
          );
        }
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            if (c.maxWidth >= 640 && c.hasBoundedHeight) {
              return _Table(batchId: batchId, rows: rows);
            }
            return _Cards(batchId: batchId, rows: rows, columns: c.maxWidth >= 480 ? 2 : 1);
          },
        );
      },
    );
  }
}

String _rollText(BuildContext context, Student s) {
  final String? roll = s.roll;
  if (roll == null || roll.isEmpty) return '';
  return context.l10n.batchRoll(context.fmt.digits(AppFormat.toAsciiDigits(roll)));
}

class _Cards extends StatelessWidget {
  const _Cards({required this.batchId, required this.rows, required this.columns});

  final String batchId;
  final List<BatchStudentRow> rows;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const double gap = 8;
        final double w = (c.maxWidth - gap * (columns - 1)) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 160),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final BatchStudentRow r in rows)
                SizedBox(width: w, child: _StudentCard(batchId: batchId, row: r)),
            ],
          ),
        );
      },
    );
  }
}

class _StudentCard extends ConsumerWidget {
  const _StudentCard({required this.batchId, required this.row});

  final String batchId;
  final BatchStudentRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final Student s = row.student;
    final String roll = _rollText(context, s);
    return GlassCard(
      onTap: () => openPath(context, Routes.student(s.id)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          InitialsAvatar(name: s.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  s.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (roll.isNotEmpty)
                      Text(roll, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
                    _AttendanceText(studentId: s.id, batchId: batchId),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DuesCell(enrollmentId: row.enrollment.id),
        ],
      ),
    );
  }
}

class _AttendanceText extends ConsumerWidget {
  const _AttendanceText({required this.studentId, required this.batchId});

  final String studentId;
  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? p = ref
        .watch(attendanceTallyProvider((studentId: studentId, batchId: batchId, month: null)))
        .value
        ?.percent;
    return Text(
      p == null ? context.l10n.batchStatNone : context.fmt.percent(p),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.aurora.textSecondary),
    );
  }
}

class _DuesCell extends ConsumerWidget {
  const _DuesCell({required this.enrollmentId});

  final String enrollmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EnrollmentDues? d = ref.watch(enrollmentDuesProvider(enrollmentId)).value;
    final DueLevel? worst = d?.worst;
    if (d == null || d.openDue.isEmpty || worst == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 16, color: context.aurora.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.l10n.batchAllPaid,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: context.aurora.textSecondary),
            ),
          ),
        ],
      );
    }
    return SeverityBadge(level: worst, monthCount: d.openDue.length, compact: true);
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.batchId, required this.rows});

  final String batchId;
  final List<BatchStudentRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DenseTable<BatchStudentRow>(
        rows: rows,
        onRowTap: (BatchStudentRow r) => openPath(context, Routes.student(r.student.id)),
        columns: <DenseColumn<BatchStudentRow>>[
          DenseColumn<BatchStudentRow>(
            label: l10n.batchColRoll,
            flex: 1,
            cell: (BatchStudentRow r) => Text(
              context.fmt.digits(AppFormat.toAsciiDigits(r.student.roll ?? '')),
              style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ),
          DenseColumn<BatchStudentRow>(
            label: l10n.batchColName,
            flex: 4,
            cell: (BatchStudentRow r) => Text(
              r.student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
            ),
          ),
          DenseColumn<BatchStudentRow>(
            label: l10n.batchColPhone,
            flex: 3,
            cell: (BatchStudentRow r) {
              final String phone = r.student.guardianPhone ?? r.student.phone ?? '';
              return Text(
                context.fmt.digits(phone),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
              );
            },
          ),
          DenseColumn<BatchStudentRow>(
            label: l10n.batchColAttendance,
            flex: 2,
            numeric: true,
            cell: (BatchStudentRow r) => _AttendanceText(studentId: r.student.id, batchId: batchId),
          ),
          DenseColumn<BatchStudentRow>(
            label: l10n.batchColDues,
            flex: 4,
            cell: (BatchStudentRow r) => _DuesCell(enrollmentId: r.enrollment.id),
          ),
        ],
      ),
    );
  }
}
