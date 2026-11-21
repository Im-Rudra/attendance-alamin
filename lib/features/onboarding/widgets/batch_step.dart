// Step 2: "create your first batch" as one scrolling form with a live preview
// on top: subject (+ class chips), batch name, the weekly slot editor with its
// clash check, the monthly fee and the two billing cards in plain words.
// Once the batch is saved the form is replaced by a calm "ready" card.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
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
    final BhorThemeData b = context.bhor;
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
        BhorTextField(
          key: const Key('onb-subject'),
          controller: subject,
          textInputAction: TextInputAction.next,
          label: l10n.batchSubjectLabel,
          hint: l10n.batchSubjectHint,
        ),
        const SizedBox(height: 8),
        Text(l10n.batchSubjectSuggest, style: b.type.meta),
        const SizedBox(height: 4),
        _ChipRow(
          children: <Widget>[
            for (final String s in suggestions)
              BhorChip(
                label: s,
                selected: typed.startsWith(s),
                onSelected: (_) => onSubjectChip(s),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.onbClassPick, style: b.type.meta),
        const SizedBox(height: 4),
        _ChipRow(
          children: <Widget>[
            for (final String c in classes)
              BhorChip(
                label: c,
                selected: classLabel == c,
                onSelected: (_) => onClassChip(c),
              ),
          ],
        ),
        const SizedBox(height: 16),
        BhorTextField(
          key: const Key('onb-batch-name'),
          controller: name,
          textInputAction: TextInputAction.next,
          label: l10n.batchNameLabel,
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(l10n.batchScheduleLabel, style: b.type.heading),
        ),
        const SizedBox(height: 8),
        SlotEditorField(
          initial: slots,
          onChanged: onSlots,
          batchId: null,
          onCheck: onCheck,
        ),
        const SizedBox(height: 20),
        BhorTextField(
          key: const Key('onb-fee'),
          controller: fee,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          label: l10n.batchFeeLabel,
          prefix: Text('৳', style: b.type.body.copyWith(color: b.colors.text3)),
          tabular: true,
          error: _feeError(context),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(l10n.batchBillingTitle, style: b.type.heading),
        ),
        const SizedBox(height: 8),
        BhorRadioCard<BillingType>(
          value: BillingType.prepaid,
          groupValue: billing,
          onChanged: onBilling,
          title: l10n.batchBillingPrepaid,
          subtitle: l10n.batchBillingPrepaidExample,
        ),
        const SizedBox(height: 8),
        BhorRadioCard<BillingType>(
          value: BillingType.postpaid,
          groupValue: billing,
          onChanged: onBilling,
          title: l10n.batchBillingPostpaid,
          subtitle: l10n.batchBillingPostpaidExample,
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

/// One horizontally scrolling row of chips (no chip walls).
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: BhorSpace.s8),
              children[i],
            ],
          ],
        ),
      );
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
    final BhorThemeData b = context.bhor;
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
    return BhorCard(
      key: const Key('onb-preview'),
      child: Row(
        children: <Widget>[
          Icon(BhorIcons.batches, color: b.colors.accent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  s.isEmpty ? l10n.onbPreviewEmpty : s,
                  style: b.type.heading.copyWith(color: s.isEmpty ? b.colors.text3 : b.colors.text),
                ),
                if (line.isNotEmpty) Text(line, style: b.type.meta),
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
    final BhorThemeData b = context.bhor;
    return BhorCard(
      key: const Key('onb-batch-done'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(BhorIcons.checkCircleFill, color: b.colors.accent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.onbBatchDoneTitle,
                  style: b.type.heading,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.onbBatchDoneLine(subject, batch),
                  style: b.type.body,
                ),
                const SizedBox(height: 8),
                Text(l10n.onbBatchDoneHint, style: b.type.meta),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
