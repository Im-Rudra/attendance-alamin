// The dues card of Today (UX 5): total owed, "N unpaid / M overdue", the
// 10-segment escalation bar with today ringed, a level legend, and a tap that
// opens Fees. With nobody owing it turns into the green "everyone paid" card.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;

    final List<Widget> legend = <Widget>[
      for (final DueLevel level in _legendOrder)
        if ((report.countByLevel[level] ?? 0) > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SeverityBadge(level: level, compact: true),
              const SizedBox(width: 4),
              Text(
                fmt.number(report.countByLevel[level] ?? 0),
                style: tt.labelLarge?.copyWith(color: tokens.textPrimary),
              ),
            ],
          ),
    ];

    return TileFrame(
      onTap: () => goRoute(context, Routes.fees),
      header: TileHeader(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.todayDuesTitle,
        trailing: Tooltip(
          message: l10n.todayDuesOpen,
          child: Icon(Icons.chevron_right, color: tokens.textSecondary),
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
                child: Text(
                  fmt.money(report.totalOutstandingActive),
                  maxLines: 1,
                  style: context.statNumber,
                ),
              ),
              Text(
                l10n.todayDuesHeadline(
                  fmt.number(report.studentsWithDues),
                  fmt.number(report.overdueStudents),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(color: tokens.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) => EscalationBar(
                  todayDay: escalationDayOf(today),
                  overdueCount: c.maxWidth >= 280 ? report.overdueStudents : 0,
                ),
              ),
              if (legend.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.surfaceDense,
                    borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Wrap(spacing: 12, runSpacing: 6, children: legend),
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
    final tokens = context.aurora;
    final sev = context.severity;
    final TextTheme tt = Theme.of(context).textTheme;
    final int collected = ref.watch(todayCollectionProvider).value?.collected ?? 0;
    return TileFrame(
      onTap: () => goRoute(context, Routes.fees),
      header: TileHeader(
        icon: Icons.account_balance_wallet_outlined,
        title: l10n.todayDuesTitle,
        trailing: Icon(Icons.chevron_right, color: tokens.textSecondary),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(color: sev.paidFill, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.check, size: 32, color: sev.paidText),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    // "Everyone has paid" only when money came in this month;
                    // with nothing collected nobody owed anything yet.
                    collected > 0 ? l10n.todayDuesAllPaid : l10n.todayDuesNone,
                    style: tt.titleMedium?.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (collected > 0)
                    Text(
                      l10n.todayDuesAllPaidSub(fmt.money(collected)),
                      style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
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
