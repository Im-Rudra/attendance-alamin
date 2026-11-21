// "মাস ভাগ": the manual month-by-month split of a payment (Product 3.4, UX 2c
// chips). Every open month up to 12 months ahead is a row; a month can never
// get more than it still owes.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/digits_formatter.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/payments/controllers/collect_payment_controller.dart';

export 'package:attendance_alamin/app/widgets/digits_formatter.dart';

class AllocationEditor extends StatelessWidget {
  const AllocationEditor({
    super.key,
    required this.plan,
    required this.manual,
    required this.currentYear,
    required this.onChanged,
    required this.onAuto,
  });

  final CollectPlan plan;

  /// The teacher has taken over the split.
  final bool manual;
  final int currentYear;
  final void Function(YearMonth month, int amount) onChanged;
  final VoidCallback onAuto;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.paySplitHelp, style: b.type.meta),
        const SizedBox(height: BhorSpace.s8),
        for (final MonthDue md in plan.openMonths)
          _SplitRow(
            key: ValueKey<int>(md.month.toInt()),
            due: md,
            value: plan.allocatedTo(md.month),
            currentYear: currentYear,
            onChanged: (int v) => onChanged(md.month, v),
          ),
        if (manual)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BhorButton(
              key: const ValueKey<String>('pay-split-auto'),
              variant: BhorButtonVariant.ghost,
              icon: BhorIcons.sparkle,
              label: l10n.paySplitAuto,
              onPressed: onAuto,
            ),
          ),
      ],
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    super.key,
    required this.due,
    required this.value,
    required this.currentYear,
    required this.onChanged,
  });

  final MonthDue due;
  final int value;
  final int currentYear;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final bool over = value > due.remaining;
    final bool on = value > 0;
    final String monthName = fmt.monthList(<YearMonth>[due.month], currentYear: currentYear);
    final String status = due.state == MonthState.partial
        ? l10n.paySplitPartial(fmt.money(due.remaining))
        : (due.isDue
            ? l10n.paySplitOwed(fmt.money(due.remaining))
            : l10n.paySplitUpcoming(fmt.money(due.remaining)));
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: <Widget>[
          BhorPressable(
            key: ValueKey<String>('pay-split-check-${due.month.toInt()}'),
            onTap: () => onChanged(on ? 0 : due.remaining),
            semanticLabel: monthName,
            checked: on,
            excludeChildSemantics: true,
            radius: 24,
            builder: (BuildContext context, BhorStates s) => SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                on ? BhorIcons.checkCircleFill : BhorIcons.minus,
                color: on ? b.colors.accent : b.colors.text2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(monthName, style: b.type.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  over ? l10n.paySplitTooMuch(fmt.money(due.remaining)) : status,
                  style: b.type.meta.copyWith(color: over ? b.colors.danger : b.colors.text2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: BhorSpace.s8),
          SizedBox(
            width: 112,
            child: _SplitField(
              key: ValueKey<String>('pay-split-${due.month.toInt()}'),
              value: value,
              error: over,
              label: l10n.paySplitMonthField(monthName),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitField extends StatefulWidget {
  const _SplitField({
    super.key,
    required this.value,
    required this.error,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final bool error;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  State<_SplitField> createState() => _SplitFieldState();
}

class _SplitFieldState extends State<_SplitField> {
  final TextEditingController _ctrl = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _syncTo(AppFormat fmt) {
    if (parseDigits(_ctrl.text) == widget.value) return;
    final String text = widget.value == 0 ? '' : fmt.digits(widget.value.toString());
    if (!_seeded) {
      _ctrl.text = text;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || parseDigits(_ctrl.text) == widget.value) return;
      _ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    _syncTo(fmt);
    _seeded = true;
    return BhorTextField(
      controller: _ctrl,
      semanticLabel: widget.label,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.end,
      tabular: true,
      inputFormatters: <TextInputFormatter>[DigitsFormatter(fmt)],
      onChanged: (String t) => widget.onChanged(parseDigits(t)),
      prefix: Text('৳', style: context.bhor.type.body.copyWith(color: context.bhor.colors.text2)),
      // An over-limit amount turns the border red (the row says why).
      error: widget.error ? ' ' : null,
    );
  }
}
