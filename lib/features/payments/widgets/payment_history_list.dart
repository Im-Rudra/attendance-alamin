// A student's payments, newest first: one row per receipt (tap for the receipt
// sheet) and one per waived month (with "মাফ তুলে নিন"). Shrink-wrapped: it sits
// inside the profile's scroll view.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/widgets/receipt_preview.dart';
import 'package:attendance_alamin/features/payments/widgets/waive_dialog.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

/// One line of the history: a receipt (one or more months) or a waived month.
class HistoryEntry {
  const HistoryEntry({required this.rows, required this.waived});

  final List<Payment> rows;
  final bool waived;

  Payment get first => rows.first;
  String get receiptId => first.receiptId;
  LocalDate get paidOn => first.paidOn;
  int get total => rows.fold(0, (int s, Payment p) => s + p.amount);
  List<YearMonth> get months => <YearMonth>[for (final Payment p in rows) p.billingMonth];
}

/// Groups rows (newest first) into receipts; every waiver is its own entry.
List<HistoryEntry> groupHistory(List<Payment> rows) {
  final List<HistoryEntry> out = <HistoryEntry>[];
  final Map<String, List<Payment>> byReceipt = <String, List<Payment>>{};
  for (final Payment p in rows) {
    if (p.waived) {
      out.add(HistoryEntry(rows: <Payment>[p], waived: true));
      continue;
    }
    final List<Payment>? group = byReceipt[p.receiptId];
    if (group == null) {
      final List<Payment> fresh = <Payment>[p];
      byReceipt[p.receiptId] = fresh;
      out.add(HistoryEntry(rows: fresh, waived: false));
    } else {
      group.add(p);
    }
  }
  for (final HistoryEntry e in out) {
    if (!e.waived) e.rows.sort((Payment a, Payment b) => a.billingMonth.compareTo(b.billingMonth));
  }
  return out;
}

const int _kCollapsedCount = 6;

class PaymentHistoryBody extends ConsumerStatefulWidget {
  const PaymentHistoryBody({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<PaymentHistoryBody> createState() => _PaymentHistoryBodyState();
}

class _PaymentHistoryBodyState extends ConsumerState<PaymentHistoryBody> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final AsyncValue<List<Payment>> rowsAsync = ref.watch(payStudentPaymentsProvider(widget.studentId));
    final List<EnrollmentTerms> terms =
        ref.watch(enrollmentTermsProvider).value ?? const <EnrollmentTerms>[];
    if (rowsAsync.hasError) return Text(l10n.commonLoadingFailed);
    final List<Payment>? rows = rowsAsync.value;
    if (rows == null) {
      return const SizedBox(height: 72, child: Center(child: BhorSpinner()));
    }
    final List<HistoryEntry> entries = groupHistory(rows);
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: BhorSpace.s16),
        child: Text(l10n.payHistoryEmpty, style: b.type.body.copyWith(color: b.colors.text2)),
      );
    }
    final Map<String, String> batchOf = <String, String>{
      for (final EnrollmentTerms t in terms)
        if (t.studentId == widget.studentId) t.enrollmentId: t.batchName,
    };
    final bool showBatch = batchOf.length > 1;
    final LocalDate today = ref.watch(todayProvider);
    final List<HistoryEntry> shown =
        _all || entries.length <= _kCollapsedCount ? entries : entries.sublist(0, _kCollapsedCount);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final HistoryEntry e in shown)
          _HistoryTile(
            key: ValueKey<String>('pay-history-${e.first.id}'),
            entry: e,
            today: today,
            batchName: showBatch ? batchOf[e.first.enrollmentId] : null,
          ),
        if (entries.length > _kCollapsedCount)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BhorButton(
              key: const ValueKey<String>('pay-history-toggle'),
              variant: BhorButtonVariant.ghost,
              onPressed: () => setState(() => _all = !_all),
              label: _all ? l10n.payHistoryLess : l10n.payHistoryMore,
            ),
          ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({super.key, required this.entry, required this.today, this.batchName});

  final HistoryEntry entry;
  final LocalDate today;
  final String? batchName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final Payment p = entry.first;

    if (entry.waived) {
      final String month = fmt.monthYear(p.billingMonth);
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: <Widget>[
            Icon(BhorIcons.minus, color: b.colors.text2),
            const SizedBox(width: BhorSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(l10n.payWaivedRow(month), style: b.type.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if ((p.note ?? '').isNotEmpty)
                    Text(p.note!, style: b.type.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            BhorButton(
              key: ValueKey<String>('pay-unwaive-${p.id}'),
              variant: BhorButtonVariant.ghost,
              onPressed: () => runUnwaiveDialog(context, enrollmentId: p.enrollmentId, month: p.billingMonth),
              label: l10n.payUnwaive,
            ),
          ],
        ),
      );
    }

    final String months = fmt.monthList(entry.months, currentYear: today.year);
    final String amount = fmt.money(entry.total);
    final String method = paymentMethodLabel(l10n, p.method);
    final String sub = batchName == null
        ? l10n.payHistorySub(fmt.date(p.paidOn), method)
        : l10n.payHistorySubBatch(fmt.date(p.paidOn), method, batchName!);
    return BhorPressable(
      onTap: () => showReceiptSheet(context, receiptId: entry.receiptId),
      semanticLabel: l10n.payA11yReceipt(months, amount),
      excludeChildSemantics: true,
      radius: BhorRadius.control,
      builder: (BuildContext context, BhorStates s) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: <Widget>[
            Icon(BhorIcons.receipt, color: b.colors.accent),
            const SizedBox(width: BhorSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(months, style: b.type.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(sub, style: b.type.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: BhorSpace.s8),
            Text(amount, style: b.type.bodyStrong),
            Icon(BhorIcons.chevronRight, color: b.colors.text2),
          ],
        ),
      ),
    );
  }
}
