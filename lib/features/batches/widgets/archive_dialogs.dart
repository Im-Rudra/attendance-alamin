// Finish-batch panel (asks the finish day and the last billable month,
// scenario 9) and reopen panel (restart day, clash list, gap-waive prompt,
// scenario 21). Both are BhorPanelKind.confirm containers (a centred dialog on
// desktop, a sheet on phones); the buttons are the container's footer.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';

Widget _footer(BuildContext context, {required String confirmLabel, required VoidCallback onConfirm}) {
  // A Wrap: the long "reopen and fix the schedule" label drops to its own line
  // in a narrow dialog instead of overflowing.
  return Wrap(
    alignment: WrapAlignment.end,
    spacing: BhorSpace.s8,
    runSpacing: BhorSpace.s8,
    children: <Widget>[
      BhorButton(
        label: context.l10n.commonCancel,
        variant: BhorButtonVariant.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      BhorButton(label: confirmLabel, onPressed: onConfirm),
    ],
  );
}

DateTime _dt(LocalDate d) => DateTime(d.year, d.month, d.day);

/// A calendar-icon field that opens the date picker anchored under it.
class BatchDateField extends StatelessWidget {
  const BatchDateField({
    super.key,
    required this.label,
    required this.date,
    required this.first,
    required this.last,
    required this.weekStart,
    required this.onChanged,
  });

  final String label;
  final LocalDate date;
  final LocalDate first;
  final LocalDate last;
  final int weekStart;
  final ValueChanged<LocalDate> onChanged;

  Future<void> _open(BuildContext anchor) async {
    final DateTime? picked = await showBhorDatePicker(
      anchor,
      anchor: anchor,
      initialDate: _dt(date),
      firstDate: _dt(first),
      lastDate: _dt(last),
      weekStart: weekStart,
      today: _dt(last),
    );
    if (picked == null) return;
    onChanged(LocalDate(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    return BhorPickerField(
      label: label,
      value: context.fmt.date(date),
      icon: BhorIcons.calendar,
      onTap: _open,
    );
  }
}

/// What the teacher chose in the finish-batch panel.
typedef FinishChoice = ({YearMonth lastBillableMonth, LocalDate on});

/// State of the finish panel: the "finished on" day and the last billable
/// month. Until the teacher picks a month by hand, the month follows the day
/// (the 11th rule of [DuesEngine.defaultLastBillableMonth]).
class FinishState extends ChangeNotifier {
  FinishState({required this.on, required this.month});

  LocalDate on;
  YearMonth month;
  bool _monthTouched = false;

  void setDate(LocalDate d) {
    on = d;
    if (!_monthTouched) month = DuesEngine.defaultLastBillableMonth(d);
    notifyListeners();
  }

  void setMonth(YearMonth m) {
    month = m;
    _monthTouched = true;
    notifyListeners();
  }
}

/// Asks the finish day and the last billable month; null when cancelled.
Future<FinishChoice?> showArchiveBatchPanel(
  BuildContext context, {
  required String batchName,
  required LocalDate today,

  /// The earliest day the batch can be finished on.
  required LocalDate earliest,
  required int weekStart,
}) {
  final FinishState state = FinishState(
    on: today,
    month: DuesEngine.defaultLastBillableMonth(today),
  );
  return showBhorPanel<FinishChoice>(
    context,
    kind: BhorPanelKind.confirm,
    title: context.l10n.batchArchiveTitle(batchName),
    builder: (BuildContext ctx) => ArchiveBatchBody(
      state: state,
      today: today,
      earliest: earliest,
      weekStart: weekStart,
    ),
    footer: (BuildContext ctx) => _footer(
      ctx,
      confirmLabel: ctx.l10n.batchArchiveConfirm,
      onConfirm: () => Navigator.of(ctx).pop<FinishChoice>(
        (lastBillableMonth: state.month, on: state.on),
      ),
    ),
  );
}

class ArchiveBatchBody extends StatelessWidget {
  const ArchiveBatchBody({
    super.key,
    required this.state,
    required this.today,
    required this.earliest,
    required this.weekStart,
  });

  final FinishState state;
  final LocalDate today;
  final LocalDate earliest;
  final int weekStart;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) {
        final YearMonth selected = state.month;
        final YearMonth thisMonth = today.yearMonth;
        YearMonth from = thisMonth.addMonths(-5);
        if (selected.isBefore(from)) from = selected;
        final List<YearMonth> choices = <YearMonth>[
          for (YearMonth m = from; !m.isAfter(thisMonth); m = m.addMonths(1)) m,
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.batchArchiveBody, style: b.type.body),
            const SizedBox(height: BhorSpace.s16),
            BatchDateField(
              label: l10n.batchFinishedOnLabel,
              date: state.on,
              first: earliest,
              last: today,
              weekStart: weekStart,
              onChanged: state.setDate,
            ),
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
                    onSelected: (_) => state.setMonth(m),
                  ),
              ],
            ),
            const SizedBox(height: BhorSpace.s12),
            Text(
              l10n.batchArchiveLbmHelp(fmt.monthYear(selected)),
              style: b.type.body.copyWith(color: b.colors.text2),
            ),
          ],
        );
      },
    );
  }
}

/// What the teacher chose in the reopen panel.
typedef UnarchiveChoice = ({bool waiveGap, bool acceptClashes, LocalDate on});

/// Asks to reopen a batch; the choice, or null when cancelled.
Future<UnarchiveChoice?> showUnarchiveBatchPanel(
  BuildContext context, {
  required String batchName,

  /// "রসায়ন · কেমিস্ট্রি বি · প্রতি রবিবার · সকাল ১০:০০–১১:০০"; empty = no clash.
  required List<String> clashLines,

  /// Gap months (closed months to skip or bill) if classes restart on a day.
  required int Function(LocalDate on) gapFor,
  required LocalDate today,

  /// The earliest day classes can restart: the day after it was finished.
  required LocalDate earliest,
  required int weekStart,
}) {
  final ValueNotifier<bool> waive = ValueNotifier<bool>(true);
  final ValueNotifier<LocalDate> on = ValueNotifier<LocalDate>(today);
  final bool clash = clashLines.isNotEmpty;
  return showBhorPanel<UnarchiveChoice>(
    context,
    kind: BhorPanelKind.confirm,
    title: context.l10n.batchUnarchiveTitle(batchName),
    builder: (BuildContext ctx) => UnarchiveBatchBody(
      clashLines: clashLines,
      gapFor: gapFor,
      waive: waive,
      on: on,
      today: today,
      earliest: earliest,
      weekStart: weekStart,
    ),
    footer: (BuildContext ctx) => _footer(
      ctx,
      confirmLabel: clash ? ctx.l10n.batchUnarchiveFix : ctx.l10n.batchUnarchiveConfirm,
      onConfirm: () => Navigator.of(ctx).pop<UnarchiveChoice>(
        (waiveGap: gapFor(on.value) > 0 && waive.value, acceptClashes: clash, on: on.value),
      ),
    ),
  );
}

class UnarchiveBatchBody extends StatelessWidget {
  const UnarchiveBatchBody({
    super.key,
    required this.clashLines,
    required this.gapFor,
    required this.waive,
    required this.on,
    required this.today,
    required this.earliest,
    required this.weekStart,
  });

  final List<String> clashLines;
  final int Function(LocalDate on) gapFor;
  final ValueNotifier<bool> waive;
  final ValueNotifier<LocalDate> on;
  final LocalDate today;
  final LocalDate earliest;
  final int weekStart;

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
        const SizedBox(height: BhorSpace.s16),
        ValueListenableBuilder<LocalDate>(
          valueListenable: on,
          builder: (BuildContext context, LocalDate d, Widget? _) => BatchDateField(
            label: l10n.batchReopenOnLabel,
            date: d,
            first: earliest,
            last: today,
            weekStart: weekStart,
            onChanged: (LocalDate v) => on.value = v,
          ),
        ),
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
        ValueListenableBuilder<LocalDate>(
          valueListenable: on,
          builder: (BuildContext context, LocalDate d, Widget? _) {
            final int gapMonths = gapFor(d);
            if (gapMonths <= 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: BhorSpace.s12),
              child: ValueListenableBuilder<bool>(
                valueListenable: waive,
                builder: (BuildContext context, bool isOn, Widget? _) => BhorListRow(
                  title: l10n.gapTitleText(gapMonths, fmt.number(gapMonths)),
                  subtitle: l10n.batchGapHint,
                  divider: false,
                  onTap: () => waive.value = !isOn,
                  trailing: BhorSwitch(
                    value: isOn,
                    semanticLabel: l10n.gapTitleText(gapMonths, fmt.number(gapMonths)),
                    onChanged: (bool v) => waive.value = v,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
