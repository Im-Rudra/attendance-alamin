// The dues card of Today (UX 5): total owed, "N unpaid / M overdue", the
// 10-segment escalation bar with today ringed, a level legend, and a tap that
// opens Fees. With nobody owing it turns into the green "everyone paid" card.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
import 'package:attendance_alamin/features/home/widgets/tile_frame.dart';
import 'package:attendance_alamin/features/home/widgets/today_actions.dart';

/// Worst first: what the legend lists.
const List<DueLevel> _legendOrder = <DueLevel>[
  DueLevel.overdue,
  DueLevel.finalDays,
  DueLevel.urgent,
  DueLevel.followUp,
  DueLevel.remind,
  DueLevel.justDue,
];

class DuesCard extends ConsumerWidget {
  const DuesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DuesReport? report = ref.watch(duesReportProvider).value;
    final LocalDate today = ref.watch(todayProvider);
    final l10n = context.l10n;
    if (report == null) {
      return TileFrame(
        header: TileHeader(icon: Icons.account_balance_wallet_outlined, title: l10n.todayDuesTitle),
        child: const SizedBox(height: 96),
      );
    }
    if (report.studentsWithDues == 0) {
      return const _AllPaid();
    }
    return _DuesBody(report: report, today: today);
  }
}

class _DuesBody extends StatelessWidget {
  const _DuesBody({required this.report, required this.today});

  final DuesReport report;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;

    final List<Widget> legend = <Widget>[
      for (final DueLevel level in _legendOrder)
        if ((report.countByLevel[level] ?? 0) > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              BhorTag.severity(
                level: level.severityLevel,
                label: level.label(l10n),
                icon: level.icon,
              ),
              const SizedBox(width: BhorSpace.s4),
              Text(
                fmt.number(report.countByLevel[level] ?? 0),
                style: b.type.label,
              ),
            ],
          ),
    ];

    return TileFrame(
      onTap: () => goRoute(context, Routes.fees),
      header: TileHeader(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.todayDuesTitle,
        trailing: BhorTooltip(
          message: l10n.todayDuesOpen,
          child: Icon(Icons.chevron_right, color: b.colors.text2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: BhorMoney(report.totalOutstandingActive, style: b.type.display),
              ),
              Text(
                l10n.todayDuesHeadline(
                  fmt.number(report.studentsWithDues),
                  fmt.number(report.overdueStudents),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: b.type.heading,
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // The legend below already counts the overdue students (QA-18).
              BhorEscalationBar(day: escalationDayOf(today) ?? 0),
              if (legend.isNotEmpty) ...<Widget>[
                const SizedBox(height: BhorSpace.s8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: b.colors.surface2,
                    borderRadius: BorderRadius.circular(BhorRadius.control),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12, vertical: BhorSpace.s8),
                    child: Wrap(spacing: BhorSpace.s12, runSpacing: BhorSpace.s8, children: legend),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Nobody owes anything: a calm green confirmation with the month's cash.
class _AllPaid extends ConsumerWidget {
  const _AllPaid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final int collected = ref.watch(todayCollectionProvider).value?.collected ?? 0;
    final BillingStatus? status = ref.watch(billingStatusProvider).value;
    final bool notStarted = status != null && status.notStarted;
    // "Everyone has paid" only when this month had fees and all are paid.
    final bool allPaid = !notStarted && (collected > 0 || (status?.billedThisMonth ?? false));
    return TileFrame(
      onTap: () => goRoute(context, Routes.fees),
      header: TileHeader(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.todayDuesTitle,
        trailing: Icon(Icons.chevron_right, color: b.colors.text2),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(color: b.colors.okBg, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(BhorSpace.s12),
                child: Icon(notStarted ? Icons.schedule : Icons.check, size: 32, color: b.colors.ok),
              ),
            ),
            const SizedBox(width: BhorSpace.s16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    // "Everyone has paid" only when money came in this month;
                    // with nothing collected nobody owed anything yet.
                    notStarted
                        ? l10n.duesNotStarted(fmt.monthYear(status.firstUpcoming!))
                        : (allPaid ? l10n.todayDuesAllPaid : l10n.todayDuesNone),
                    style: b.type.heading,
                  ),
                  if (allPaid && collected > 0)
                    Text(
                      l10n.todayDuesAllPaidSub(fmt.money(collected)),
                      style: b.type.meta,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
