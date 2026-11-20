// Step 2: "create your first batch" as one scrolling form with a live preview
// on top: subject (+ class chips), batch name, the weekly slot editor with its
// clash check, the monthly fee and the two billing cards in plain words.
// Once the batch is saved the form is replaced by a calm "ready" card.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/onboarding/widgets/onb_common.dart';
import 'package:attendance_alamin/features/schedule/schedule_entry.dart';

/// The class chips, in order, with their labels.
List<String> onbClassLabels(BuildContext context) {
  final l10n = context.l10n;
  return <String>[
    l10n.onbClass6,
    l10n.onbClass7,
    l10n.onbClass8,
    l10n.onbClass9,
    l10n.onbClass10,
    l10n.onbClass11,
    l10n.onbClass12,
    l10n.onbClassSsc,
    l10n.onbClassHsc,
  ];
}

class BatchStep extends StatelessWidget {
  const BatchStep({
    super.key,
    required this.subject,
    required this.name,
    required this.fee,
    required this.billing,
    required this.onBilling,
    required this.slots,
    required this.onSlots,
    required this.onCheck,
    required this.classLabel,
    required this.onSubjectChip,
    required this.onClassChip,
    required this.created,
    this.error,
  });

  final TextEditingController subject;
  final TextEditingController name;
  final TextEditingController fee;
  final BillingType billing;
  final ValueChanged<BillingType> onBilling;

  /// Starting slots of the editor (read once by the editor).
  final List<SlotDraft> slots;
  final ValueChanged<List<SlotDraft>> onSlots;
  final ValueChanged<SlotCheckResult> onCheck;

  /// The class chip that is on (so a second tap swaps it), if any.
  final String? classLabel;
  final ValueChanged<String> onSubjectChip;
  final ValueChanged<String> onClassChip;

  /// Subject and batch name once the batch was saved, else null.
  final ({String subject, String batch})? created;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = created;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OnbHeading(title: l10n.onbBatchTitle, body: l10n.onbBatchBody),
        const SizedBox(height: 16),
        if (done != null)
          _CreatedCard(subject: done.subject, batch: done.batch)
        else ...<Widget>[
          _Preview(subject: subject, name: name, fee: fee),
          const SizedBox(height: 16),
          OnbSection(child: _form(context)),
          if (error != null) ...<Widget>[
            const SizedBox(height: 16),
            OnbErrorBox(message: error!),
          ],
        ],
      ],
    );
  }

  Widget _form(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String typed = subject.text.trim();
    final List<String> suggestions = <String>[
      l10n.batchSuggestMath,
      l10n.batchSuggestEnglish,
      l10n.batchSuggestPhysics,
      l10n.batchSuggestChemistry,
      l10n.batchSuggestBiology,
      l10n.batchSuggestIct,
    ];
    final List<String> classes = onbClassLabels(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const Key('onb-subject'),
          controller: subject,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.batchSubjectLabel,
            hintText: l10n.batchSubjectHint,
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.batchSubjectSuggest, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String s in suggestions)
              ChoiceChip(
                label: Text(s),
                selected: typed.startsWith(s),
                onSelected: (_) => onSubjectChip(s),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.onbClassPick, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String c in classes)
              ChoiceChip(
                label: Text(c),
                selected: classLabel == c,
                onSelected: (_) => onClassChip(c),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('onb-batch-name'),
          controller: name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l10n.batchNameLabel),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(l10n.batchScheduleLabel, style: tt.titleMedium?.copyWith(color: tokens.textPrimary)),
        ),
        const SizedBox(height: 8),
        SlotEditorField(
          initial: slots,
          onChanged: onSlots,
          batchId: null,
          onCheck: onCheck,
        ),
        const SizedBox(height: 20),
        TextField(
          key: const Key('onb-fee'),
          controller: fee,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.batchFeeLabel,
            prefixText: '৳ ',
            errorText: _feeError(context),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(l10n.batchBillingTitle, style: tt.titleMedium?.copyWith(color: tokens.textPrimary)),
        ),
        const SizedBox(height: 8),
        _BillingChoice(
          title: l10n.batchBillingPrepaid,
          example: l10n.batchBillingPrepaidExample,
          selected: billing == BillingType.prepaid,
          onTap: () => onBilling(BillingType.prepaid),
        ),
        const SizedBox(height: 8),
        _BillingChoice(
          title: l10n.batchBillingPostpaid,
          example: l10n.batchBillingPostpaidExample,
          selected: billing == BillingType.postpaid,
          onTap: () => onBilling(BillingType.postpaid),
        ),
      ],
    );
  }

  String? _feeError(BuildContext context) {
    if (fee.text.trim().isEmpty) return null;
    try {
      Validators.amount(fee.text);
      return null;
    } on ValidationException {
      return context.l10n.errAmountInvalid;
    }
  }
}

/// "Math — Class 10 / Batch 1 · ৳1,000 / month" as it will look in the app.
class _Preview extends StatelessWidget {
  const _Preview({required this.subject, required this.name, required this.fee});

  final TextEditingController subject;
  final TextEditingController name;
  final TextEditingController fee;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String s = subject.text.trim();
    final String n = name.text.trim();
    String? feeText;
    try {
      feeText = l10n.batchFeePerMonth(context.fmt.money(Validators.amount(fee.text)));
    } on ValidationException {
      feeText = null;
    }
    final String line = n.isEmpty
        ? (feeText ?? '')
        : (feeText == null ? n : l10n.onbPreviewLine(n, feeText));
    return GlassCard(
      key: const Key('onb-preview'),
      dense: true,
      child: Row(
        children: <Widget>[
          Icon(Icons.groups_2_outlined, color: tokens.accent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  s.isEmpty ? l10n.onbPreviewEmpty : s,
                  style: tt.titleMedium?.copyWith(
                    color: s.isEmpty ? tokens.textSecondary : tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (line.isNotEmpty)
                  Text(line, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatedCard extends StatelessWidget {
  const _CreatedCard({required this.subject, required this.batch});

  final String subject;
  final String batch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return GlassCard(
      key: const Key('onb-batch-done'),
      dense: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.check_circle, color: tokens.accent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.onbBatchDoneTitle,
                  style: tt.titleMedium?.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.onbBatchDoneLine(subject, batch),
                  style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.onbBatchDoneHint,
                  style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "When do students pay?" radio card (plain words + a worked example).
class _BillingChoice extends StatelessWidget {
  const _BillingChoice({
    required this.title,
    required this.example,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String example;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusDenseList);
    final Color fg = selected ? tokens.onAccentContainer : tokens.textPrimary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$title. $example',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? tokens.accentContainer : tokens.surfaceDense,
        shape: RoundedRectangleBorder(
          borderRadius: br,
          side: BorderSide(color: selected ? tokens.accent : tokens.hairline, width: selected ? 2 : 1),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: br),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? tokens.onAccentContainer : tokens.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: tt.titleMedium?.copyWith(
                            color: fg,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          example,
                          style: tt.bodyMedium?.copyWith(color: selected ? tokens.onAccentContainer : tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
