// "বেতন কখন দেয়?": two big radio cards in plain words with a worked month
// example (UX trap 3: never the words prepaid / postpaid).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

class BillingCards extends StatelessWidget {
  const BillingCards({super.key, required this.value, required this.onChanged});

  final BillingType value;
  final ValueChanged<BillingType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorRadioCard<BillingType>(
          value: BillingType.prepaid,
          groupValue: value,
          onChanged: onChanged,
          title: l10n.batchBillingPrepaid,
          subtitle: l10n.batchBillingPrepaidExample,
        ),
        const SizedBox(height: BhorSpace.s8),
        BhorRadioCard<BillingType>(
          value: BillingType.postpaid,
          groupValue: value,
          onChanged: onChanged,
          title: l10n.batchBillingPostpaid,
          subtitle: l10n.batchBillingPostpaidExample,
        ),
      ],
    );
  }
}
