// Step 3: the quick-add loop. Only a name and the guardian's phone; "save and
// add next" stores the student, clears the fields and keeps the cursor on the
// name field so the whole class can be typed without touching the screen.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String? batch = batchName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OnbHeading(title: l10n.onbStudentsTitle, body: l10n.onbStudentsBody),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              batch == null ? Icons.info_outline : Icons.groups_2_outlined,
              size: 20,
              color: tokens.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                batch == null ? l10n.onbStudentsNoBatch : l10n.onbStudentsIntoBatch(batch),
                key: const Key('onb-students-target'),
                style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
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
            style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        OnbSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                key: const Key('onb-student-name'),
                controller: name,
                focusNode: nameFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.onbStudentName),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('onb-student-phone'),
                controller: phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(
                  labelText: l10n.onbStudentPhone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                key: const Key('onb-student-add'),
                onPressed: busy ? null : onAdd,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: Text(l10n.onbStudentSaveNext),
              ),
              const SizedBox(height: 8),
              CsvImportButton(onPressed: busy ? null : onImportCsv),
              if (lastAdded != null) ...<Widget>[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.check_circle, size: 18, color: tokens.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.onbStudentAddedNote(lastAdded!),
                          style: tt.bodyMedium?.copyWith(color: tokens.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 12),
          OnbErrorBox(message: error!),
        ],
        const SizedBox(height: 20),
        if (saved.isEmpty)
          Text(
            l10n.onbStudentsEmpty,
            key: const Key('onb-students-empty'),
            style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
          )
        else ...<Widget>[
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              l10n.onbStudentsAdded(context.fmt.number(saved.length)),
              key: const Key('onb-students-count'),
              style: tt.titleMedium?.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          for (final SavedStudent s in saved.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                dense: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: <Widget>[
                    InitialsAvatar(name: s.name, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.onbStudentRow(context.fmt.digits(s.roll), s.name),
                            style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
                          ),
                          if (s.guardianPhone != null)
                            Text(
                              context.fmt.digits(s.guardianPhone!),
                              key: Key('onb-added-phone-${s.id}'),
                              style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
