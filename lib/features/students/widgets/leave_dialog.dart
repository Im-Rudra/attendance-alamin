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
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/batches/widgets/panel_footer.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

/// Shows the form; true when the student (or the one enrollment) was ended.
/// [enrollmentId] set = remove from that batch only. A side panel on desktop,
/// a sheet on phones.
Future<bool> openLeaveDialog(
  BuildContext context, {
  required String studentId,
  String? enrollmentId,
}) async {
  final PanelFooterSlot slot = PanelFooterSlot();
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final l10n = context.l10n;
  final bool? done = await showBhorPanel<bool>(
    context,
    kind: BhorPanelKind.form,
    title: enrollmentId == null ? l10n.stuLeftTitle : l10n.stuRemoveFromBatchTitle,
    width: 460,
    footer: slot.build,
    dirty: dirty,
    builder: (BuildContext ctx) =>
        LeaveDialog(studentId: studentId, enrollmentId: enrollmentId, footerSlot: slot, dirty: dirty),
  );
  return done ?? false;
}

class LeaveDialog extends ConsumerStatefulWidget {
  const LeaveDialog({super.key, required this.studentId, this.enrollmentId, this.footerSlot, this.dirty});

  final String studentId;
  final String? enrollmentId;

  /// Hosted inside [showBhorPanel]: no dialog frame; the confirm button goes
  /// to [footerSlot]. Null = standalone [BhorDialog].
  final PanelFooterSlot? footerSlot;

  /// Written true once the date or a month was changed.
  final ValueNotifier<bool>? dirty;

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
    final Map<String, String> subjectNames = <String, String>{
      for (final Subject sub in ref.watch(stuSubjectsProvider).value ?? const <Subject>[]) sub.id: sub.name,
    };
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
        if (b.id == id) return batchLabel(l10n, subjectNames[b.subjectId] ?? '', b.name);
      }
      return '';
    }

    final String title = one == null ? l10n.stuLeftTitle : l10n.stuRemoveFromBatchTitle;
    final String body = one == null
        ? l10n.stuLeftBody(student?.name ?? '')
        : l10n.stuRemoveFromBatchBody(student?.name ?? '', batchName(one));

    final Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(body, style: b.type.body.copyWith(color: b.colors.text2)),
            const SizedBox(height: BhorSpace.s16),
            DateField(
              label: l10n.stuLeftDate,
              value: date,
              lastDate: today.addDays(31),
              onChanged: (LocalDate d) => setState(() {
                _date = d;
                widget.dirty?.value = true;
              }),
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
                onChanged: (YearMonth m) => setState(() {
                  _edited[e.id] = m;
                  widget.dirty?.value = true;
                }),
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
    );
    final PanelFooterSlot? slot = widget.footerSlot;
    final Widget confirm = BhorButton(
      key: const ValueKey<String>('stu-leave-confirm'),
      label: one == null ? l10n.stuLeftConfirm : l10n.stuRemoveConfirm,
      expand: slot != null,
      onPressed: (_busy || (one != null && open.isEmpty)) ? null : () => _confirm(date, open, lbm),
    );
    if (slot != null) {
      slot.publish(confirm, alive: () => mounted);
      return content;
    }
    return BhorDialog(
      title: title,
      body: SingleChildScrollView(child: content),
      actions: <Widget>[
        BhorButton(
          label: l10n.commonCancel,
          variant: BhorButtonVariant.ghost,
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        confirm,
      ],
    );
  }
}
