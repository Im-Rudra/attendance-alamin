// Form fields shared by the full-screen student form and the add sheet.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_form_model.dart';
import 'package:attendance_alamin/features/students/widgets/photo_picker.dart';

/// Name and guardian phone, then "আরও তথ্য" (roll, student phone, guardian
/// name, admission date, photo, notes).
class StudentFieldsView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: model,
      builder: (BuildContext context, Widget? _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('stu-field-name'),
              controller: model.name,
              autofocus: autofocusName,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => model.clearError('name'),
              decoration: InputDecoration(
                labelText: l10n.stuFieldName,
                errorText: model.errors['name'],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('stu-field-guardian-phone'),
              controller: model.guardianPhone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onChanged: (_) => model.clearError('guardianPhone'),
              decoration: InputDecoration(
                labelText: l10n.stuFieldGuardianPhone,
                errorText: model.errors['guardianPhone'],
              ),
            ),
            const SizedBox(height: 4),
            // ListTile (inside ExpansionTile) paints on the nearest Material,
            // so give it its own above the dense card behind it.
            Material(
              type: MaterialType.transparency,
              child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey<String>('stu-more-info'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: moreExpanded,
                title: Text(l10n.stuMoreInfo),
                children: <Widget>[
                  TextField(
                    controller: model.roll,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l10n.stuFieldRoll),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: model.phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => model.clearError('phone'),
                    decoration: InputDecoration(
                      labelText: l10n.stuFieldStudentPhone,
                      errorText: model.errors['phone'],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: model.guardianName,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        InputDecoration(labelText: l10n.stuFieldGuardianName),
                  ),
                  const SizedBox(height: 12),
                  DateField(
                    label: l10n.stuFieldAdmissionDate,
                    value: model.admissionDate,
                    lastDate: today.addDays(366),
                    onChanged: model.setAdmission,
                  ),
                  const SizedBox(height: 12),
                  _PhotoRow(model: model),
                  const SizedBox(height: 12),
                  TextField(
                    controller: model.notes,
                    maxLines: 3,
                    minLines: 2,
                    decoration: InputDecoration(labelText: l10n.commonNotes),
                  ),
                ],
              ),
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
    final tokens = context.aurora;
    final bool has = model.photoChanged ? model.photo != null : model.hadPhoto;
    return Row(
      children: <Widget>[
        ExcludeSemantics(
          child: model.photo != null
              ? ClipOval(
                  child: Image.memory(model.photo!,
                      width: 48, height: 48, fit: BoxFit.cover),
                )
              : InitialsAvatar(name: model.name.text, size: 48),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(has ? l10n.stuPhotoChange : l10n.stuPhotoAdd),
                onPressed: () async {
                  final bytes = await pickStudentPhoto(context);
                  if (bytes != null) model.setPhoto(bytes);
                },
              ),
              if (has)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: tokens.error),
                  onPressed: () => model.setPhoto(null),
                  child: Text(l10n.stuPhotoRemove),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A date shown like a field; tapping opens the date picker.
class DateField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final LocalDate last = lastDate ?? value.addDays(366);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final DateTime? d = await showAppDatePicker(
          context: context,
          initialDate: DateTime(value.year, value.month, value.day),
          firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
          lastDate: DateTime(last.year, last.month, last.day),
        );
        if (d != null) onChanged(LocalDate(d.year, d.month, d.day));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(context.fmt.date(value)),
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
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<YearMonth>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: <DropdownMenuItem<YearMonth>>[
            for (final YearMonth m in months)
              DropdownMenuItem<YearMonth>(
                value: m,
                child: Text(fmt.monthYear(m), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (YearMonth? m) {
            if (m != null) onChanged(m);
          },
        ),
      ),
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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                        color: context.aurora.textPrimary,
                        fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            if (start == base || start == base.addMonths(1)) ...<Widget>[
              SegmentedChoice<bool>(
                key: const ValueKey<String>('stu-billing-toggle'),
                options: const <bool>[true, false],
                selected: start == base,
                onChanged: (bool thisMonth) =>
                    choice.setStart(thisMonth ? base : base.addMonths(1)),
                labelOf: (bool thisMonth) =>
                    thisMonth ? l10n.stuStartThisMonth : l10n.stuStartNextMonth,
              ),
              const SizedBox(height: 12),
            ],
            MonthDropdown(
              label: l10n.stuBillingStart,
              value: start,
              months: monthChoices(
                  base.addMonths(-12), base.addMonths(7), start),
              onChanged: choice.setStart,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.stuBillingStartHint(cutoffDayText(context, cutoff)),
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: context.aurora.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('stu-field-fee-override'),
              controller: choice.fee,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.stuFeeOverride,
                helperText: l10n.stuFeeOverrideHint,
                errorText: choice.feeError,
              ),
            ),
          ],
        );
      },
    );
  }
}

String cutoffDayText(BuildContext context, int cutoff) =>
    context.fmt.number(cutoff);
