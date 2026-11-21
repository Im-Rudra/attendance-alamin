// The blocks of the monthly collection summary (Product 3.7):
// 1. the billing month: expected / received / waived / outstanding, per batch;
// 2. cash in during the calendar month: by method, other income, total, and
//    the receipts behind it.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

// ---- small pieces -------------------------------------------------------------

/// A stat card: the amount big over its label, with an optional caption and
/// footer line. Tappable when [onTap] is set.
class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.label,
    required this.amount,
    this.caption,
    this.footer,
    this.onTap,
  });

  final String label;
  final int amount;
  final String? caption;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return BhorCard(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.all(BhorSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: BhorMoney(amount, style: b.type.stat),
          ),
          if (caption != null) Text(caption!, maxLines: 2, overflow: TextOverflow.ellipsis, style: b.type.meta),
          if (footer != null) ...<Widget>[const SizedBox(height: BhorSpace.s4), footer!],
        ],
      ),
    );
  }
}

/// One hairline.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: BhorSpace.s8),
        color: context.bhor.colors.line,
      );
}

// ---- block 1: the billing month ---------------------------------------------

class BillingBlock extends ConsumerWidget {
  const BillingBlock({super.key, required this.summary, required this.onSeeDues});

  final CollectionSummary summary;

  /// Outstanding tile tapped: open the dues list filtered to this month.
  final VoidCallback onSeeDues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final MonthTotals t = summary.totals;
    final BillingStatus? status = ref.watch(billingStatusProvider).value;
    final bool nothing = t.expected == 0 && t.waivedCount == 0;

    final List<Widget> children = <Widget>[
      BhorSectionHeader(title: l10n.collBillingBlock(fmt.monthYear(summary.month))),
    ];
    if (nothing) {
      children.add(
        BhorCard(
          child: status != null && status.notStarted
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.duesNotStarted(fmt.monthYear(status.firstUpcoming!)),
                      key: const ValueKey<String>('coll-not-started'),
                      style: b.type.body,
                    ),
                    const SizedBox(height: BhorSpace.s8),
                    BhorButton(
                      label: l10n.duesSeeStudents,
                      variant: BhorButtonVariant.ghost,
                      onPressed: () => GoRouter.maybeOf(context)?.go(Routes.students),
                    ),
                  ],
                )
              : Text(l10n.collNothingBilled, style: b.type.body.copyWith(color: b.colors.text2)),
        ),
      );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    final double ratio = t.expected <= 0 ? 0 : t.received / t.expected;
    children.addAll(<Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _StatCard(label: l10n.collExpected, amount: t.expected)),
          const SizedBox(width: BhorSpace.s12),
          Expanded(
            child: _StatCard(
              label: l10n.collReceived,
              amount: t.received,
              caption: l10n.collPaidStudents(
                fmt.number(t.paidStudents),
                fmt.number(t.totalStudents),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: BhorSpace.s12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _StatCard(
              label: l10n.collWaived,
              amount: t.waivedAmount,
              caption: l10n.collWaivedCaption(fmt.number(t.waivedCount)),
            ),
          ),
          const SizedBox(width: BhorSpace.s12),
          Expanded(
            child: _StatCard(
              key: const ValueKey<String>('coll-outstanding'),
              label: l10n.collOutstanding,
              amount: t.outstanding,
              onTap: t.outstanding > 0 ? onSeeDues : null,
              footer: t.outstanding > 0
                  ? Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            l10n.collSeeDues,
                            style: b.type.label.copyWith(color: b.colors.accent),
                          ),
                        ),
                        const SizedBox(width: BhorSpace.s4),
                        Icon(Icons.arrow_forward, size: 16, color: b.colors.accent),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
      const SizedBox(height: BhorSpace.s12),
      BhorProgress(
        value: ratio.clamp(0.0, 1.0).toDouble(),
        height: 10,
        semanticLabel: l10n.collProgressLabel(fmt.money(t.received), fmt.money(t.expected)),
      ),
    ]);

    if (summary.batches.isNotEmpty) {
      children.addAll(<Widget>[
        BhorSectionHeader(title: l10n.collByBatch),
        BhorCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < summary.batches.length; i++)
                _BatchLine(
                  name: summary.batches[i].batchName,
                  totals: summary.batches[i].totals,
                  divider: i < summary.batches.length - 1 || summary.batches.length > 1,
                ),
              if (summary.batches.length > 1)
                _BatchLine(
                  name: l10n.collAllBatches,
                  totals: t,
                  divider: false,
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
    final BhorThemeData b = context.bhor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s12),
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: b.colors.line)) : null,
      ),
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
                  style: bold ? b.type.heading : b.type.bodyStrong,
                ),
              ),
              const SizedBox(width: BhorSpace.s8),
              Text(
                l10n.collPaidStudents(
                  fmt.number(totals.paidStudents),
                  fmt.number(totals.totalStudents),
                ),
                style: b.type.meta,
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
            style: b.type.meta,
          ),
        ],
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
    final BhorThemeData b = context.bhor;
    final bool nothing = summary.cashTotal == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorSectionHeader(title: l10n.collCashBlock(fmt.monthYear(summary.month))),
        BhorCard(
          child: nothing
              ? Text(l10n.collLogEmpty, style: b.type.body.copyWith(color: b.colors.text2))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(l10n.collByMethod, style: b.type.meta),
                    const SizedBox(height: BhorSpace.s4),
                    for (final MethodTotal m in summary.byMethod)
                      _KeyValue(
                        label: paymentMethodLabel(l10n, m.method),
                        amount: m.amount,
                      ),
                    const _Rule(),
                    _KeyValue(label: l10n.collFeesTotal, amount: summary.feesCash),
                    if (summary.otherIncome > 0)
                      _KeyValue(
                        key: const ValueKey<String>('coll-other-income'),
                        label: l10n.collOtherIncome,
                        amount: summary.otherIncome,
                      ),
                    const _Rule(),
                    _KeyValue(
                      label: l10n.collCashTotal,
                      amount: summary.cashTotal,
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
  const _KeyValue({super.key, required this.label, required this.amount, this.bold = false});

  final String label;
  final int amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final TextStyle style = bold ? b.type.heading : b.type.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: style)),
          const SizedBox(width: BhorSpace.s8),
          BhorMoney(amount, style: style),
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
    final BhorThemeData b = context.bhor;
    final Map<String, Student> students = ref.watch(duesStudentMapProvider);
    final List<ReceiptLine> receipts = summary.receipts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorSectionHeader(title: l10n.collLog),
        if (receipts.isEmpty)
          BhorCard(
            child: Text(l10n.collLogEmpty, style: b.type.body.copyWith(color: b.colors.text2)),
          )
        else
          BhorCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < receipts.length; i++)
                  _ReceiptRow(
                    key: ValueKey<String>('coll-receipt-${receipts[i].receiptId}'),
                    name: students[receipts[i].studentId]?.name ?? '',
                    line: receipts[i],
                    divider: i < receipts.length - 1,
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
    final BhorThemeData b = context.bhor;
    final String sub = <String>[dateText, methodLabel, monthsText]
        .where((String s) => s.isNotEmpty)
        .join(' · ');
    // Tapping the row opens the receipt (edit / delete), like the student
    // profile's Payment history (QA-14).
    return BhorListRow(
      key: ValueKey<String>('coll-receipt-open-${line.receiptId}'),
      title: name.isNotEmpty ? name : sub,
      subtitle: name.isNotEmpty ? sub : null,
      divider: divider,
      onTap: () => showReceipt(context, receiptId: line.receiptId),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BhorMoney(line.amount, style: b.type.bodyStrong),
          BhorIconButton(
            icon: Icons.share,
            semanticLabel: l10n.collShareReceipt,
            onPressed: () => shareReceipt(context, receiptId: line.receiptId),
          ),
        ],
      ),
    );
  }
}

/// Month stepping limits shared by the collection screen and the batch tab.
bool canStepBack(YearMonth month, YearMonth? earliest) =>
    earliest != null && month.isAfter(earliest);

bool canStepForward(YearMonth month, YearMonth current) => month.isBefore(current);
