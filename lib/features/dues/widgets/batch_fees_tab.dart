// Batch detail › বেতন (UX 3 "Batch detail"): a month picker, the month's
// totals, and one row per student with the month's state and a Collect button.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/collection_blocks.dart';
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace s) => EmptyState(
              icon: Icons.error_outline,
              message: l10n.commonLoadingFailed,
            ),
            data: (List<LedgerLine> lines) {
              if (lines.isEmpty) {
                return EmptyState(icon: Icons.receipt_long_outlined, message: l10n.duesFeesEmpty);
              }
              final List<LedgerLine> rows = sortLedger(lines);
              final MonthTotals t = totalsOf(lines);
              return ListView(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 112),
                children: <Widget>[
                  _TotalsStrip(totals: t),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
                    child: Material(
                      color: context.aurora.surfaceDense,
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < rows.length; i++)
                            _LedgerRow(
                              key: ValueKey<String>('fees-row-${rows[i].terms.enrollmentId}'),
                              line: rows[i],
                              divider: i > 0,
                            ),
                        ],
                      ),
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
    final fmt = context.fmt;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _Mini(label: l10n.collExpected, value: fmt.money(totals.expected))),
          Expanded(child: _Mini(label: l10n.collReceived, value: fmt.money(totals.received))),
          Expanded(child: _Mini(label: l10n.collOutstanding, value: fmt.money(totals.outstanding))),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            maxLines: 1,
            style: tt.titleMedium?.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final MonthDue d = line.due;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: tokens.hairline)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    line.terms.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(color: tokens.textPrimary),
                  ),
                  Text(
                    d.state == MonthState.free ? l10n.uiStateFree : fmt.money(d.fee),
                    maxLines: 1,
                    style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            MonthStateChip(due: d),
            if (d.isOpen) ...<Widget>[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: ValueKey<String>('fees-collect-${line.terms.enrollmentId}'),
                tooltip: l10n.duesCollect,
                icon: const Icon(Icons.payments_outlined),
                onPressed: () => showCollectPaymentSheet(
                  context,
                  studentId: line.terms.studentId,
                  enrollmentId: line.terms.enrollmentId,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
