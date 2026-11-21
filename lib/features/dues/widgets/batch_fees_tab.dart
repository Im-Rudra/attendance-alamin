// Batch detail › বেতন (UX 3 "Batch detail"): a month picker, the month's
// totals, and one row per student with the month's state and a Collect button.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/collection_blocks.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_tags.dart';
import 'package:attendance_alamin/features/dues/widgets/fees_segments.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';

/// Rows of the tab, most urgent first: open due months by severity, then open
/// months not due yet, paid, waived and free ones; name within a group.
List<LedgerLine> sortLedger(List<LedgerLine> lines) {
  int group(MonthDue d) {
    if (d.isOpen && d.isDue) return 0;
    if (d.isOpen) return 1;
    if (d.state == MonthState.paid) return 2;
    return 3;
  }

  final List<LedgerLine> sorted = <LedgerLine>[...lines];
  sorted.sort((LedgerLine a, LedgerLine b) {
    final int ga = group(a.due);
    final int gb = group(b.due);
    if (ga != gb) return ga.compareTo(gb);
    final int la = a.due.level?.rank ?? -1;
    final int lb = b.due.level?.rank ?? -1;
    if (la != lb) return lb.compareTo(la);
    return a.terms.studentName.compareTo(b.terms.studentName);
  });
  return sorted;
}

class BatchFeesPanel extends ConsumerStatefulWidget {
  const BatchFeesPanel({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<BatchFeesPanel> createState() => _BatchFeesPanelState();
}

class _BatchFeesPanelState extends ConsumerState<BatchFeesPanel> {
  /// `null` = the current month.
  YearMonth? _picked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final YearMonth current = ref.watch(todayProvider).yearMonth;
    final YearMonth month = _picked ?? current;
    final YearMonth? earliest = ref.watch(collEarliestMonthProvider);
    final AsyncValue<List<LedgerLine>> async =
        ref.watch(batchLedgerProvider((batchId: widget.batchId, month: month)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MonthPickerRow(
          month: month,
          canPrev: canStepBack(month, earliest),
          canNext: canStepForward(month, current),
          onChanged: (YearMonth m) => setState(() => _picked = m == current ? null : m),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: BhorSpinner()),
            error: (Object e, StackTrace s) => BhorEmptyState(
              icon: Icons.error_outline,
              title: l10n.commonLoadingFailed,
            ),
            data: (List<LedgerLine> lines) {
              if (lines.isEmpty) {
                return BhorEmptyState(icon: Icons.receipt_long_outlined, title: l10n.duesFeesEmpty);
              }
              final List<LedgerLine> rows = sortLedger(lines);
              final MonthTotals t = totalsOf(lines);
              return ListView(
                padding: const EdgeInsets.fromLTRB(0, BhorSpace.s4, 0, 112),
                children: <Widget>[
                  _TotalsStrip(totals: t),
                  const SizedBox(height: BhorSpace.s8),
                  BhorCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < rows.length; i++)
                          _LedgerRow(
                            key: ValueKey<String>('fees-row-${rows[i].terms.enrollmentId}'),
                            line: rows[i],
                            divider: i < rows.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TotalsStrip extends StatelessWidget {
  const _TotalsStrip({required this.totals});

  final MonthTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BhorCard(
      padding: const EdgeInsets.all(BhorSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _Mini(label: l10n.collExpected, amount: totals.expected)),
          Expanded(child: _Mini(label: l10n.collReceived, amount: totals.received)),
          Expanded(child: _Mini(label: l10n.collOutstanding, amount: totals.outstanding)),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: BhorMoney(amount, style: b.type.heading),
        ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({super.key, required this.line, required this.divider});

  final LedgerLine line;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final MonthDue d = line.due;
    return BhorListRow(
      title: line.terms.studentName,
      subtitle: d.state == MonthState.free ? l10n.uiStateFree : fmt.money(d.fee),
      divider: divider,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: monthStateTag(context, d),
          ),
          if (d.isOpen) ...<Widget>[
            const SizedBox(width: BhorSpace.s8),
            BhorIconButton(
              key: ValueKey<String>('fees-collect-${line.terms.enrollmentId}'),
              icon: Icons.payments_outlined,
              semanticLabel: l10n.duesCollect,
              variant: BhorButtonVariant.secondary,
              onPressed: () => showCollectPaymentSheet(
                context,
                studentId: line.terms.studentId,
                enrollmentId: line.terms.enrollmentId,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
