// "নতুন ফি কোন মাস থেকে?" (Product 3.1, scenario 11): month choice plus the
// live "N টি মাস আংশিক হয়ে যাবে" warning before the fee is saved.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';

/// Returns the chosen first month, or null when dismissed.
///
/// [current] is the default (this month); months before [earliest] are not
/// offered. Callers pass the earliest first billable month of the batch's
/// enrollments, at least 24 months back (QA-01: a migrated student's past
/// months can carry the fee). Months older than the quick chips are offered
/// in a "আরও আগের মাস" dropdown. [previewPartial] returns how many
/// fully paid months would turn partial from the given month.
Future<YearMonth?> showFeeChangeSheet(
  BuildContext context, {
  required int oldFee,
  required int newFee,
  required YearMonth current,
  required YearMonth earliest,
  required Future<int> Function(YearMonth from) previewPartial,
}) {
  return showBhorSheet<YearMonth>(
    context,
    title: context.l10n.batchFeeFromTitle,
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

  /// Months before the quick chips, newest first, back to [FeeChangeSheet.earliest].
  List<YearMonth> get _older => <YearMonth>[
        for (YearMonth m = widget.current.addMonths(-3); !m.isBefore(widget.earliest); m = m.addMonths(-1)) m,
      ];

  void _pick(YearMonth m) {
    setState(() {
      _month = m;
      _preview = widget.previewPartial(m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.batchFeeFromBody(fmt.money(widget.oldFee), fmt.money(widget.newFee)),
            style: b.type.body.copyWith(color: b.colors.text2),
          ),
          const SizedBox(height: BhorSpace.s12),
          Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s8,
            children: <Widget>[
              for (final YearMonth m in _choices)
                BhorChip(label: fmt.monthYear(m), selected: m == _month, onSelected: (_) => _pick(m)),
            ],
          ),
          if (_older.isNotEmpty) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            BhorSelect<YearMonth>(
              key: const Key('fee-change-earlier'),
              value: _older.contains(_month) ? _month : null,
              hint: l10n.batchFeeEarlierMonth,
              options: <BhorOption<YearMonth>>[
                for (final YearMonth m in _older) BhorOption<YearMonth>(value: m, label: fmt.monthYear(m)),
              ],
              onChanged: _pick,
            ),
          ],
          const SizedBox(height: BhorSpace.s12),
          FutureBuilder<int>(
            future: _preview,
            builder: (BuildContext context, AsyncSnapshot<int> snap) {
              final int? n = snap.data;
              if (n == null) return const SizedBox(height: 48);
              final bool warn = n > 0;
              return BatchNotice(
                warn: warn,
                text: warn ? l10n.batchFeePartialWarn(fmt.number(n)) : l10n.batchFeeNoPartial,
              );
            },
          ),
          const SizedBox(height: BhorSpace.s16),
          BhorButton(label: l10n.batchFeeConfirm, expand: true, onPressed: () => Navigator.of(context).pop(_month)),
        ],
      ),
    );
  }
}
