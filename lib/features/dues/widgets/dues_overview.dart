// Summary blocks of the Fees tab (UX 5 "dues card" and the desktop mock):
// the dues card of phones (count-up total, "N unpaid · M overdue", the
// 10-segment escalation bar with today ringed) and the three summary tiles of
// wide windows (expected · received · outstanding of this month, count-ups
// with an animated progress bar).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_empty.dart';

/// Card: total due, headline, escalation bar. [action] sits at the top right
/// (the "remind everyone" button on phones).
class DuesSummaryCard extends ConsumerWidget {
  const DuesSummaryCard({super.key, required this.report, this.action});

  final DuesReport report;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final LocalDate today = ref.watch(todayProvider);

    final bool nothing =
        report.studentsWithDues == 0 && report.totalOutstandingInactive == 0;
    if (nothing) {
      return BhorCard(
        child: Row(
          children: <Widget>[
            Icon(BhorIcons.checkCircleFill, color: b.colors.ok, size: 28),
            const SizedBox(width: BhorSpace.s12),
            Expanded(
              child: Text(
                duesEmptyMessage(context, ref.watch(billingStatusProvider).value),
                style: b.type.heading,
              ),
            ),
          ],
        ),
      );
    }

    return BhorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(l10n.duesTotalLabel, style: b.type.meta),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: BhorCountUp.money(
                        amount: report.totalOutstandingActive,
                        style: b.type.stat,
                        muteSign: true,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...<Widget>[const SizedBox(width: BhorSpace.s8), action!],
            ],
          ),
          const SizedBox(height: BhorSpace.s4),
          Text(
            l10n.duesHeadline(
              fmt.number(report.studentsWithDues),
              fmt.number(report.overdueStudents),
            ),
            style: b.type.bodyStrong,
          ),
          if (report.totalOutstandingInactive > 0) ...<Widget>[
            const SizedBox(height: 2),
            Text(l10n.duesInactiveLine(fmt.money(report.totalOutstandingInactive)), style: b.type.meta),
          ],
          if (report.studentsWithDues > 0) ...<Widget>[
            const SizedBox(height: BhorSpace.s12),
            BhorEscalationBar(day: escalationDay(today) ?? 11),
          ],
        ],
      ),
    );
  }
}

/// This month at a glance: expected · received (with progress) · outstanding.
/// Three equal tiles that count up; shown above the list on wide windows.
class FeesSummaryTiles extends ConsumerWidget {
  const FeesSummaryTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final YearMonth month = ref.watch(todayProvider).yearMonth;
    final CollectionSummary? s = ref.watch(collectionSummaryProvider(month)).value;
    if (s == null) {
      return const Row(
        children: <Widget>[
          Expanded(child: BhorSkeleton(height: 96)),
          SizedBox(width: BhorSpace.s12),
          Expanded(child: BhorSkeleton(height: 96)),
          SizedBox(width: BhorSpace.s12),
          Expanded(child: BhorSkeleton(height: 96)),
        ],
      );
    }
    final MonthTotals t = s.totals;
    final double progress = t.expected <= 0 ? 0 : (t.received / t.expected).clamp(0.0, 1.0);
    Widget tile(String label, int amount, {Color? color, bool bar = false}) => Expanded(
          child: BhorCard(
            padding: const EdgeInsets.all(BhorSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: BhorCountUp.money(amount: amount, style: b.type.stat, color: color, muteSign: true),
                ),
                const SizedBox(height: BhorSpace.s12),
                bar
                    ? BhorProgress(value: progress, color: b.colors.ok)
                    : const SizedBox(height: 6),
              ],
            ),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        tile(l10n.collExpected, t.expected),
        const SizedBox(width: BhorSpace.s12),
        tile(l10n.collReceived, t.received, color: b.colors.ok, bar: true),
        const SizedBox(width: BhorSpace.s12),
        tile(l10n.collOutstanding, t.outstanding),
      ],
    );
  }
}
