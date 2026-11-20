// "বেতন কখন দেয়?": two big radio cards in plain words with a worked month
// example (UX trap 3: never the words prepaid / postpaid).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
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
        _BillingCard(
          title: l10n.batchBillingPrepaid,
          example: l10n.batchBillingPrepaidExample,
          selected: value == BillingType.prepaid,
          onTap: () => onChanged(BillingType.prepaid),
        ),
        const SizedBox(height: 8),
        _BillingCard(
          title: l10n.batchBillingPostpaid,
          example: l10n.batchBillingPostpaidExample,
          selected: value == BillingType.postpaid,
          onTap: () => onChanged(BillingType.postpaid),
        ),
      ],
    );
  }
}

class _BillingCard extends StatelessWidget {
  const _BillingCard({
    required this.title,
    required this.example,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String example;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusDenseList);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$title. $example',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? tokens.accentContainer : tokens.surfaceDense,
        shape: RoundedRectangleBorder(
          borderRadius: br,
          side: BorderSide(
            color: selected ? tokens.accent : tokens.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: br),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? tokens.onAccentContainer : tokens.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: tt.titleMedium?.copyWith(
                            color: selected ? tokens.onAccentContainer : tokens.textPrimary,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          example,
                          style: tt.bodyMedium?.copyWith(
                            color: selected ? tokens.onAccentContainer : tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
