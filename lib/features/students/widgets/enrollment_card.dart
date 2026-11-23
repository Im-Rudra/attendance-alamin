// One card per enrollment on the student profile (UX 3): batch, fee, the month
// strip, outstanding dues, attendance summary and [টাকা নিন].

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
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
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/attendance/attendance_entry.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/widgets/enrollment_edits.dart';
import 'package:attendance_alamin/features/students/widgets/leave_dialog.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

class EnrollmentCard extends ConsumerWidget {
  const EnrollmentCard({
    super.key,
    required this.student,
    required this.enrollment,
    this.showCollect = true,
  });

  final Student student;
  final Enrollment enrollment;

  /// False when the profile already offers one student-level "Collect fee"
  /// (single enrollment), so the button is not shown twice (QA-18).
  final bool showCollect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final fmt = context.fmt;
    final LocalDate today = ref.watch(todayProvider);
    final List<Batch> batches = ref.watch(stuBatchesProvider).value ?? const <Batch>[];
    Batch? batch;
    for (final Batch b in batches) {
      if (b.id == enrollment.batchId) batch = b;
    }
    String batchTitle = '';
    if (batch != null) {
      String subjectName = '';
      for (final Subject sub in ref.watch(stuSubjectsProvider).value ?? const <Subject>[]) {
        if (sub.id == batch.subjectId) subjectName = sub.name;
      }
      batchTitle = batchLabel(l10n, subjectName, batch.name);
    }
    final EnrollmentDues? dues = ref.watch(enrollmentDuesProvider(enrollment.id)).value;
    final bool ended = enrollment.endDate != null;
    final bool active = student.status == StudentStatus.active;

    String? feeText;
    int? special;
    if (dues != null) {
      special = specialFeeAt(dues.terms.overrides, today.yearMonth);
      final ({int fee, bool missing}) f =
          DuesEngine.feeFor(dues.terms, today.yearMonth);
      feeText = f.missing ? l10n.stuFeeNotSet : l10n.stuMonthlyFee(fmt.money(f.fee));
    }

    return BhorCard(
      padding: const EdgeInsets.all(BhorSpace.s16),
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
                    Text(batchTitle, style: b.type.heading),
                    if (special != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
                        child: BhorTag(
                          key: ValueKey<String>('stu-special-fee-${enrollment.id}'),
                          label: l10n.stuSpecialFee(fmt.money(special)),
                          tone: BhorTone.accent,
                          icon: BhorIcons.takeMoney,
                        ),
                      )
                    else if (feeText != null)
                      Text(feeText, style: b.type.label.copyWith(color: b.colors.text2)),
                    Text(
                      l10n.stuJoinedLine(fmt.date(enrollment.joinDate)),
                      key: ValueKey<String>('stu-joined-${enrollment.id}'),
                      style: b.type.label.copyWith(color: b.colors.text2),
                    ),
                    Text(
                      l10n.stuBillingStartLine(fmt.monthYear(enrollment.startMonth)),
                      style: b.type.label.copyWith(color: b.colors.text2),
                    ),
                  ],
                ),
              ),
              // Its own context anchors the menu at this button (G7).
              Builder(
                builder: (BuildContext btn) => BhorIconButton(
                  icon: BhorIcons.overflowVertical,
                  semanticLabel: l10n.commonMore,
                  onPressed: () => showBhorMenu(
                    context,
                    anchor: btn,
                    items: <BhorMenuItem>[
                      BhorMenuItem(
                        icon: BhorIcons.calendar,
                        label: l10n.stuChangeJoinDate,
                        onTap: () => openChangeJoinDate(context, enrollment),
                      ),
                      BhorMenuItem(
                        icon: BhorIcons.calendar,
                        label: l10n.stuChangeBillingStart,
                        onTap: () => _editStartMonth(context, ref, today),
                      ),
                      if (!ended)
                        BhorMenuItem(
                          icon: BhorIcons.takeMoney,
                          label: l10n.stuChangeFee,
                          onTap: () => openChangeStudentFee(context, enrollment),
                        ),
                      if (!ended && active)
                        BhorMenuItem(
                          icon: BhorIcons.leftStudents,
                          label: l10n.stuRemoveFromBatchTitle,
                          destructive: true,
                          onTap: () =>
                              openLeaveDialog(context, studentId: student.id, enrollmentId: enrollment.id),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (ended) ...<Widget>[
            const SizedBox(height: BhorSpace.s4),
            Row(
              children: <Widget>[
                Icon(BhorIcons.leftStudents, size: 16, color: b.colors.text2),
                const SizedBox(width: BhorSpace.s8),
                Expanded(
                  child: Text(
                    enrollment.endMonth == null
                        ? l10n.stuLeftOn(fmt.date(enrollment.endDate!))
                        : l10n.stuEnrollmentEnded(
                            fmt.date(enrollment.endDate!),
                            fmt.monthYear(enrollment.endMonth!),
                          ),
                    style: b.type.label.copyWith(color: b.colors.text2),
                  ),
                ),
              ],
            ),
          ],
          if (dues != null && dues.months.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _MonthStrip(months: stripMonths(dues.months, today.yearMonth)),
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
                  style: b.type.bodyStrong,
                ),
                if (dues.worst != null && !dues.inactive)
                  _LevelTag(level: dues.worst!, dayInDue: dues.worstDay, monthCount: dues.openDue.length),
              ],
            ),
          ],
          const SizedBox(height: 8),
          EnrollmentAttendanceSummary(
              studentId: student.id, batchId: enrollment.batchId),
          if (showCollect && (!ended || (dues?.totalOutstanding ?? 0) > 0)) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: BhorButton(
                icon: BhorIcons.takeMoney,
                label: l10n.stuCollect,
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
    final l10n = context.l10n;
    final ValueNotifier<YearMonth> value = ValueNotifier<YearMonth>(enrollment.startMonth);
    final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
    final YearMonth? picked = await showBhorPanel<YearMonth>(
      context,
      kind: BhorPanelKind.form,
      title: l10n.stuChangeBillingStart,
      width: 420,
      dirty: dirty,
      builder: (BuildContext ctx) => _StartMonthBody(
        value: value,
        dirty: dirty,
        current: enrollment.startMonth,
        around: today.yearMonth,
      ),
      footer: (BuildContext ctx) => BhorButton(
        label: l10n.commonSave,
        expand: true,
        onPressed: () => Navigator.of(ctx).pop(value.value),
      ),
    );
    if (picked == null || picked == enrollment.startMonth) return;
    if (!context.mounted) return;
    try {
      await ref
          .read(enrollmentsRepositoryProvider)
          .setStartMonth(enrollment.id, picked);
    } on AppException catch (e) {
      if (context.mounted) BhorToast.show(context, message: errorText(l10n, e));
    }
  }
}

class _StartMonthBody extends StatelessWidget {
  const _StartMonthBody({
    required this.value,
    required this.dirty,
    required this.current,
    required this.around,
  });

  final ValueNotifier<YearMonth> value;
  final ValueNotifier<bool> dirty;
  final YearMonth current;
  final YearMonth around;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<YearMonth>(
      valueListenable: value,
      builder: (BuildContext context, YearMonth v, Widget? _) => MonthDropdown(
        label: l10n.stuBillingStart,
        value: v,
        months: monthChoices(around.addMonths(-24), around.addMonths(12), v),
        onChanged: (YearMonth m) {
          value.value = m;
          dirty.value = m != current;
        },
      ),
    );
  }
}

/// A due level as a tag: icon + word + day count, never colour alone.
class _LevelTag extends StatelessWidget {
  const _LevelTag({required this.level, required this.dayInDue, required this.monthCount});

  final DueLevel level;
  final int? dayInDue;
  final int monthCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final List<String> parts = <String>[level.label(l10n)];
    if (dayInDue != null && level != DueLevel.upcoming) parts.add(l10n.uiDayCount(fmt.number(dayInDue!)));
    return BhorTag.severity(level: level.severityLevel, label: parts.join(' · '), icon: level.icon);
  }
}

/// The enrollment's months: month name over a state tag (icon + word). The
/// tiles wrap onto further lines, so no tag is ever cut off at the edge.
class _MonthStrip extends StatelessWidget {
  const _MonthStrip({required this.months});

  final List<MonthDue> months;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BhorSpace.s4, bottom: BhorSpace.s4),
      child: Wrap(
        spacing: BhorSpace.s12,
        runSpacing: BhorSpace.s8,
        children: <Widget>[
          for (final MonthDue m in months) _MonthTile(key: ValueKey<int>(m.month.toInt()), due: m),
        ],
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({super.key, required this.due});

  final MonthDue due;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final Widget tag;
    final String word;
    switch (due.state) {
      case MonthState.paid:
        final bool advance = !due.isDue;
        word = advance ? l10n.uiStateAdvance : l10n.uiStatePaid;
        tag = BhorTag(
          label: word,
          tone: BhorTone.ok,
          icon: advance ? BhorIcons.addCircle : BhorIcons.checkCircleFill,
        );
      case MonthState.waived:
        word = l10n.uiStateWaived;
        tag = BhorTag(label: word, icon: BhorIcons.minus);
      case MonthState.free:
        word = l10n.uiStateFree;
        tag = BhorTag(label: word, icon: BhorIcons.overflow);
      case MonthState.partial:
      case MonthState.unpaid:
        final DueLevel? level = due.level;
        final bool partial = due.state == MonthState.partial;
        if (level == null || level == DueLevel.upcoming) {
          word = partial ? l10n.uiPartialLeft(fmt.money(due.remaining)) : l10n.uiLevelUpcoming;
          tag = BhorTag(label: word, icon: BhorIcons.clock);
        } else {
          word = partial ? l10n.uiPartialLeft(fmt.money(due.remaining)) : level.label(l10n);
          tag = BhorTag.severity(level: level.severityLevel, label: word, icon: level.icon);
        }
    }
    return Semantics(
      container: true,
      label: l10n.a11yMonthChip(fmt.monthYear(due.month), word),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Full month name, never a truncated short form.
            Text(fmt.monthName(due.month.month), maxLines: 1, style: b.type.label),
            const SizedBox(height: BhorSpace.s4),
            tag,
          ],
        ),
      ),
    );
  }
}
