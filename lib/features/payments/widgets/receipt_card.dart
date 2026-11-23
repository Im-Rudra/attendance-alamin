// The receipt as a designed card (F4), the same widget on screen and on the
// printed / saved slip: a header with the centre's name, phone and address and
// a paid stamp, then slip number / student / guardian phone / batch / months /
// method / date rows, the amount and the remaining-balance line. The shared
// message text is separate ([receiptTextFor]); this is what the teacher sees
// and prints.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/receipt_text.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Placeholder of the template that the card shows as an icon.
const String _kCheckMark = '✓';

class ReceiptCard extends StatelessWidget {
  const ReceiptCard({
    super.key,
    required this.model,
    required this.center,
    required this.today,
    this.centerPhone = '',
    this.centerAddress = '',
  });

  final ReceiptModel model;

  /// The centre's name (the batch's place, else the centre settings).
  final String center;
  final String centerPhone;
  final String centerAddress;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final AppLocalizations l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final ReceiptFacts f = model.facts;
    final String coaching = center.trim().isEmpty ? l10n.duesCenterFallback : center.trim();
    final String phone = centerPhone.trim();
    final String address = centerAddress.trim();
    final String roll = (f.roll ?? '').trim();
    final String guardianPhone = (f.guardianPhone ?? '').trim();
    final String slipNo = f.receiptNo;
    final String months = fmt.monthList(f.months, currentYear: today.year, partial: f.partialMonths);
    final bool allPaid = f.remaining <= 0;
    Widget rule() => Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: BhorSpace.s12),
          color: b.colors.line,
        );
    return SizedBox(
      width: double.infinity,
      child: BhorCard(
        key: const ValueKey<String>('pay-receipt-text'),
        padding: const EdgeInsets.all(BhorSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: b.colors.accentTint, shape: BoxShape.circle),
                  child: Icon(BhorIcons.receipt, size: 20, color: b.colors.accent),
                ),
                const SizedBox(width: BhorSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(coaching, key: const ValueKey<String>('pay-receipt-centre'), style: b.type.heading),
                      if (phone.isNotEmpty)
                        Text(fmt.digits(phone), key: const ValueKey<String>('pay-receipt-centre-phone'), style: b.type.meta),
                      if (address.isNotEmpty)
                        Text(address, key: const ValueKey<String>('pay-receipt-centre-address'), style: b.type.meta),
                      Text(l10n.payReceiptTitle, style: b.type.meta),
                    ],
                  ),
                ),
                const SizedBox(width: BhorSpace.s8),
                BhorTag(
                  key: const ValueKey<String>('pay-receipt-stamp'),
                  label: l10n.payReceiptPaidStamp,
                  tone: BhorTone.ok,
                  icon: BhorIcons.checkCircleFill,
                ),
              ],
            ),
            rule(),
            if (slipNo.isNotEmpty)
              _ReceiptLine(
                valueKey: const ValueKey<String>('pay-receipt-no'),
                label: l10n.payReceiptNoLabel,
                value: fmt.digits(slipNo),
              ),
            _ReceiptLine(
              label: l10n.payReceiptStudent,
              value: roll.isEmpty ? f.studentName : '${f.studentName} · ${l10n.duesPickerRoll(fmt.digits(roll))}',
            ),
            if (guardianPhone.isNotEmpty)
              _ReceiptLine(
                valueKey: const ValueKey<String>('pay-receipt-guardian-phone'),
                label: l10n.payGuardianPhone,
                value: fmt.digits(guardianPhone),
              ),
            _ReceiptLine(label: l10n.payBatchLabelShort, value: f.batchName),
            _ReceiptLine(label: l10n.payMonthsLabelShort, value: months),
            _ReceiptLine(label: l10n.payMethodLabel, value: paymentMethodLabel(l10n, model.method)),
            _ReceiptLine(label: l10n.payDateLabel, value: fmt.date(model.paidOn)),
            rule(),
            Row(
              children: <Widget>[
                Expanded(child: Text(l10n.payAmountLabel, style: b.type.bodyStrong)),
                BhorMoney(f.total, style: b.type.title),
              ],
            ),
            const SizedBox(height: BhorSpace.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (allPaid) ...<Widget>[
                  Icon(BhorIcons.check, size: 18, color: b.colors.accent),
                  const SizedBox(width: BhorSpace.s8),
                ],
                Expanded(
                  child: Text(
                    allPaid
                        ? l10n.payReceiptAllPaid.replaceAll(_kCheckMark, '').trim()
                        : l10n.payReceiptRemaining(fmt.money(f.remaining)),
                    key: const ValueKey<String>('pay-receipt-remaining'),
                    style: b.type.body.copyWith(color: b.colors.text2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 104, child: Text(label, style: b.type.meta)),
          Expanded(child: Text(value, key: valueKey, textAlign: TextAlign.end, style: b.type.bodyStrong)),
        ],
      ),
    );
  }
}
