// Archive panel (asks the last billable month, scenario 9) and unarchive panel
// (clash list + gap-waive prompt, scenario 21). Both are BhorPanelKind.confirm
// containers (a centred dialog on desktop, a sheet on phones); the buttons are
// the container's footer.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';

Widget _footer(BuildContext context, {required String confirmLabel, required VoidCallback onConfirm}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: <Widget>[
      BhorButton(
        label: context.l10n.commonCancel,
        variant: BhorButtonVariant.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      const SizedBox(width: BhorSpace.s8),
      BhorButton(label: confirmLabel, onPressed: onConfirm),
    ],
  );
}

/// Asks the last billable month; the chosen month, or null when cancelled.
Future<YearMonth?> showArchiveBatchPanel(
  BuildContext context, {
  required String batchName,

  /// Product 3.2 default: this month when the day is 11 or later, else last.
  required YearMonth initial,
  required YearMonth thisMonth,
}) {
  final ValueNotifier<YearMonth> month = ValueNotifier<YearMonth>(initial);
  return showBhorPanel<YearMonth>(
    context,
    kind: BhorPanelKind.confirm,
    title: context.l10n.batchArchiveTitle(batchName),
    builder: (BuildContext ctx) => ArchiveBatchBody(month: month, thisMonth: thisMonth),
    footer: (BuildContext ctx) => _footer(
      ctx,
      confirmLabel: ctx.l10n.batchArchiveConfirm,
      onConfirm: () => Navigator.of(ctx).pop(month.value),
    ),
  );
}

class ArchiveBatchBody extends StatelessWidget {
  const ArchiveBatchBody({super.key, required this.month, required this.thisMonth});

  final ValueNotifier<YearMonth> month;
  final YearMonth thisMonth;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final List<YearMonth> choices = <YearMonth>[
      for (int i = -5; i <= 0; i++) thisMonth.addMonths(i),
    ];
    return ValueListenableBuilder<YearMonth>(
      valueListenable: month,
      builder: (BuildContext context, YearMonth selected, Widget? _) => Column(
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
                  selected: m == selected,
                  onSelected: (_) => month.value = m,
                ),
            ],
          ),
          const SizedBox(height: BhorSpace.s12),
          Text(
            l10n.batchArchiveLbmHelp(fmt.monthYear(selected)),
            style: b.type.body.copyWith(color: b.colors.text2),
          ),
        ],
      ),
    );
  }
}

/// What the teacher chose in the unarchive panel.
typedef UnarchiveChoice = ({bool waiveGap, bool acceptClashes});

/// Asks to restore a batch; the choice, or null when cancelled.
Future<UnarchiveChoice?> showUnarchiveBatchPanel(
  BuildContext context, {
  required String batchName,

  /// "রসায়ন · কেমিস্ট্রি বি · প্রতি রবিবার · সকাল ১০:০০–১১:০০"; empty = no clash.
  required List<String> clashLines,
  required int gapMonths,
}) {
  final ValueNotifier<bool> waive = ValueNotifier<bool>(true);
  final bool clash = clashLines.isNotEmpty;
  return showBhorPanel<UnarchiveChoice>(
    context,
    kind: BhorPanelKind.confirm,
    title: context.l10n.batchUnarchiveTitle(batchName),
    builder: (BuildContext ctx) => UnarchiveBatchBody(clashLines: clashLines, gapMonths: gapMonths, waive: waive),
    footer: (BuildContext ctx) => _footer(
      ctx,
      confirmLabel: clash ? ctx.l10n.batchUnarchiveFix : ctx.l10n.batchUnarchiveConfirm,
      onConfirm: () => Navigator.of(ctx).pop<UnarchiveChoice>(
        (waiveGap: gapMonths > 0 && waive.value, acceptClashes: clash),
      ),
    ),
  );
}

class UnarchiveBatchBody extends StatelessWidget {
  const UnarchiveBatchBody({
    super.key,
    required this.clashLines,
    required this.gapMonths,
    required this.waive,
  });

  final List<String> clashLines;
  final int gapMonths;
  final ValueNotifier<bool> waive;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final bool clash = clashLines.isNotEmpty;
    return Column(
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
              for (final String line in clashLines)
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
        if (gapMonths > 0) ...<Widget>[
          const SizedBox(height: BhorSpace.s12),
          ValueListenableBuilder<bool>(
            valueListenable: waive,
            builder: (BuildContext context, bool on, Widget? _) => BhorListRow(
              title: l10n.gapTitleText(gapMonths, fmt.number(gapMonths)),
              subtitle: l10n.batchGapHint,
              divider: false,
              onTap: () => waive.value = !on,
              trailing: BhorSwitch(
                value: on,
                semanticLabel: l10n.gapTitleText(gapMonths, fmt.number(gapMonths)),
                onChanged: (bool v) => waive.value = v,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
