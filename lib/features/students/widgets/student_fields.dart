// Form fields shared by the full-screen student form and the add sheet.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_form_model.dart';
import 'package:attendance_alamin/features/students/widgets/photo_picker.dart';

/// Name and guardian phone, then "আরও তথ্য" (roll, student phone, guardian
/// name, admission date, photo, notes).
class StudentFieldsView extends StatefulWidget {
  const StudentFieldsView({
    super.key,
    required this.model,
    required this.today,
    this.autofocusName = false,
    this.moreExpanded = false,
  });

  final StudentFormModel model;
  final LocalDate today;
  final bool autofocusName;

  /// Open "আরও তথ্য" from the start (edit form).
  final bool moreExpanded;

  @override
  State<StudentFieldsView> createState() => _StudentFieldsViewState();
}

class _StudentFieldsViewState extends State<StudentFieldsView> {
  late bool _open = widget.moreExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final StudentFormModel model = widget.model;
    return ListenableBuilder(
      listenable: model,
      builder: (BuildContext context, Widget? _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BhorTextField(
              key: const ValueKey<String>('stu-field-name'),
              controller: model.name,
              autofocus: widget.autofocusName,
              textInputAction: TextInputAction.next,
              onChanged: (_) => model.clearError('name'),
              label: l10n.stuFieldName,
              error: model.errors['name'],
            ),
            const SizedBox(height: BhorSpace.s12),
            BhorTextField(
              key: const ValueKey<String>('stu-field-guardian-phone'),
              controller: model.guardianPhone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onChanged: (_) => model.clearError('guardianPhone'),
              label: l10n.stuFieldGuardianPhone,
              error: model.errors['guardianPhone'],
            ),
            const SizedBox(height: BhorSpace.s4),
            BhorPressable(
              key: const ValueKey<String>('stu-more-info'),
              onTap: () => setState(() => _open = !_open),
              semanticLabel: l10n.stuMoreInfo,
              builder: (BuildContext c, BhorStates st) => ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BhorSize.minTap),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(l10n.stuMoreInfo, style: b.type.bodyStrong)),
                    Icon(_open ? Icons.expand_less : Icons.expand_more, color: b.colors.text2),
                  ],
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.only(bottom: BhorSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    BhorTextField(
                      controller: model.roll,
                      textInputAction: TextInputAction.next,
                      label: l10n.stuFieldRoll,
                    ),
                    const SizedBox(height: BhorSpace.s12),
                    BhorTextField(
                      controller: model.phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => model.clearError('phone'),
                      label: l10n.stuFieldStudentPhone,
                      error: model.errors['phone'],
                    ),
                    const SizedBox(height: BhorSpace.s12),
                    BhorTextField(
                      controller: model.guardianName,
                      textInputAction: TextInputAction.next,
                      label: l10n.stuFieldGuardianName,
                    ),
                    const SizedBox(height: BhorSpace.s12),
                    DateField(
                      label: l10n.stuFieldAdmissionDate,
                      value: model.admissionDate,
                      lastDate: widget.today.addDays(366),
                      onChanged: model.setAdmission,
                    ),
                    const SizedBox(height: BhorSpace.s12),
                    _PhotoRow(model: model),
                    const SizedBox(height: BhorSpace.s12),
                    BhorTextField(
                      controller: model.notes,
                      maxLines: 3,
                      minLines: 2,
                      label: l10n.commonNotes,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.model});

  final StudentFormModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool has = model.photoChanged ? model.photo != null : model.hadPhoto;
    return Row(
      children: <Widget>[
        ExcludeSemantics(
          child: BhorAvatar(
            name: model.name.text,
            size: 48,
            image: model.photo != null ? MemoryImage(model.photo!) : null,
          ),
        ),
        const SizedBox(width: BhorSpace.s12),
        Expanded(
          child: Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s4,
            children: <Widget>[
              BhorButton(
                variant: BhorButtonVariant.secondary,
                icon: Icons.photo_camera_outlined,
                label: has ? l10n.stuPhotoChange : l10n.stuPhotoAdd,
                onPressed: () async {
                  final bytes = await pickStudentPhoto(context);
                  if (bytes != null) model.setPhoto(bytes);
                },
              ),
              if (has)
                BhorButton(
                  variant: BhorButtonVariant.ghost,
                  label: l10n.stuPhotoRemove,
                  onPressed: () => model.setPhoto(null),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A date shown like a field; tapping opens the date picker.
class DateField extends ConsumerWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate = const LocalDate(2015, 1, 1),
    this.lastDate,
  });

  final String label;
  final LocalDate value;
  final ValueChanged<LocalDate> onChanged;
  final LocalDate firstDate;
  final LocalDate? lastDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BhorThemeData b = context.bhor;
    final LocalDate last = lastDate ?? value.addDays(366);
    final String shown = context.fmt.date(value);
    return BhorPressable(
      semanticLabel: '$label: $shown',
      excludeChildSemantics: true,
      onTap: () async {
        final LocalDate today = ref.read(todayProvider);
        final int weekStart = ref.read(weekStartProvider).value ?? DateTime.saturday;
        final DateTime? d = await showBhorDatePicker(
          context,
          initialDate: DateTime(value.year, value.month, value.day),
          firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
          lastDate: DateTime(last.year, last.month, last.day),
          weekStart: weekStart,
          today: DateTime(today.year, today.month, today.day),
        );
        if (d != null) onChanged(LocalDate(d.year, d.month, d.day));
      },
      builder: (BuildContext c, BhorStates st) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BhorSize.control + BhorSpace.s12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: b.colors.surface,
            borderRadius: BorderRadius.circular(BhorRadius.control),
            border: Border.all(color: st.hovered ? b.colors.accentLine : b.colors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12, vertical: BhorSpace.s8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(label, style: b.type.caption),
                      Text(shown, style: b.type.body),
                    ],
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 20, color: b.colors.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A month picked from a short list (first / last billable month).
class MonthDropdown extends StatelessWidget {
  const MonthDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.months,
    required this.onChanged,
  });

  final String label;
  final YearMonth value;
  final List<YearMonth> months;
  final ValueChanged<YearMonth> onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    return BhorSelect<YearMonth>(
      label: label,
      value: value,
      options: <BhorOption<YearMonth>>[
        for (final YearMonth m in months) BhorOption<YearMonth>(m, fmt.monthYear(m)),
      ],
      onChanged: onChanged,
    );
  }
}

/// "বেতন শুরু: [মাস ▾]" (default from the cutoff, Product 3.2) and the optional
/// fee override.
class StartMonthFeeFields extends StatelessWidget {
  const StartMonthFeeFields({
    super.key,
    required this.choice,
    required this.join,
    required this.cutoff,
  });

  final EnrollChoice choice;
  final LocalDate join;
  final int cutoff;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    return ListenableBuilder(
      listenable: choice,
      builder: (BuildContext context, Widget? _) {
        final YearMonth start = choice.startFor(join, cutoff);
        final YearMonth base = join.yearMonth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.stuBillingStartLine(context.fmt.monthYear(start)),
                key: const ValueKey<String>('stu-billing-start-line'),
                style: b.type.heading,
              ),
            ),
            const SizedBox(height: BhorSpace.s8),
            if (start == base || start == base.addMonths(1)) ...<Widget>[
              BhorSegmented<bool>(
                key: const ValueKey<String>('stu-billing-toggle'),
                segments: <BhorSegment<bool>>[
                  BhorSegment<bool>(true, l10n.stuStartThisMonth),
                  BhorSegment<bool>(false, l10n.stuStartNextMonth),
                ],
                value: start == base,
                onChanged: (bool thisMonth) => choice.setStart(thisMonth ? base : base.addMonths(1)),
              ),
              const SizedBox(height: BhorSpace.s12),
            ],
            MonthDropdown(
              label: l10n.stuBillingStart,
              value: start,
              months: monthChoices(base.addMonths(-12), base.addMonths(7), start),
              onChanged: choice.setStart,
            ),
            const SizedBox(height: BhorSpace.s4),
            Text(
              l10n.stuBillingStartHint(cutoffDayText(context, cutoff)),
              style: b.type.label.copyWith(color: b.colors.text2),
            ),
            const SizedBox(height: BhorSpace.s12),
            BhorTextField(
              key: const ValueKey<String>('stu-field-fee-override'),
              controller: choice.fee,
              keyboardType: TextInputType.number,
              label: l10n.stuFeeOverride,
              helper: l10n.stuFeeOverrideHint,
              error: choice.feeError,
            ),
          ],
        );
      },
    );
  }
}

String cutoffDayText(BuildContext context, int cutoff) =>
    context.fmt.number(cutoff);
