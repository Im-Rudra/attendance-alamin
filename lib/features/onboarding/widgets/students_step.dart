// Step 3: the quick-add loop. Only a name and the guardian's phone; "save and
// add next" stores the student, clears the fields and keeps the cursor on the
// name field so the whole class can be typed without touching the screen.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/widgets/digits_formatter.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/features/extras/widgets/csv_import_flow.dart';
import 'package:attendance_alamin/features/onboarding/controllers/onboarding_service.dart';
import 'package:attendance_alamin/features/onboarding/widgets/onb_common.dart';

class StudentsStep extends StatelessWidget {
  const StudentsStep({
    super.key,
    required this.name,
    required this.phone,
    required this.nameFocus,
    required this.onAdd,
    required this.onImportCsv,
    required this.saved,
    required this.batchName,
    required this.billingMonth,
    required this.busy,
    this.error,
    this.lastAdded,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final FocusNode nameFocus;
  final VoidCallback onAdd;
  final VoidCallback onImportCsv;

  /// Students saved so far, oldest first.
  final List<SavedStudent> saved;

  /// The batch they join, or null when step 2 was skipped.
  final String? batchName;

  /// The formatted current month, shown as the billing start of these students.
  final String billingMonth;
  final bool busy;
  final String? error;

  /// Name of the student saved last (announced and shown briefly).
  final String? lastAdded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final String? batch = batchName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OnbHeading(title: l10n.onbStudentsTitle, body: l10n.onbStudentsBody),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Centre the icon on the first text line.
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                batch == null ? BhorIcons.info : BhorIcons.batches,
                size: 18,
                color: c.text3,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                batch == null ? l10n.onbStudentsNoBatch : l10n.onbStudentsIntoBatch(batch),
                key: const Key('onb-students-target'),
                style: b.type.meta,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 28),
          child: Text(
            l10n.onbBillingStartNote(billingMonth),
            key: const Key('onb-students-billing-note'),
            style: b.type.meta,
          ),
        ),
        const SizedBox(height: 16),
        OnbSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BhorTextField(
                key: const Key('onb-student-name'),
                textCapitalization: TextCapitalization.words,
                controller: name,
                focusNode: nameFocus,
                autofocus: true,
                textInputAction: TextInputAction.next,
                label: l10n.onbStudentName,
                error: error != null && phone.text.trim().isEmpty ? error : null,
              ),
              const SizedBox(height: 12),
              BhorTextField(
                key: const Key('onb-student-phone'),
                controller: phone,
                keyboardType: TextInputType.phone,
                inputFormatters: <TextInputFormatter>[DigitsFormatter(context.fmt, maxLength: 20, phone: true)],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                label: l10n.onbStudentPhone,
                prefix: const Icon(BhorIcons.phone),
                tabular: true,
                error: error != null && phone.text.trim().isNotEmpty ? error : null,
              ),
              const SizedBox(height: 12),
              BhorButton(
                key: const Key('onb-student-add'),
                label: l10n.onbStudentSaveNext,
                variant: BhorButtonVariant.secondary,
                onPressed: busy ? null : onAdd,
                expand: true,
              ),
              const SizedBox(height: 8),
              CsvImportButton(onPressed: busy ? null : onImportCsv),
              if (lastAdded != null) ...<Widget>[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: <Widget>[
                      Icon(BhorIcons.checkCircleFill, size: 18, color: c.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.onbStudentAddedNote(lastAdded!),
                          style: b.type.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (saved.isEmpty)
          Text(
            l10n.onbStudentsEmpty,
            key: const Key('onb-students-empty'),
            style: b.type.meta,
          )
        else ...<Widget>[
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              l10n.onbStudentsAdded(context.fmt.number(saved.length)),
              key: const Key('onb-students-count'),
              style: b.type.heading,
            ),
          ),
          const SizedBox(height: 8),
          for (final SavedStudent s in saved.reversed)
            BhorStagger(
              key: ValueKey<String>('onb-saved-${s.id}'),
              index: 0,
              child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BhorCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: <Widget>[
                    BhorAvatar(name: s.name, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.onbStudentRow(context.fmt.digits(s.roll), s.name),
                            style: b.type.body,
                          ),
                          if (s.guardianPhone != null)
                            Text(
                              context.fmt.digits(s.guardianPhone!),
                              key: Key('onb-added-phone-${s.id}'),
                              style: b.type.meta,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
        ],
      ],
    );
  }
}
