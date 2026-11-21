// The record / edit payment form shared by the bottom sheet and the desktop
// side panel (UX 2c): batch, months, amount, method, date, note and one big
// button that repeats the months and the amount.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
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
    this.fill = false,
  });

  final String studentId;
  final String? enrollmentId;

  /// Set when an existing receipt is edited.
  final String? receiptId;

  /// Called after a successful save.
  final ValueChanged<SavedPayment> onDone;

  /// Shows a close button in the header when set.
  final VoidCallback? onClose;

  /// True inside a sheet / side panel of fixed height: the save bar is pinned
  /// to the bottom and the form scrolls above it.
  final bool fill;

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

  /// The ⋮ menu: waive the first open month.
  Future<void> _openMenu(String enrollmentId, YearMonth month) async {
    final bool? waive = await showBhorPanel<bool>(
      context,
      kind: BhorPanelKind.list,
      width: 360,
      builder: (BuildContext ctx) => BhorList(
        children: <Widget>[
          BhorListRow(
            key: const ValueKey<String>('pay-menu-waive'),
            title: context.l10n.payWaiveMenu,
            divider: false,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (waive != true || !mounted) return;
    await runWaiveDialog(context, enrollmentId: enrollmentId, month: month);
  }

  Future<void> _pickDate(LocalDate current, LocalDate today) async {
    final DateTime last = DateTime(today.year, today.month, today.day);
    DateTime first = DateTime(today.year - 2, 1, 1);
    final DateTime initial = DateTime(current.year, current.month, current.day);
    if (initial.isBefore(first)) first = initial;
    final DateTime? picked = await showBhorDatePicker(
      context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
      weekStart: ref.read(weekStartProvider).value ?? DateTime.saturday,
      today: last,
    );
    if (picked == null || !mounted) return;
    ref
        .read(collectPaymentControllerProvider(_args).notifier)
        .setDate(LocalDate(picked.year, picked.month, picked.day));
  }

  /// Single-shot: set synchronously on the first tap and kept after a
  /// successful save (the sheet closes / the panel builds a fresh form), so a
  /// fast second tap can never record a second receipt, even while the
  /// refreshed dues re-prefill the next month.
  bool _locked = false;

  Future<void> _submit() async {
    if (_locked) return;
    setState(() => _locked = true);
    final SavedPayment? saved = await ref.read(collectPaymentControllerProvider(_args).notifier).submit();
    if (saved != null) {
      if (mounted) widget.onDone(saved);
      return;
    }
    if (mounted) setState(() => _locked = false);
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

    final CollectPlan plan = buildPlan(
      dues: dues,
      today: today,
      amount: input.amount,
      split: input.split,
      start: input.startMonth,
    );
    final bool manual = input.split != null;
    final List<PaymentMethod> visible = ref.watch(paymentMethodsConfigProvider).visible;
    final PaymentMethod method = input.method ?? defaultMethod(visible);
    final LocalDate paidOn = input.paidOn ?? today;
    final Set<YearMonth> selectedMonths = plan.months.isNotEmpty
        ? plan.months.toSet()
        : <YearMonth>{
            if (plan.openMonths.isNotEmpty) input.startMonth ?? plan.openMonths.first.month,
          };
    final int shownAmount = manual ? plan.total : (input.amount ?? plan.prefill);
    _showAmount(fmt, shownAmount);

    final notifier = ref.read(collectPaymentControllerProvider(args).notifier);
    final BhorThemeData b = context.bhor;
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
          BhorAvatar(name: terms.studentName, size: 44),
          const SizedBox(width: BhorSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  terms.studentName,
                  style: b.type.heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _subtitle(terms),
                  style: b.type.meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!editing)
            BhorIconButton(
              key: const ValueKey<String>('pay-menu'),
              icon: BhorIcons.overflowVertical,
              semanticLabel: l10n.payMenuTooltip,
              variant: BhorButtonVariant.secondary,
              circle: true,
              onPressed: plan.openMonths.isEmpty
                  ? null
                  : () => _openMenu(enrollmentId, plan.openMonths.first.month),
            ),
          if (widget.onClose != null) ...<Widget>[
            const SizedBox(width: BhorSpace.s8),
            BhorIconButton(
              icon: BhorIcons.close,
              semanticLabel: l10n.commonClose,
              variant: BhorButtonVariant.secondary,
              circle: true,
              onPressed: widget.onClose,
            ),
          ],
        ],
      ),
      if (chooser) ...<Widget>[
        const SizedBox(height: BhorSpace.s16),
        _Label(l10n.payBatchLabel),
        Wrap(
          spacing: BhorSpace.s8,
          runSpacing: BhorSpace.s4,
          children: <Widget>[
            for (final EnrollmentDues c in choices)
              BhorChip(
                key: ValueKey<String>('pay-batch-${c.terms.enrollmentId}'),
                label: c.totalOutstanding > 0
                    ? l10n.payBatchOwed(c.terms.batchName, fmt.money(c.totalOutstanding))
                    : l10n.payBatchClear(c.terms.batchName),
                selected: c.terms.enrollmentId == enrollmentId,
                onSelected: (bool _) => notifier.pickEnrollment(c.terms.enrollmentId),
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      _Label(l10n.payMonthsLabel),
      if (!editing && plan.openMonths.isNotEmpty) ...<Widget>[
        Wrap(
          key: const ValueKey<String>('pay-month-chips'),
          spacing: BhorSpace.s8,
          runSpacing: BhorSpace.s4,
          children: <Widget>[
            for (final MonthDue md in plan.openMonths.take(6))
              BhorChip(
                key: ValueKey<String>('pay-month-${md.month.toInt()}'),
                label: _chipLabel(l10n, fmt, md, today),
                selected: selectedMonths.contains(md.month),
                onSelected: (bool _) => notifier.pickMonth(md.month),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      Semantics(
        liveRegion: true,
        child: Text(
          plan.months.isEmpty
              ? l10n.payMonthsNone
              : (plan.pureAdvance
                  ? l10n.payMonthAdvance(possessive(
                      monthsSpan(fmt, plan.months, currentYear: today.year),
                      bangla: fmt.lang == Lang.bn,
                    ))
                  : fmt.monthList(plan.months, currentYear: today.year, partial: plan.partialMonths.toSet())),
          key: const ValueKey<String>('pay-months'),
          style: b.type.bodyStrong,
        ),
      ),
      const SizedBox(height: 16),
      BhorTextField(
        key: const ValueKey<String>('pay-amount'),
        label: l10n.payAmountLabel,
        controller: _amount,
        focusNode: _amountFocus,
        readOnly: manual,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[DigitsFormatter(fmt)],
        tabular: true,
        onChanged: (String t) => notifier.setAmount(parseDigits(t).toString()),
        prefix: Text('৳', style: b.type.body.copyWith(color: b.colors.text2)),
        // The amount in the app language (grouped), so a typo is obvious.
        helper: manual
            ? l10n.payAmountFromSplit
            : (shownAmount > 0 && plan.problem == PlanProblem.none ? fmt.money(shownAmount) : null),
        error: problemMessage,
      ),
      if (plan.ok && plan.partialLeft > 0)
        _Note(
          key: const ValueKey<String>('pay-partial-note'),
          icon: BhorIcons.info,
          text: l10n.payPartialNote(fmt.money(plan.partialLeft)),
        ),
      if (plan.ok && plan.advanceTotal > 0 && !plan.pureAdvance)
        _Note(
          key: const ValueKey<String>('pay-advance-note'),
          icon: BhorIcons.calendar,
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
        spacing: BhorSpace.s8,
        runSpacing: BhorSpace.s4,
        children: <Widget>[
          for (final PaymentMethod m in visible)
            BhorChip(
              key: ValueKey<String>('pay-method-${m.code}'),
              label: paymentMethodLabel(l10n, m),
              selected: m == method,
              onSelected: (bool _) => notifier.setMethod(m),
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
                  style: b.type.body,
                ),
              ],
            ),
          ),
          BhorIconButton(
            key: const ValueKey<String>('pay-date-edit'),
            icon: BhorIcons.calendar,
            semanticLabel: l10n.payDateEdit,
            variant: BhorButtonVariant.secondary,
            circle: true,
            onPressed: () => _pickDate(paidOn, today),
          ),
        ],
      ),
      if (_showNote)
        BhorTextField(
          key: const ValueKey<String>('pay-note'),
          controller: _note,
          maxLength: 120,
          onChanged: notifier.setNote,
          label: l10n.payNoteLabel,
        )
      else
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BhorButton(
            key: const ValueKey<String>('pay-note-add'),
            variant: BhorButtonVariant.ghost,
            icon: BhorIcons.notes,
            label: l10n.payNoteAdd,
            onPressed: () => setState(() => _showNote = true),
          ),
        ),
      if (errorMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(errorMessage, style: b.type.body.copyWith(color: b.colors.danger)),
        ),
      const SizedBox(height: 8),
    ];

    final Widget bar = KeyedSubtree(
      key: const ValueKey<String>('pay-bar'),
      child: _ActionBar(
        label: buttonLabel,
        onPressed: plan.ok && !input.busy && !_locked ? _submit : null,
        loading: input.busy || _locked,
        disabledReason: disabledReason,
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final Widget scroll = SingleChildScrollView(
          padding: const EdgeInsets.only(top: BhorSpace.s4, bottom: BhorSpace.s8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
        );
        final bool pinned = widget.fill && box.hasBoundedHeight;
        return Column(
          mainAxisSize: pinned ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (pinned)
              Expanded(child: scroll)
            else if (box.hasBoundedHeight)
              Flexible(child: scroll)
            else
              scroll,
            bar,
          ],
        );
      },
    );
  }

  String _chipLabel(AppLocalizations l10n, AppFormat fmt, MonthDue md, LocalDate today) {
    final String name = fmt.monthList(<YearMonth>[md.month], currentYear: today.year);
    if (!md.isDue) return l10n.payChipAdvance(name);
    if (md.paid > 0) return l10n.payChipPartial(name);
    return name;
  }

  String _subtitle(EnrollmentTerms t) {
    final List<String> parts = <String>[
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
        child: Center(child: BhorSpinner()),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(BhorSpace.s24),
        child: Center(
          child: Text(text, textAlign: TextAlign.center, style: context.bhor.type.body),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: context.bhor.type.label.copyWith(color: context.bhor.colors.text2)),
      );
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Padding(
      padding: const EdgeInsets.only(top: BhorSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: b.colors.accent),
          const SizedBox(width: BhorSpace.s8),
          Expanded(child: Text(text, style: b.type.body)),
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
    final BhorThemeData b = context.bhor;
    return Semantics(
      expanded: open,
      child: BhorPressable(
        key: const ValueKey<String>('pay-split-toggle'),
        onTap: onTap,
        semanticLabel: title,
        excludeChildSemantics: true,
        radius: BhorRadius.control,
        builder: (BuildContext context, BhorStates s) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BhorSize.minTap),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(title, style: b.type.label.copyWith(color: b.colors.accent))),
              Icon(open ? BhorIcons.chevronUp : BhorIcons.chevronDown, color: b.colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// The big save button pinned under the form, with the reason it is disabled.
/// While the save runs the button shows the spinner (and ignores taps).
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.label,
    required this.onPressed,
    required this.loading,
    this.disabledReason,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: b.colors.line))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, BhorSpace.s12, 0, BhorSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BhorButton(
              label: label,
              onPressed: onPressed,
              loading: loading,
              expand: true,
              size: BhorButtonSize.lg,
            ),
            AnimatedSize(
              duration: BhorMotion.of(context, BhorMotion.fast),
              curve: BhorMotion.ease,
              alignment: Alignment.topCenter,
              child: onPressed == null && !loading && disabledReason != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: BhorSpace.s8),
                      child: Text(disabledReason!, textAlign: TextAlign.center, style: b.type.meta),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
