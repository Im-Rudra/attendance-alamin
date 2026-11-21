// The blocks of the monthly collection summary (Product 3.7):
// 1. the billing month: expected / received / waived / outstanding, per batch;
// 2. cash in during the calendar month: by method, other income, total, and
//    the receipts behind it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

// ---- block 1: the billing month ---------------------------------------------

class BillingBlock extends StatelessWidget {
  const BillingBlock({super.key, required this.summary, required this.onSeeDues});

  final CollectionSummary summary;

  /// Outstanding tile tapped: open the dues list filtered to this month.
  final VoidCallback onSeeDues;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final MonthTotals t = summary.totals;
    final bool nothing = t.expected == 0 && t.waivedCount == 0;

    final List<Widget> children = <Widget>[
      SectionHeader(title: l10n.collBillingBlock(fmt.monthYear(summary.month))),
    ];
    if (nothing) {
      children.add(
        GlassCard(
          dense: true,
          child: Text(
            l10n.collNothingBilled,
            style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
        ),
      );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    final double ratio = t.expected <= 0 ? 0 : t.received / t.expected;
    children.addAll(<Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: StatTile(label: l10n.collExpected, value: fmt.money(t.expected)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              label: l10n.collReceived,
              value: fmt.money(t.received),
              caption: l10n.collPaidStudents(
                fmt.number(t.paidStudents),
                fmt.number(t.totalStudents),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: StatTile(
              label: l10n.collWaived,
              value: fmt.money(t.waivedAmount),
              caption: l10n.collWaivedCaption(fmt.number(t.waivedCount)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              key: const ValueKey<String>('coll-outstanding'),
              behavior: HitTestBehavior.opaque,
              onTap: t.outstanding > 0 ? onSeeDues : null,
              child: StatTile(
                label: l10n.collOutstanding,
                value: fmt.money(t.outstanding),
                footer: t.outstanding > 0
                    ? Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              l10n.collSeeDues,
                              style: tt.labelMedium?.copyWith(
                                color: tokens.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16, color: tokens.accent),
                        ],
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Semantics(
        container: true,
        label: l10n.collProgressLabel(fmt.money(t.received), fmt.money(t.expected)),
        excludeSemantics: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0).toDouble(),
            minHeight: 10,
            backgroundColor: tokens.track,
            color: tokens.accent,
          ),
        ),
      ),
    ]);

    if (summary.batches.isNotEmpty) {
      children.addAll(<Widget>[
        SectionHeader(title: l10n.collByBatch),
        GlassCard(
          dense: true,
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < summary.batches.length; i++)
                _BatchLine(
                  name: summary.batches[i].batchName,
                  totals: summary.batches[i].totals,
                  divider: i > 0,
                ),
              if (summary.batches.length > 1)
                _BatchLine(
                  name: l10n.collAllBatches,
                  totals: t,
                  divider: true,
                  bold: true,
                ),
            ],
          ),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _BatchLine extends StatelessWidget {
  const _BatchLine({
    required this.name,
    required this.totals,
    required this.divider,
    this.bold = false,
  });

  final String name;
  final MonthTotals totals;
  final bool divider;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: tokens.hairline)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: bold ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.collPaidStudents(
                    fmt.number(totals.paidStudents),
                    fmt.number(totals.totalStudents),
                  ),
                  style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              l10n.collBatchSummary(
                fmt.money(totals.expected),
                fmt.money(totals.received),
                fmt.money(totals.outstanding),
              ),
              style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- block 2: cash in --------------------------------------------------------

class CashBlock extends StatelessWidget {
  const CashBlock({super.key, required this.summary});

  final CollectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool nothing = summary.cashTotal == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: l10n.collCashBlock(fmt.monthYear(summary.month))),
        GlassCard(
          dense: true,
          child: nothing
              ? Text(
                  l10n.collLogEmpty,
                  style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.collByMethod,
                      style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    for (final MethodTotal m in summary.byMethod)
                      _KeyValue(
                        label: paymentMethodLabel(l10n, m.method),
                        value: fmt.money(m.amount),
                      ),
                    const Divider(height: 16),
                    _KeyValue(label: l10n.collFeesTotal, value: fmt.money(summary.feesCash)),
                    if (summary.otherIncome > 0)
                      _KeyValue(
                        key: const ValueKey<String>('coll-other-income'),
                        label: l10n.collOtherIncome,
                        value: fmt.money(summary.otherIncome),
                      ),
                    const Divider(height: 16),
                    _KeyValue(
                      label: l10n.collCashTotal,
                      value: fmt.money(summary.cashTotal),
                      bold: true,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({super.key, required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextStyle? style = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: tokens.textPrimary,
          fontWeight: bold ? FontWeight.w700 : null,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: style)),
          const SizedBox(width: 8),
          Text(value, maxLines: 1, style: style),
        ],
      ),
    );
  }
}

// ---- the receipts of the month ----------------------------------------------

class ReceiptLog extends ConsumerWidget {
  const ReceiptLog({super.key, required this.summary});

  final CollectionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final Map<String, Student> students = ref.watch(duesStudentMapProvider);
    final List<ReceiptLine> receipts = summary.receipts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: l10n.collLog),
        if (receipts.isEmpty)
          GlassCard(
            dense: true,
            child: Text(
              l10n.collLogEmpty,
              style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          )
        else
          GlassCard(
            dense: true,
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < receipts.length; i++)
                  _ReceiptRow(
                    key: ValueKey<String>('coll-receipt-${receipts[i].receiptId}'),
                    name: students[receipts[i].studentId]?.name ?? '',
                    line: receipts[i],
                    divider: i > 0,
                    methodLabel: paymentMethodLabel(l10n, receipts[i].method),
                    dateText: fmt.dateShort(receipts[i].paidOn),
                    monthsText: fmt.monthList(receipts[i].months, currentYear: summary.month.year),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    super.key,
    required this.name,
    required this.line,
    required this.divider,
    required this.methodLabel,
    required this.dateText,
    required this.monthsText,
  });

  final String name;
  final ReceiptLine line;
  final bool divider;
  final String methodLabel;
  final String dateText;
  final String monthsText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String sub = <String>[dateText, methodLabel, monthsText]
        .where((String s) => s.isNotEmpty)
        .join(' · ');
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: tokens.hairline)) : null,
      ),
      // Tapping the row opens the receipt (edit / delete), like the student
      // profile's Payment history (QA-14).
      child: InkWell(
        key: ValueKey<String>('coll-receipt-open-${line.receiptId}'),
        onTap: () => showReceipt(context, receiptId: line.receiptId),
        child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (name.isNotEmpty)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(color: tokens.textPrimary),
                      ),
                    Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmt.money(line.amount),
                maxLines: 1,
                style: tt.titleSmall?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: l10n.collShareReceipt,
                icon: const Icon(Icons.share, size: 20),
                onPressed: () => shareReceipt(context, receiptId: line.receiptId),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Month stepping limits shared by the collection screen and the batch tab.
bool canStepBack(YearMonth month, YearMonth? earliest) =>
    earliest != null && month.isAfter(earliest);

bool canStepForward(YearMonth month, YearMonth current) => month.isBefore(current);
