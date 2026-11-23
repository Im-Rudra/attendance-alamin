// The "More months…" month grid of the collect form (teacher feedback item 7):
// 12 months of one year (‹ year ›), each with its state (Paid · Due · Partial
// · Not due yet · Advance), tapped to tick or untick it. A picker popover
// anchored to the chip on desktop, a bottom sheet on phones. Ticks go straight
// to the form's controller, so the form behind updates live.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/payments/controllers/collect_payment_controller.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// What a month is, as the grid and the chips show it.
enum PayMonthStatus {
  /// Paid in full (its due date has come).
  paid,

  /// Paid in full before its due date.
  advance,

  /// Due, nothing paid.
  due,

  /// Partly paid.
  partial,

  /// Owes money but its due date has not come yet.
  notDue,
  waived,
  free,

  /// Not billed (before the enrollment, after it ended, beyond 12 months).
  none,
}

/// The status of [md] (null = the month is not billed).
PayMonthStatus payMonthStatus(MonthDue? md) {
  if (md == null) return PayMonthStatus.none;
  return switch (md.state) {
    MonthState.waived => PayMonthStatus.waived,
    MonthState.free => PayMonthStatus.free,
    MonthState.paid => md.isDue ? PayMonthStatus.paid : PayMonthStatus.advance,
    MonthState.partial => PayMonthStatus.partial,
    MonthState.unpaid => md.isDue ? PayMonthStatus.due : PayMonthStatus.notDue,
  };
}

/// The word for [s] in the grid.
String payMonthStatusText(AppLocalizations l10n, PayMonthStatus s) => switch (s) {
      PayMonthStatus.paid => l10n.payGridPaid,
      PayMonthStatus.advance => l10n.payGridAdvance,
      PayMonthStatus.due => l10n.payGridDue,
      PayMonthStatus.partial => l10n.payGridPartial,
      PayMonthStatus.notDue => l10n.payGridNotDue,
      PayMonthStatus.waived => l10n.payGridWaived,
      PayMonthStatus.free => l10n.payGridFree,
      PayMonthStatus.none => l10n.payGridNone,
    };

/// Opens the month grid for the form of [args] on [enrollmentId], anchored
/// to [anchor] (the "More months…" chip).
Future<void> showPayMonthGrid(
  BuildContext context, {
  required BuildContext anchor,
  required PayArgs args,
  required String enrollmentId,
}) {
  return showBhorPanel<void>(
    context,
    kind: BhorPanelKind.picker,
    anchor: anchor,
    title: context.l10n.payGridTitle,
    width: 360,
    builder: (BuildContext c) => PayMonthGrid(
      args: args,
      enrollmentId: enrollmentId,
      onDone: () => Navigator.of(c).pop(),
    ),
  );
}

/// The grid itself (also usable inline). Reads and writes the collect form's
/// controller of [args].
class PayMonthGrid extends ConsumerStatefulWidget {
  const PayMonthGrid({super.key, required this.args, required this.enrollmentId, this.onDone});

  final PayArgs args;
  final String enrollmentId;

  /// The Done button; hidden when null.
  final VoidCallback? onDone;

  @override
  ConsumerState<PayMonthGrid> createState() => _PayMonthGridState();
}

class _PayMonthGridState extends ConsumerState<PayMonthGrid> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final CollectInput input = ref.watch(collectPaymentControllerProvider(widget.args));
    final LocalDate today = ref.watch(todayProvider);
    final EnrollmentDues? dues = ref
        .watch(payDuesProvider((enrollmentId: widget.enrollmentId, receiptId: widget.args.receiptId)))
        .value;
    if (dues == null) {
      return const SizedBox(height: 160, child: Center(child: BhorSpinner()));
    }
    final CollectPlan plan = buildPlan(
      dues: dues,
      today: today,
      amount: input.amount,
      split: input.split,
      selected: input.selected,
    );
    final Set<YearMonth> ticked = input.selected ?? plan.months.toSet();
    final Map<YearMonth, MonthDue> byMonth = <YearMonth, MonthDue>{
      for (final MonthDue md in dues.months) md.month: md,
    };

    final int minYear = dues.months.isEmpty ? today.year : dues.months.first.month.year;
    int maxYear = dues.months.isEmpty ? today.year : dues.months.last.month.year;
    if (maxYear < today.year) maxYear = today.year;
    int initialYear() {
      final List<YearMonth> sorted = ticked.toList()..sort();
      if (sorted.isNotEmpty) return sorted.first.year;
      if (plan.openMonths.isNotEmpty) return plan.openMonths.first.month.year;
      return today.year;
    }

    int year = _year ?? initialYear();
    if (year < minYear) year = minYear;
    if (year > maxYear) year = maxYear;
    final notifier = ref.read(collectPaymentControllerProvider(widget.args).notifier);

    Widget cell(int month) {
      final YearMonth ym = YearMonth(year, month);
      final MonthDue? md = byMonth[ym];
      final PayMonthStatus status = payMonthStatus(md);
      final bool selectable = md != null && monthSelectable(md, today);
      return _GridCell(
        key: ValueKey<String>('pay-grid-${ym.toInt()}'),
        month: fmt.monthName(month),
        status: payMonthStatusText(l10n, status),
        semanticLabel: l10n.payGridCellA11y(fmt.monthYear(ym), payMonthStatusText(l10n, status)),
        settled: status == PayMonthStatus.paid || status == PayMonthStatus.advance,
        selected: selectable && ticked.contains(ym),
        onTap: selectable ? () => notifier.toggleMonth(ym) : null,
      );
    }

    const double gap = BhorSpace.s4;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            BhorIconButton(
              key: const ValueKey<String>('pay-grid-prev'),
              icon: BhorIcons.chevronLeft,
              semanticLabel: l10n.payGridPrevYear,
              onPressed: year > minYear ? () => setState(() => _year = year - 1) : null,
            ),
            Expanded(
              child: Text(
                fmt.digits(year.toString()),
                key: const ValueKey<String>('pay-grid-year'),
                textAlign: TextAlign.center,
                style: BhorType.tabular(b.type.bodyStrong),
              ),
            ),
            BhorIconButton(
              key: const ValueKey<String>('pay-grid-next'),
              icon: BhorIcons.chevronRight,
              semanticLabel: l10n.payGridNextYear,
              onPressed: year < maxYear ? () => setState(() => _year = year + 1) : null,
            ),
          ],
        ),
        const SizedBox(height: BhorSpace.s8),
        for (int row = 0; row < 4; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int col = 0; col < 3; col++) ...<Widget>[
                if (col > 0) const SizedBox(width: gap),
                Expanded(child: cell(row * 3 + col + 1)),
              ],
            ],
          ),
        ],
        const SizedBox(height: BhorSpace.s12),
        Semantics(
          liveRegion: true,
          child: Text(
            plan.ok
                ? l10n.payGridTotal(fmt.digits(plan.months.length.toString()), fmt.money(plan.total))
                : l10n.payMonthsNone,
            key: const ValueKey<String>('pay-grid-total'),
            textAlign: TextAlign.center,
            style: b.type.body.copyWith(color: b.colors.text2),
          ),
        ),
        if (widget.onDone != null) ...<Widget>[
          const SizedBox(height: BhorSpace.s8),
          BhorButton(
            key: const ValueKey<String>('pay-grid-done'),
            label: l10n.commonDone,
            expand: true,
            onPressed: widget.onDone,
          ),
        ],
      ],
    );
  }
}

/// One month of the grid: the name over its state. Selected = solid accent;
/// paid months are quiet with a check; months that cannot be picked are
/// greyed.
class _GridCell extends StatelessWidget {
  const _GridCell({
    super.key,
    required this.month,
    required this.status,
    required this.semanticLabel,
    required this.settled,
    required this.selected,
    required this.onTap,
  });

  final String month;
  final String status;
  final String semanticLabel;
  final bool settled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool enabled = onTap != null;
    final Color fg = selected ? c.onAccentFill : (enabled ? c.text : c.text3);
    final Color sub = selected ? c.onAccentFill : (enabled ? c.text2 : c.text3);
    return BhorPressable(
      onTap: onTap,
      checked: enabled ? selected : null,
      semanticLabel: semanticLabel,
      excludeChildSemantics: true,
      radius: BhorRadius.chip,
      builder: (BuildContext context, BhorStates s) => AnimatedContainer(
        duration: BhorMotion.of(context, BhorMotion.fast),
        curve: BhorMotion.ease,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s4, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? c.accentFill
              : (enabled ? (s.hovered || s.pressed ? c.soft2 : c.soft) : null),
          borderRadius: BorderRadius.circular(BhorRadius.chip),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              month,
              textAlign: TextAlign.center,
              style: (selected ? b.type.bodyStrong : b.type.body).copyWith(color: fg),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (settled) ...<Widget>[
                  Icon(BhorIcons.check, size: 12, color: sub),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: b.type.caption.copyWith(color: sub),
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
