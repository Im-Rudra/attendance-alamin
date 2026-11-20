// Archive dialog (asks the last billable month, scenario 9) and unarchive
// dialog (clash list + gap-waive prompt, scenario 21).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/core/time/year_month.dart';

/// Pops the chosen last billable month, or null.
class ArchiveBatchDialog extends StatefulWidget {
  const ArchiveBatchDialog({
    super.key,
    required this.batchName,
    required this.initial,
    required this.thisMonth,
  });

  final String batchName;

  /// Product 3.2 default: this month when the day is 11 or later, else last.
  final YearMonth initial;
  final YearMonth thisMonth;

  @override
  State<ArchiveBatchDialog> createState() => _ArchiveBatchDialogState();
}

class _ArchiveBatchDialogState extends State<ArchiveBatchDialog> {
  late YearMonth _month = widget.initial;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final List<YearMonth> choices = <YearMonth>[
      for (int i = -5; i <= 0; i++) widget.thisMonth.addMonths(i),
    ];
    return AlertDialog(
      title: Text(l10n.batchArchiveTitle(widget.batchName)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.batchArchiveBody, style: tt.bodyLarge?.copyWith(color: tokens.textPrimary)),
            const SizedBox(height: 16),
            Text(l10n.batchArchiveLbmLabel, style: tt.titleSmall?.copyWith(color: tokens.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final YearMonth m in choices)
                  ChoiceChip(
                    label: Text(fmt.monthYear(m)),
                    selected: m == _month,
                    onSelected: (_) => setState(() => _month = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.batchArchiveLbmHelp(fmt.monthYear(_month)),
              style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_month),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.batchArchiveConfirm),
        ),
      ],
    );
  }
}

/// What the teacher chose in the unarchive dialog.
typedef UnarchiveChoice = ({bool waiveGap, bool acceptClashes});

class UnarchiveBatchDialog extends StatefulWidget {
  const UnarchiveBatchDialog({
    super.key,
    required this.batchName,
    required this.clashLines,
    required this.gapMonths,
  });

  final String batchName;

  /// "রসায়ন · কেমিস্ট্রি বি · প্রতি রবিবার · সকাল ১০:০০–১১:০০"; empty = no clash.
  final List<String> clashLines;
  final int gapMonths;

  @override
  State<UnarchiveBatchDialog> createState() => _UnarchiveBatchDialogState();
}

class _UnarchiveBatchDialogState extends State<UnarchiveBatchDialog> {
  bool _waive = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool clash = widget.clashLines.isNotEmpty;
    return AlertDialog(
      title: Text(l10n.batchUnarchiveTitle(widget.batchName)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.batchUnarchiveBody, style: tt.bodyLarge?.copyWith(color: tokens.textPrimary)),
            if (clash) ...<Widget>[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.errorContainer,
                  borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
                  border: Border.all(color: tokens.errorContainerBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.warning_amber_rounded, color: tokens.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.batchUnarchiveClash,
                              style: tt.titleSmall?.copyWith(color: tokens.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final String line in widget.clashLines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(line, style: tt.bodyMedium?.copyWith(color: tokens.onErrorContainer)),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.batchUnarchiveClashHint,
                        style: tt.labelMedium?.copyWith(color: tokens.onErrorContainer),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.gapMonths > 0) ...<Widget>[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _waive,
                onChanged: (bool v) => setState(() => _waive = v),
                title: Text(l10n.batchGapTitle(fmt.number(widget.gapMonths))),
                subtitle: Text(l10n.batchGapHint),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop<UnarchiveChoice>(
            (waiveGap: widget.gapMonths > 0 && _waive, acceptClashes: clash),
          ),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(clash ? l10n.batchUnarchiveFix : l10n.batchUnarchiveConfirm),
        ),
      ],
    );
  }
}
