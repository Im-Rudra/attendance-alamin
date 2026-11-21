// "মাস ভাগ": the manual month-by-month split of a payment (Product 3.4, UX 2c
// chips). Every open month up to 12 months ahead is a row; a month can never
// get more than it still owes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.paySplitHelp, style: tt.bodySmall?.copyWith(color: tokens.textSecondary)),
        const SizedBox(height: 8),
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
            child: TextButton.icon(
              key: const ValueKey<String>('pay-split-auto'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onAuto,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: Text(l10n.paySplitAuto),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
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
          Semantics(
            button: true,
            checked: on,
            label: monthName,
            excludeSemantics: true,
            onTap: () => onChanged(on ? 0 : due.remaining),
            child: InkWell(
              key: ValueKey<String>('pay-split-check-${due.month.toInt()}'),
              borderRadius: BorderRadius.circular(24),
              onTap: () => onChanged(on ? 0 : due.remaining),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  on ? Icons.check_box : Icons.check_box_outline_blank,
                  color: on ? tokens.accent : tokens.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(monthName, style: tt.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  over ? l10n.paySplitTooMuch(fmt.money(due.remaining)) : status,
                  style: tt.bodySmall?.copyWith(color: over ? tokens.error : tokens.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
    return Semantics(
      label: widget.label,
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.end,
        inputFormatters: <TextInputFormatter>[DigitsFormatter(fmt)],
        onChanged: (String t) => widget.onChanged(parseDigits(t)),
        decoration: InputDecoration(
          isDense: true,
          prefixText: '৳',
          enabledBorder: widget.error
              ? OutlineInputBorder(borderSide: BorderSide(color: context.aurora.error))
              : null,
        ),
      ),
    );
  }
}
