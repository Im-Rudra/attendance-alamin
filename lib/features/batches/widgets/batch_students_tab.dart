// Batch detail › শিক্ষার্থী: rows with dues badge and attendance %; a data
// table (sticky header) when the pane is wide enough (UX 3b, extra-large).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/attendance_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_table.dart';
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
      loading: () => const Center(child: BhorSpinner()),
      error: (Object e, StackTrace s) => BhorEmptyState(
        icon: BhorIcons.warning,
        title: l10n.commonLoadingFailed,
        action: BhorButton(
          label: l10n.commonRetry,
          variant: BhorButtonVariant.secondary,
          onPressed: () => ref.invalidate(batchStudentRowsProvider(batchId)),
        ),
      ),
      data: (List<BatchStudentRow> rows) {
        if (rows.isEmpty) {
          return BhorEmptyState(
            icon: BhorIcons.add,
            title: l10n.batchStudentsEmpty,
            action: archived
                ? null
                : BhorButton(
                    label: l10n.batchAddStudent,
                    onPressed: () => showAddStudentToBatchSheet(context, batchId: batchId),
                  ),
          );
        }
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            if (c.maxWidth >= 640 && c.hasBoundedHeight) {
              return _Table(batchId: batchId, rows: rows);
            }
            return _Cards(batchId: batchId, rows: rows);
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

/// One student per row at every width (a card grid wrapped names per
/// character in narrow columns): circle avatar, name that ellipsizes, roll as
/// meta, dues tag and attendance on the right.
class _Cards extends StatelessWidget {
  const _Cards({required this.batchId, required this.rows});

  final String batchId;
  final List<BatchStudentRow> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, BhorSpace.s8, 0, 160),
      child: BhorStaggerScope(
        child: BhorList(
          children: <Widget>[
            for (int i = 0; i < rows.length; i++)
              BhorStagger(index: i, child: _StudentRow(batchId: batchId, row: rows[i])),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.batchId, required this.row});

  final String batchId;
  final BatchStudentRow row;

  @override
  Widget build(BuildContext context) {
    final Student s = row.student;
    final String roll = _rollText(context, s);
    return BhorListRow(
      title: s.name,
      subtitle: roll.isEmpty ? null : roll,
      leading: BhorAvatar(name: s.name),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _DuesCell(enrollmentId: row.enrollment.id),
          _AttendanceText(studentId: s.id, batchId: batchId),
        ],
      ),
      semanticLabel: s.name,
      onTap: () => openPath(context, Routes.student(s.id)),
    );
  }
}

class _AttendanceText extends ConsumerWidget {
  const _AttendanceText({required this.studentId, required this.batchId});

  final String studentId;
  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BhorThemeData th = context.bhor;
    final int? p = ref
        .watch(attendanceTallyProvider((studentId: studentId, batchId: batchId, month: null)))
        .value
        ?.percent;
    return Text(
      p == null ? context.l10n.batchStatNone : context.fmt.percent(p),
      style: BhorType.tabular(th.type.body.copyWith(color: th.colors.text2)),
    );
  }
}

class _DuesCell extends ConsumerWidget {
  const _DuesCell({required this.enrollmentId});

  final String enrollmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BhorThemeData th = context.bhor;
    final EnrollmentDues? d = ref.watch(enrollmentDuesProvider(enrollmentId)).value;
    final DueLevel? worst = d?.worst;
    if (d == null || d.openDue.isEmpty || worst == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(BhorIcons.checkCircle, size: 16, color: th.colors.text2),
          const SizedBox(width: BhorSpace.s4),
          Flexible(
            child: Text(
              context.l10n.batchAllPaid,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: th.type.label.copyWith(color: th.colors.text2),
            ),
          ),
        ],
      );
    }
    return DueTag(level: worst, monthCount: d.openDue.length);
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.batchId, required this.rows});

  final String batchId;
  final List<BatchStudentRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData th = context.bhor;
    return Padding(
      padding: const EdgeInsets.only(top: BhorSpace.s8),
      child: BatchTable<BatchStudentRow>(
        rows: rows,
        semanticLabel: (BatchStudentRow r) => r.student.name,
        onRowTap: (BatchStudentRow r) => openPath(context, Routes.student(r.student.id)),
        columns: <BatchColumn<BatchStudentRow>>[
          BatchColumn<BatchStudentRow>(
            label: l10n.batchColRoll,
            flex: 1,
            cell: (BatchStudentRow r) => Text(
              context.fmt.digits(AppFormat.toAsciiDigits(r.student.roll ?? '')),
              style: th.type.body.copyWith(color: th.colors.text2),
            ),
          ),
          BatchColumn<BatchStudentRow>(
            label: l10n.batchColName,
            flex: 4,
            cell: (BatchStudentRow r) => Text(
              r.student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: th.type.bodyStrong,
            ),
          ),
          BatchColumn<BatchStudentRow>(
            label: l10n.batchColPhone,
            flex: 3,
            cell: (BatchStudentRow r) {
              final String phone = r.student.guardianPhone ?? r.student.phone ?? '';
              return Text(
                context.fmt.digits(phone),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: th.type.body.copyWith(color: th.colors.text2),
              );
            },
          ),
          BatchColumn<BatchStudentRow>(
            label: l10n.batchColAttendance,
            flex: 2,
            numeric: true,
            cell: (BatchStudentRow r) => _AttendanceText(studentId: r.student.id, batchId: batchId),
          ),
          BatchColumn<BatchStudentRow>(
            label: l10n.batchColDues,
            flex: 4,
            cell: (BatchStudentRow r) => _DuesCell(enrollmentId: r.enrollment.id),
          ),
        ],
      ),
    );
  }
}
