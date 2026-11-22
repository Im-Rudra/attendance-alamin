// The record / edit payment form shared by the bottom sheet and the desktop
// side panel (UX 2c): batch, months, amount, method, date, note and one big
// button that repeats the months and the amount.

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/widgets/chip_wrap.dart';
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
    this.barSink,
    this.dirtySink,
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

  /// When set, the save bar is not drawn inside the form: its state is
  /// published here and the container's pinned footer draws it ([PayBar]).
  final ValueNotifier<PayBarSpec?>? barSink;

  /// Set to true once the teacher changed something (closing then asks first).
  final ValueNotifier<bool>? dirtySink;

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
  late final CollectInput _base;
  bool _touched = false;

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
    _base = ref.read(collectPaymentControllerProvider(_args));
    final String initial = _base.note;
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

  /// Inline "মাফ করুন": waive the first open month.
  Future<void> _waive(String enrollmentId, YearMonth month) =>
      runWaiveDialog(context, enrollmentId: enrollmentId, month: month);

  Future<void> _pickDate(LocalDate current, LocalDate today, BuildContext anchor) async {
    final DateTime last = DateTime(today.year, today.month, today.day);
    DateTime first = DateTime(today.year - 2, 1, 1);
    final DateTime initial = DateTime(current.year, current.month, current.day);
    if (initial.isBefore(first)) first = initial;
    final DateTime? picked = await showBhorDatePicker(
      context,
      anchor: anchor,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: first,
      lastDate: last,
      weekStart: ref.read(weekStartProvider).value ?? DateTime.saturday,
      today: last,
    );
    if (picked == null || !mounted) return;
    _touched = true;
    ref
        .read(collectPaymentControllerProvider(_args).notifier)
        .setDate(LocalDate(picked.year, picked.month, picked.day));
  }

  bool _sameSplit(Map<YearMonth, int>? a, Map<YearMonth, int>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (final MapEntry<YearMonth, int> e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  /// True once the teacher changed something (a typed amount, another month
  /// or split, a note, the method or date): closing then asks first.
  bool _isDirty(CollectInput i) {
    final CollectInput b = _base;
    if (i.amountText != b.amountText || i.startMonth != b.startMonth || i.note != b.note) return true;
    if (!_sameSplit(i.split, b.split)) return true;
    if (widget.receiptId != null) return i.method != b.method || i.paidOn != b.paidOn;
    return _touched || (i.enrollmentId != null && i.enrollmentId != b.enrollmentId);
  }

  /// Hands [spec] and the dirty flag to the container once the frame is built
  /// (a notifier must not change while the tree builds).
  void _publish(PayBarSpec spec, bool dirty) {
    final ValueNotifier<PayBarSpec?>? bar = widget.barSink;
    final ValueNotifier<bool>? d = widget.dirtySink;
    if (bar == null && d == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (bar != null && bar.value != spec) bar.value = spec;
      if (d != null && d.value != dirty) d.value = dirty;
    });
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

  /// The last fully built form. Once the save starts the sheet shows this
  /// frozen copy: the refreshed dues would otherwise re-prefill the next
  /// month under the success overlay.
  ({List<Widget> body, String label})? _frozen;

  Widget _frame(List<Widget> body, Widget bar) {
    if (widget.barSink != null) {
      // The container pins the save bar; the content just flows and scrolls.
      return SingleChildScrollView(
        padding: const EdgeInsets.only(top: BhorSpace.s4, bottom: BhorSpace.s8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final ({List<Widget> body, String label})? frozen = _frozen;
    if (_locked && frozen != null) {
      _publish((label: frozen.label, enabled: false, loading: true, reason: null, submit: _submit), true);
      return _frame(
        frozen.body,
        KeyedSubtree(
          key: const ValueKey<String>('pay-bar'),
          child: _ActionBar(label: frozen.label, onPressed: null, loading: true),
        ),
      );
    }
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
        ChipWrap(
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
        _MonthGrid(
          key: const ValueKey<String>('pay-month-chips'),
          chips: <Widget>[
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
        localDigits: true,
        inputFormatters: <TextInputFormatter>[DigitsFormatter(fmt)],
        tabular: true,
        onChanged: (String t) => notifier.setAmount(parseDigits(t).toString()),
        prefix: Text('৳', style: b.type.body.copyWith(color: b.colors.text2)),
        helper: manual ? l10n.payAmountFromSplit : null,
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
      ChipWrap(
        spacing: BhorSpace.s8,
        runSpacing: BhorSpace.s4,
        children: <Widget>[
          for (final PaymentMethod m in visible)
            BhorChip(
              key: ValueKey<String>('pay-method-${m.code}'),
              label: paymentMethodLabel(l10n, m),
              selected: m == method,
              onSelected: (bool _) {
                _touched = true;
                notifier.setMethod(m);
              },
            ),
        ],
      ),
      const SizedBox(height: 16),
      Builder(
        builder: (BuildContext bc) => _DateField(
          key: const ValueKey<String>('pay-date-edit'),
          label: l10n.payDateLabel,
          value: paidOn == today ? l10n.payDateToday(fmt.date(paidOn)) : fmt.date(paidOn),
          semanticLabel: l10n.payDateEdit,
          onTap: () => _pickDate(paidOn, today, bc),
        ),
      ),
      const SizedBox(height: BhorSpace.s8),
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
      if (!editing && plan.openMonths.isNotEmpty)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BhorButton(
            key: const ValueKey<String>('pay-menu-waive'),
            variant: BhorButtonVariant.ghost,
            icon: BhorIcons.minus,
            label: l10n.payWaiveMenu,
            onPressed: () => _waive(enrollmentId, plan.openMonths.first.month),
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

    _frozen = (body: body, label: buttonLabel);
    final bool canSave = plan.ok && !input.busy && !_locked;
    _publish(
      (
        label: buttonLabel,
        enabled: canSave,
        loading: input.busy || _locked,
        reason: canSave ? null : disabledReason,
        submit: _submit,
      ),
      _isDirty(input),
    );
    return _frame(body, bar);
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

/// A field-styled date row: tap anywhere to change the date.
class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String value;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return BhorPressable(
      onTap: onTap,
      semanticLabel: '$label, $value. $semanticLabel',
      excludeChildSemantics: true,
      builder: (BuildContext context, BhorStates s) => AnimatedContainer(
        duration: BhorMotion.of(context, BhorMotion.fast),
        curve: BhorMotion.ease,
        constraints: const BoxConstraints(minHeight: BhorSize.field),
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s8),
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? b.colors.soft2 : b.colors.soft,
          borderRadius: BorderRadius.circular(BhorRadius.control),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: b.type.caption),
                  Text(value, key: const ValueKey<String>('pay-date'), style: b.type.body),
                ],
              ),
            ),
            Icon(BhorIcons.calendar, size: 18, color: b.colors.accent),
          ],
        ),
      ),
    );
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
        builder: (BuildContext context, BhorStates s) => Container(
          constraints: const BoxConstraints(minHeight: BhorSize.minTap),
          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16),
          decoration: BoxDecoration(
            color: s.hovered || s.pressed ? b.colors.soft2 : b.colors.soft,
            borderRadius: BorderRadius.circular(BhorRadius.control),
          ),
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

/// What the pinned save bar shows (published by the form, drawn by [PayBar]).
typedef PayBarSpec = ({String label, bool enabled, bool loading, String? reason, VoidCallback submit});

/// The footer of a payment panel: the save bar for the published spec; tapping calls
/// the form's own submit. Listens to [sink] (the form publishes into it).
class PayBar extends StatelessWidget {
  const PayBar({super.key, required this.sink, required this.fallbackLabel});

  final ValueListenable<PayBarSpec?> sink;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PayBarSpec?>(
      valueListenable: sink,
      builder: (BuildContext context, PayBarSpec? spec, Widget? _) => KeyedSubtree(
        key: const ValueKey<String>('pay-bar'),
        child: _ActionBar(
          label: spec?.label ?? fallbackLabel,
          onPressed: spec != null && spec.enabled ? spec.submit : null,
          loading: spec?.loading ?? false,
          disabledReason: spec?.reason,
          framed: false,
        ),
      ),
    );
  }
}

/// Month chips in an even grid (2 or 3 equal columns, never a ragged wrap).
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({super.key, required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    const double gap = BhorSpace.s8;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double w = c.maxWidth.isFinite ? c.maxWidth : 360;
        final int cols = (w - 2 * gap) / 3 >= 150 ? 3 : 2;
        final double cell = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          children: <Widget>[
            // At least one cell wide (an even grid); a long label may grow
            // its chip rather than overflow.
            for (final Widget chip in chips) ConstrainedBox(constraints: BoxConstraints(minWidth: cell), child: chip),
          ],
        );
      },
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
    this.framed = true,
  });

  /// False inside a container footer (it draws the top rule and padding).
  final bool framed;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return DecoratedBox(
      decoration: BoxDecoration(border: framed ? Border(top: BorderSide(color: b.colors.line)) : null),
      child: Padding(
        padding: framed ? const EdgeInsets.fromLTRB(0, BhorSpace.s12, 0, BhorSpace.s4) : EdgeInsets.zero,
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
