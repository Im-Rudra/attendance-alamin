// "ছেড়ে গেছে" dialog (Product 3.2, scenario 8): the left date (default today)
// and, per open enrollment, the last billable month (default: the left month
// from day 11, otherwise the month before). Also used for removing a student
// from one batch only.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/attendance_providers.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

/// Shows the dialog; true when the student (or the one enrollment) was ended.
/// [enrollmentId] set = remove from that batch only.
Future<bool> openLeaveDialog(
  BuildContext context, {
  required String studentId,
  String? enrollmentId,
}) async {
  final bool? done = await showBhorDialog<bool>(
    context,
    builder: (BuildContext ctx) =>
        LeaveDialog(studentId: studentId, enrollmentId: enrollmentId),
  );
  return done ?? false;
}

class LeaveDialog extends ConsumerStatefulWidget {
  const LeaveDialog({super.key, required this.studentId, this.enrollmentId});

  final String studentId;
  final String? enrollmentId;

  @override
  ConsumerState<LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends ConsumerState<LeaveDialog> {
  LocalDate? _date;
  final Map<String, YearMonth> _edited = <String, YearMonth>{};
  bool _busy = false;
  String? _error;

  Future<void> _confirm(
      LocalDate date, List<Enrollment> open, Map<String, YearMonth> lbm) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String? one = widget.enrollmentId;
      if (one == null) {
        await ref.read(studentsRepositoryProvider).markLeft(widget.studentId,
            on: date, lastBillableByEnrollment: lbm);
      } else {
        final YearMonth? m = lbm[one];
        if (m != null) {
          await ref
              .read(enrollmentsRepositoryProvider)
              .end(one, on: date, lastBillableMonth: m);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final fmt = context.fmt;
    final LocalDate today = ref.watch(todayProvider);
    final LocalDate date = _date ?? today;
    final Student? student = ref.watch(stuStudentProvider(widget.studentId)).value;
    final List<Enrollment> all =
        ref.watch(studentEnrollmentsProvider(widget.studentId)).value ??
            const <Enrollment>[];
    final List<Batch> batches = ref.watch(stuBatchesProvider).value ?? const <Batch>[];
    final String? one = widget.enrollmentId;
    final List<Enrollment> open = <Enrollment>[
      for (final Enrollment e in all)
        if (e.endDate == null && (one == null || e.id == one)) e,
    ];
    final YearMonth defaultLbm = DuesEngine.defaultLastBillableMonth(date);
    final Map<String, YearMonth> lbm = <String, YearMonth>{
      for (final Enrollment e in open) e.id: _edited[e.id] ?? defaultLbm,
    };
    String batchName(String id) {
      for (final Batch b in batches) {
        if (b.id == id) return b.name;
      }
      return '';
    }

    final String title = one == null ? l10n.stuLeftTitle : l10n.stuRemoveFromBatchTitle;
    final String body = one == null
        ? l10n.stuLeftBody(student?.name ?? '')
        : l10n.stuRemoveFromBatchBody(student?.name ?? '', batchName(one));

    return BhorDialog(
      title: title,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(body, style: b.type.body.copyWith(color: b.colors.text2)),
            const SizedBox(height: BhorSpace.s16),
            DateField(
              label: l10n.stuLeftDate,
              value: date,
              lastDate: today.addDays(31),
              onChanged: (LocalDate d) => setState(() => _date = d),
            ),
            const SizedBox(height: BhorSpace.s16),
            for (final Enrollment e in open) ...<Widget>[
              Text(batchName(e.batchId), style: b.type.heading),
              const SizedBox(height: BhorSpace.s8),
              MonthDropdown(
                label: l10n.stuLastBillable,
                value: lbm[e.id]!,
                months: monthChoices(
                  e.startMonth.addMonths(-1),
                  date.yearMonth.addMonths(1),
                  lbm[e.id]!,
                ),
                onChanged: (YearMonth m) => setState(() => _edited[e.id] = m),
              ),
              const SizedBox(height: BhorSpace.s4),
              Text(
                l10n.stuLastBillableHint(fmt.monthYear(lbm[e.id]!)),
                style: b.type.label.copyWith(color: b.colors.text2),
              ),
              const SizedBox(height: BhorSpace.s16),
            ],
            if (open.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: BhorSpace.s16),
                child: Text(
                  l10n.stuLeftNoOpenBatches,
                  style: b.type.body.copyWith(color: b.colors.text2),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: BhorSpace.s8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: b.type.body.copyWith(color: b.colors.danger)),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        BhorButton(
          label: l10n.commonCancel,
          variant: BhorButtonVariant.ghost,
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        BhorButton(
          key: const ValueKey<String>('stu-leave-confirm'),
          label: one == null ? l10n.stuLeftConfirm : l10n.stuRemoveConfirm,
          onPressed: (_busy || (one != null && open.isEmpty)) ? null : () => _confirm(date, open, lbm),
        ),
      ],
    );
  }
}
