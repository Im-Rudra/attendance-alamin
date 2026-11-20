// The record / edit payment form shared by the bottom sheet and the desktop
// side panel (UX 2c): batch, months, amount, method, date, note and one big
// button that repeats the months and the amount.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/initials_avatar.dart';
import 'package:attendance_alamin/app/widgets/sticky_action_bar.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/features/payments/controllers/collect_payment_controller.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/receipt_text.dart';
import 'package:attendance_alamin/features/payments/widgets/allocation_editor.dart';
import 'package:attendance_alamin/features/payments/widgets/waive_dialog.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class CollectPaymentForm extends ConsumerStatefulWidget {
  const CollectPaymentForm({
    super.key,
    required this.studentId,
    required this.onDone,
    this.enrollmentId,
    this.receiptId,
    this.onClose,
  });

  final String studentId;
  final String? enrollmentId;

  /// Set when an existing receipt is edited.
  final String? receiptId;

  /// Called after a successful save.
  final ValueChanged<SavedPayment> onDone;

  /// Shows a close button in the header when set.
  final VoidCallback? onClose;

  @override
  ConsumerState<CollectPaymentForm> createState() => _CollectPaymentFormState();
}

class _CollectPaymentFormState extends ConsumerState<CollectPaymentForm> {
  final TextEditingController _amount = TextEditingController();
  final FocusNode _amountFocus = FocusNode();
  final TextEditingController _note = TextEditingController();
  bool _splitOpen = false;
  bool _showNote = false;
  bool _amountSeeded = false;

  PayArgs get _args =>
      (studentId: widget.studentId, enrollmentId: widget.enrollmentId, receiptId: widget.receiptId);

  @override
  void initState() {
    super.initState();
    _amountFocus.addListener(() {
      if (_amountFocus.hasFocus) {
        _amount.selection = TextSelection(baseOffset: 0, extentOffset: _amount.text.length);
      }
    });
    final String initial = ref.read(collectPaymentControllerProvider(_args)).note;
    if (initial.isNotEmpty) {
      _note.text = initial;
      _showNote = true;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    _note.dispose();
    super.dispose();
  }

  void _showAmount(AppFormat fmt, int value) {
    final String text = value > 0 ? fmt.digits(value.toString()) : '';
    if (!_amountSeeded) {
      _amountSeeded = true;
      _amount.text = text;
      return;
    }
    if (parseDigits(_amount.text) == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || parseDigits(_amount.text) == value) return;
      _amount.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    });
  }

  Future<void> _pickDate(LocalDate current, LocalDate today) async {
    final DateTime last = DateTime(today.year, today.month, today.day);
    DateTime first = DateTime(today.year - 2, 1, 1);
    final DateTime initial = DateTime(current.year, current.month, current.day);
    if (initial.isBefore(first)) first = initial;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    ref
        .read(collectPaymentControllerProvider(_args).notifier)
        .setDate(LocalDate(picked.year, picked.month, picked.day));
  }

  Future<void> _submit() async {
    final SavedPayment? saved = await ref.read(collectPaymentControllerProvider(_args).notifier).submit();
    if (saved != null && mounted) widget.onDone(saved);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final PayArgs args = _args;
    final CollectInput input = ref.watch(collectPaymentControllerProvider(args));
    final AsyncValue<List<EnrollmentDues>> choicesAsync = ref.watch(payChoicesProvider(widget.studentId));
    final LocalDate today = ref.watch(todayProvider);
    final bool editing = widget.receiptId != null;

    if (choicesAsync.hasError) {
      return _Message(text: l10n.commonLoadingFailed);
    }
    final List<EnrollmentDues>? choices = choicesAsync.value;
    if (choices == null) return const _Loading();

    final String? enrollmentId = resolveEnrollmentId(
      picked: input.enrollmentId,
      requested: widget.enrollmentId,
      choices: choices,
    );
    if (enrollmentId == null) return _Message(text: l10n.payNoEnrollment);

    final AsyncValue<EnrollmentDues?> duesAsync =
        ref.watch(payDuesProvider((enrollmentId: enrollmentId, receiptId: widget.receiptId)));
    if (duesAsync.hasError) return _Message(text: l10n.commonLoadingFailed);
    final EnrollmentDues? dues = duesAsync.value;
    if (!duesAsync.hasValue) return const _Loading();
    if (dues == null) return _Message(text: l10n.payNoEnrollment);

    final CollectPlan plan = buildPlan(dues: dues, today: today, amount: input.amount, split: input.split);
    final bool manual = input.split != null;
    final List<PaymentMethod> visible = ref.watch(paymentMethodsConfigProvider).visible;
    final PaymentMethod method = input.method ?? defaultMethod(visible);
    final LocalDate paidOn = input.paidOn ?? today;
    final int shownAmount = manual ? plan.total : (input.amount ?? plan.prefill);
    _showAmount(fmt, shownAmount);

    final notifier = ref.read(collectPaymentControllerProvider(args).notifier);
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final EnrollmentTerms terms = dues.terms;
    final bool chooser = choices.length > 1 && widget.enrollmentId == null && !editing;

    final String? errorMessage = input.errorCode == null ? null : errorTextForCode(l10n, input.errorCode!);
    final String? problemMessage = switch (plan.problem) {
      PlanProblem.overflow => l10n.payErrOverflow(fmt.money(plan.maxPlaceable)),
      PlanProblem.nothingOpen => l10n.payErrNothingOpen,
      _ => null,
    };
    final String? disabledReason = switch (plan.problem) {
      PlanProblem.none => null,
      PlanProblem.noAmount => l10n.payDisabledAmount,
      PlanProblem.overflow => l10n.payDisabledOverflow,
      PlanProblem.splitExceeds => l10n.payDisabledSplit,
      PlanProblem.nothingOpen => l10n.payDisabledNoMonths,
    };
    final String buttonLabel = plan.ok ? _buttonLabel(l10n, fmt, plan, today, editing) : (editing ? l10n.payButtonSaveEdit : l10n.payTitle);

    final List<Widget> body = <Widget>[
      Row(
        children: <Widget>[
          InitialsAvatar(name: terms.studentName, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(editing ? l10n.payTitleEdit : l10n.payTitle, style: tt.titleMedium),
                ),
                Text(
                  _subtitle(terms),
                  style: tt.bodySmall?.copyWith(color: tokens.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!editing)
            PopupMenuButton<String>(
              key: const ValueKey<String>('pay-menu'),
              tooltip: l10n.payMenuTooltip,
              enabled: plan.openMonths.isNotEmpty,
              onSelected: (String v) {
                if (v == 'waive' && plan.openMonths.isNotEmpty) {
                  runWaiveDialog(context, enrollmentId: enrollmentId, month: plan.openMonths.first.month);
                }
              },
              itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  key: const ValueKey<String>('pay-menu-waive'),
                  value: 'waive',
                  child: Text(l10n.payWaiveMenu),
                ),
              ],
            ),
          if (widget.onClose != null)
            IconButton(
              tooltip: l10n.commonClose,
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
        ],
      ),
      if (chooser) ...<Widget>[
        const SizedBox(height: 16),
        _Label(l10n.payBatchLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final EnrollmentDues c in choices)
              _Pill(
                key: ValueKey<String>('pay-batch-${c.terms.enrollmentId}'),
                label: c.totalOutstanding > 0
                    ? l10n.payBatchOwed(c.terms.batchName, fmt.money(c.totalOutstanding))
                    : l10n.payBatchClear(c.terms.batchName),
                selected: c.terms.enrollmentId == enrollmentId,
                onTap: () => notifier.pickEnrollment(c.terms.enrollmentId),
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      _Label(l10n.payMonthsLabel),
      Semantics(
        liveRegion: true,
        child: Text(
          plan.months.isEmpty
              ? l10n.payMonthsNone
              : fmt.monthList(plan.months, currentYear: today.year, partial: plan.partialMonths.toSet()),
          key: const ValueKey<String>('pay-months'),
          style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 16),
      _Label(l10n.payAmountLabel),
      TextField(
        key: const ValueKey<String>('pay-amount'),
        controller: _amount,
        focusNode: _amountFocus,
        readOnly: manual,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[DigitsFormatter(fmt)],
        style: tt.titleLarge,
        onChanged: (String t) => notifier.setAmount(parseDigits(t).toString()),
        decoration: InputDecoration(
          prefixText: '৳ ',
          helperText: manual ? l10n.payAmountFromSplit : null,
          errorText: problemMessage,
          errorMaxLines: 3,
        ),
      ),
      if (plan.ok && plan.partialLeft > 0)
        _Note(
          key: const ValueKey<String>('pay-partial-note'),
          icon: Icons.info_outline,
          text: l10n.payPartialNote(fmt.money(plan.partialLeft)),
        ),
      if (plan.ok && plan.advanceTotal > 0 && !plan.pureAdvance)
        _Note(
          key: const ValueKey<String>('pay-advance-note'),
          icon: Icons.event_available,
          text: l10n.payAdvanceNote(
            fmt.money(plan.advanceTotal),
            fmt.monthList(plan.advanceMonths, currentYear: today.year),
          ),
        ),
      const SizedBox(height: 8),
      _SplitHeader(
        open: _splitOpen,
        title: l10n.paySplitTitle,
        onTap: () => setState(() => _splitOpen = !_splitOpen),
      ),
      if (_splitOpen)
        AllocationEditor(
          plan: plan,
          manual: manual,
          currentYear: today.year,
          onChanged: (YearMonth m, int v) => notifier.setSplit(m, v, <YearMonth, int>{
            for (final Allocation a in plan.allocations) a.month: a.amount,
          }),
          onAuto: () => notifier.resetSplit(keepAmount: plan.total > 0 ? plan.total : null),
        ),
      const SizedBox(height: 16),
      _Label(l10n.payMethodLabel),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final PaymentMethod m in visible)
            _Pill(
              key: ValueKey<String>('pay-method-${m.code}'),
              label: paymentMethodLabel(l10n, m),
              selected: m == method,
              semanticsLabel: l10n.payA11yMethod(paymentMethodLabel(l10n, m)),
              onTap: () => notifier.setMethod(m),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Label(l10n.payDateLabel),
                Text(
                  paidOn == today ? l10n.payDateToday(fmt.date(paidOn)) : fmt.date(paidOn),
                  key: const ValueKey<String>('pay-date'),
                  style: tt.bodyLarge,
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey<String>('pay-date-edit'),
            tooltip: l10n.payDateEdit,
            onPressed: () => _pickDate(paidOn, today),
            icon: const Icon(Icons.edit_calendar),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
      if (_showNote)
        TextField(
          key: const ValueKey<String>('pay-note'),
          controller: _note,
          maxLength: 120,
          onChanged: notifier.setNote,
          decoration: InputDecoration(labelText: l10n.payNoteLabel),
        )
      else
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey<String>('pay-note-add'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => setState(() => _showNote = true),
            icon: const Icon(Icons.edit_note),
            label: Text(l10n.payNoteAdd),
          ),
        ),
      if (errorMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(errorMessage, style: tt.bodyMedium?.copyWith(color: tokens.error)),
        ),
      const SizedBox(height: 8),
    ];

    final Widget bar = KeyedSubtree(
      key: const ValueKey<String>('pay-bar'),
      child: StickyActionBar(
        label: buttonLabel,
        onPressed: plan.ok && !input.busy ? _submit : null,
        disabledReason: disabledReason,
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final Widget scroll = SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (box.hasBoundedHeight) Flexible(child: scroll) else scroll,
            bar,
          ],
        );
      },
    );
  }

  String _subtitle(EnrollmentTerms t) {
    final List<String> parts = <String>[
      t.studentName,
      if (t.subjectName.isNotEmpty) t.subjectName,
      t.batchName,
    ];
    return parts.join(' · ');
  }

  String _buttonLabel(AppLocalizations l10n, AppFormat fmt, CollectPlan plan, LocalDate today, bool editing) {
    if (editing) return l10n.payButtonSaveEdit;
    final List<YearMonth> months = plan.months;
    final String amount = fmt.money(plan.total);
    final List<YearMonth> sorted = months.toSet().toList()..sort();
    var consecutive = true;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].toInt() != sorted[i - 1].addMonths(1).toInt()) consecutive = false;
    }
    if (sorted.length > 3 && !consecutive) {
      return l10n.payButtonCount(fmt.digits(sorted.length.toString()), amount);
    }
    final String span = possessive(
      monthsSpan(fmt, sorted, currentYear: today.year),
      bangla: fmt.lang == Lang.bn,
    );
    return plan.pureAdvance ? l10n.payButtonAdvance(span, amount) : l10n.payButtonMonths(span, amount);
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.aurora.textSecondary),
        ),
      );
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: tokens.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitHeader extends StatelessWidget {
  const _SplitHeader({required this.open, required this.title, required this.onTap});

  final bool open;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    return Semantics(
      button: true,
      expanded: open,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: const ValueKey<String>('pay-split-toggle'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tokens.accent),
                ),
              ),
              Icon(open ? Icons.expand_less : Icons.expand_more, color: tokens.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticsLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final Color fg = selected ? tokens.onAccentContainer : tokens.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? tokens.accentContainer : tokens.surfaceDense,
        shape: StadiumBorder(side: BorderSide(color: selected ? tokens.accent : tokens.hairline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (selected) ...<Widget>[
                    Icon(Icons.check, size: 18, color: fg),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: fg,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
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
