// One card per enrollment on the student profile (UX 3): batch, fee, the month
// strip, outstanding dues, attendance summary and [টাকা নিন].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/attendance/attendance_entry.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/widgets/leave_dialog.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

enum _CardAction { startMonth, remove }

class EnrollmentCard extends ConsumerWidget {
  const EnrollmentCard({super.key, required this.student, required this.enrollment});

  final Student student;
  final Enrollment enrollment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final LocalDate today = ref.watch(todayProvider);
    final List<Batch> batches = ref.watch(stuBatchesProvider).value ?? const <Batch>[];
    Batch? batch;
    for (final Batch b in batches) {
      if (b.id == enrollment.batchId) batch = b;
    }
    final EnrollmentDues? dues = ref.watch(enrollmentDuesProvider(enrollment.id)).value;
    final bool ended = enrollment.endDate != null;
    final bool active = student.status == StudentStatus.active;

    String? feeText;
    if (dues != null) {
      final ({int fee, bool missing}) f =
          DuesEngine.feeFor(dues.terms, today.yearMonth);
      feeText = f.missing ? l10n.stuFeeNotSet : l10n.stuMonthlyFee(fmt.money(f.fee));
    }

    return GlassCard(
      dense: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      batch?.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
                    ),
                    if (feeText != null)
                      Text(feeText,
                          style: tt.labelMedium
                              ?.copyWith(color: tokens.textSecondary)),
                    Text(
                      l10n.stuBillingStartLine(fmt.monthYear(enrollment.startMonth)),
                      style:
                          tt.labelMedium?.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_CardAction>(
                tooltip: l10n.commonMore,
                onSelected: (_CardAction a) async {
                  switch (a) {
                    case _CardAction.startMonth:
                      await _editStartMonth(context, ref, today);
                    case _CardAction.remove:
                      await openLeaveDialog(context,
                          studentId: student.id, enrollmentId: enrollment.id);
                  }
                },
                itemBuilder: (BuildContext ctx) =>
                    <PopupMenuEntry<_CardAction>>[
                  PopupMenuItem<_CardAction>(
                    value: _CardAction.startMonth,
                    child: Text(l10n.stuChangeBillingStart),
                  ),
                  if (!ended && active)
                    PopupMenuItem<_CardAction>(
                      value: _CardAction.remove,
                      child: Text(l10n.stuRemoveFromBatchTitle),
                    ),
                ],
              ),
            ],
          ),
          if (ended) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Icon(Icons.person_off_outlined,
                    size: 16, color: tokens.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    enrollment.endMonth == null
                        ? l10n.stuLeftOn(fmt.date(enrollment.endDate!))
                        : l10n.stuEnrollmentEnded(
                            fmt.date(enrollment.endDate!),
                            fmt.monthYear(enrollment.endMonth!),
                          ),
                    style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          if (dues != null && dues.months.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            MonthStrip(months: stripMonths(dues.months, today.yearMonth)),
          ],
          if (dues != null && dues.totalOutstanding > 0) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  l10n.stuOutstanding(fmt.money(dues.totalOutstanding)),
                  style: tt.titleSmall?.copyWith(color: tokens.textPrimary),
                ),
                if (dues.worst != null && !dues.inactive)
                  SeverityBadge(
                    level: dues.worst!,
                    dayInDue: dues.worstDay,
                    monthCount: dues.openDue.length,
                    compact: true,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          EnrollmentAttendanceSummary(
              studentId: student.id, batchId: enrollment.batchId),
          if (!ended || (dues?.totalOutstanding ?? 0) > 0) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                icon: const Icon(Icons.payments_outlined),
                label: Text(l10n.stuCollect),
                onPressed: () => showCollectPaymentSheet(context,
                    studentId: student.id, enrollmentId: enrollment.id),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editStartMonth(
      BuildContext context, WidgetRef ref, LocalDate today) async {
    final YearMonth? picked = await showDialog<YearMonth>(
      context: context,
      builder: (BuildContext ctx) => _StartMonthDialog(
        current: enrollment.startMonth,
        around: today.yearMonth,
      ),
    );
    if (picked == null || picked == enrollment.startMonth) return;
    if (!context.mounted) return;
    final l10n = context.l10n;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(enrollmentsRepositoryProvider)
          .setStartMonth(enrollment.id, picked);
    } on AppException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
    }
  }
}

class _StartMonthDialog extends StatefulWidget {
  const _StartMonthDialog({required this.current, required this.around});

  final YearMonth current;
  final YearMonth around;

  @override
  State<_StartMonthDialog> createState() => _StartMonthDialogState();
}

class _StartMonthDialogState extends State<_StartMonthDialog> {
  late YearMonth _value = widget.current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.stuChangeBillingStart,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              MonthDropdown(
                label: l10n.stuBillingStart,
                value: _value,
                months: monthChoices(widget.around.addMonths(-24),
                    widget.around.addMonths(12), _value),
                onChanged: (YearMonth m) => setState(() => _value = m),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_value),
                    child: Text(l10n.commonSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
