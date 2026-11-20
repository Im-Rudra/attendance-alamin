// "নতুন ফি কোন মাস থেকে?" (Product 3.1, scenario 11): month choice plus the
// live "N টি মাস আংশিক হয়ে যাবে" warning before the fee is saved.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/time/year_month.dart';

/// Returns the chosen first month, or null when dismissed.
///
/// [current] is the default (this month); months before [earliest] (the
/// batch's first month) are not offered. [previewPartial] returns how many
/// fully paid months would turn partial from the given month.
Future<YearMonth?> showFeeChangeSheet(
  BuildContext context, {
  required int oldFee,
  required int newFee,
  required YearMonth current,
  required YearMonth earliest,
  required Future<int> Function(YearMonth from) previewPartial,
}) {
  return showModalBottomSheet<YearMonth>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => FeeChangeSheet(
      oldFee: oldFee,
      newFee: newFee,
      current: current,
      earliest: earliest,
      previewPartial: previewPartial,
    ),
  );
}

class FeeChangeSheet extends StatefulWidget {
  const FeeChangeSheet({
    super.key,
    required this.oldFee,
    required this.newFee,
    required this.current,
    required this.earliest,
    required this.previewPartial,
  });

  final int oldFee;
  final int newFee;
  final YearMonth current;
  final YearMonth earliest;
  final Future<int> Function(YearMonth from) previewPartial;

  @override
  State<FeeChangeSheet> createState() => _FeeChangeSheetState();
}

class _FeeChangeSheetState extends State<FeeChangeSheet> {
  late YearMonth _month = widget.current;
  late Future<int> _preview = widget.previewPartial(_month);

  List<YearMonth> get _choices => <YearMonth>[
        for (int i = -2; i <= 6; i++)
          if (!widget.current.addMonths(i).isBefore(widget.earliest)) widget.current.addMonths(i),
      ];

  void _pick(YearMonth m) {
    setState(() {
      _month = m;
      _preview = widget.previewPartial(m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(l10n.batchFeeFromTitle, style: tt.titleLarge?.copyWith(color: tokens.textPrimary)),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.batchFeeFromBody(fmt.money(widget.oldFee), fmt.money(widget.newFee)),
              style: tt.bodyLarge?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final YearMonth m in _choices)
                  ChoiceChip(
                    label: Text(fmt.monthYear(m)),
                    selected: m == _month,
                    onSelected: (_) => _pick(m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<int>(
              future: _preview,
              builder: (BuildContext context, AsyncSnapshot<int> snap) {
                final int? n = snap.data;
                if (n == null) return const SizedBox(height: 48);
                final bool warn = n > 0;
                final Color fg = warn ? tokens.onErrorContainer : tokens.textSecondary;
                return Semantics(
                  liveRegion: true,
                  container: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: warn ? tokens.errorContainer : tokens.surfaceDense,
                      borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
                      border: Border.all(color: warn ? tokens.errorContainerBorder : tokens.hairline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            warn ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: fg,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              warn
                                  ? l10n.batchFeePartialWarn(fmt.number(n))
                                  : l10n.batchFeeNoPartial,
                              style: tt.bodyLarge?.copyWith(color: fg),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_month),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              child: Text(l10n.batchFeeConfirm),
            ),
          ],
        ),
      ),
    );
  }
}
