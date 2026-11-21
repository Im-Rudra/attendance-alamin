// Archive dialog (asks the last billable month, scenario 9) and unarchive
// dialog (clash list + gap-waive prompt, scenario 21).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';

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
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final List<YearMonth> choices = <YearMonth>[
      for (int i = -5; i <= 0; i++) widget.thisMonth.addMonths(i),
    ];
    return BhorDialog(
      title: l10n.batchArchiveTitle(widget.batchName),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.batchArchiveBody, style: b.type.body),
            const SizedBox(height: BhorSpace.s16),
            Text(l10n.batchArchiveLbmLabel, style: b.type.bodyStrong),
            const SizedBox(height: BhorSpace.s8),
            Wrap(
              spacing: BhorSpace.s8,
              runSpacing: BhorSpace.s8,
              children: <Widget>[
                for (final YearMonth m in choices)
                  BhorChip(
                    label: fmt.monthYear(m),
                    selected: m == _month,
                    onSelected: (_) => setState(() => _month = m),
                  ),
              ],
            ),
            const SizedBox(height: BhorSpace.s12),
            Text(
              l10n.batchArchiveLbmHelp(fmt.monthYear(_month)),
              style: b.type.body.copyWith(color: b.colors.text2),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        BhorButton(
          label: l10n.commonCancel,
          variant: BhorButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BhorButton(
          label: l10n.batchArchiveConfirm,
          onPressed: () => Navigator.of(context).pop(_month),
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
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final bool clash = widget.clashLines.isNotEmpty;
    return BhorDialog(
      title: l10n.batchUnarchiveTitle(widget.batchName),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.batchUnarchiveBody, style: b.type.body),
            if (clash) ...<Widget>[
              const SizedBox(height: BhorSpace.s12),
              BatchNotice(
                text: l10n.batchUnarchiveClash,
                icon: BhorIcons.warning,
                children: <Widget>[
                  const SizedBox(height: BhorSpace.s8),
                  for (final String line in widget.clashLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BhorSpace.s4),
                      child: Text(line, style: b.type.body.copyWith(color: b.colors.danger)),
                    ),
                  const SizedBox(height: BhorSpace.s4),
                  Text(
                    l10n.batchUnarchiveClashHint,
                    style: b.type.label.copyWith(color: b.colors.danger),
                  ),
                ],
              ),
            ],
            if (widget.gapMonths > 0) ...<Widget>[
              const SizedBox(height: BhorSpace.s12),
              BhorListRow(
                title: l10n.batchGapTitle(fmt.number(widget.gapMonths)),
                subtitle: l10n.batchGapHint,
                divider: false,
                onTap: () => setState(() => _waive = !_waive),
                trailing: BhorSwitch(
                  value: _waive,
                  semanticLabel: l10n.batchGapTitle(fmt.number(widget.gapMonths)),
                  onChanged: (bool v) => setState(() => _waive = v),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        BhorButton(
          label: l10n.commonCancel,
          variant: BhorButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        BhorButton(
          label: clash ? l10n.batchUnarchiveFix : l10n.batchUnarchiveConfirm,
          onPressed: () => Navigator.of(context).pop<UnarchiveChoice>(
            (waiveGap: widget.gapMonths > 0 && _waive, acceptClashes: clash),
          ),
        ),
      ],
    );
  }
}
