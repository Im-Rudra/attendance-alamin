// Overview of the dues (UX 5 "dues card" and 3b Fees): the big total, the
// "N unpaid · M overdue" headline, the 10-segment escalation bar with today
// ringed, and the per-level counts. The overview pane (nothing selected on a
// wide window, and the level rail on extra-large windows) adds this month's
// collection and the students who owe most.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_empty.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';

/// Glass card: total due, headline, escalation bar, level legend.
class DuesSummaryCard extends ConsumerWidget {
  const DuesSummaryCard({super.key, required this.report});

  final DuesReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final LocalDate today = ref.watch(todayProvider);

    final bool nothing =
        report.studentsWithDues == 0 && report.totalOutstandingInactive == 0;
    if (nothing) {
      return GlassCard(
        child: Row(
          children: <Widget>[
            Icon(Icons.check_circle, color: tokens.accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                duesEmptyMessage(context, ref.watch(billingStatusProvider).value),
                style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> legend = <Widget>[
      for (final DueLevel level in kDuesGroupOrder)
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

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.duesTotalLabel,
            style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyText(
              fmt.money(report.totalOutstandingActive),
              maxLines: 1,
              style: context.statNumber,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.duesHeadline(
              fmt.number(report.studentsWithDues),
              fmt.number(report.overdueStudents),
            ),
            style: tt.titleSmall?.copyWith(color: tokens.textPrimary),
          ),
          if (report.totalOutstandingInactive > 0) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              l10n.duesInactiveLine(fmt.money(report.totalOutstandingInactive)),
              style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
            ),
          ],
          if (report.studentsWithDues > 0) ...<Widget>[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) => EscalationBar(
                todayDay: escalationDay(today),
                // The count badge needs room; on a narrow rail the headline
                // already says it.
                overdueCount: c.maxWidth >= 280 ? report.overdueStudents : 0,
              ),
            ),
            if (legend.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 6, children: legend),
            ],
          ],
        ],
      ),
    );
  }
}

/// This month's collection as three tiles + a link to the full summary.
class _CollectionGlance extends ConsumerWidget {
  const _CollectionGlance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final YearMonth month = ref.watch(todayProvider).yearMonth;
    final CollectionSummary? s = ref.watch(collectionSummaryProvider(month)).value;
    if (s == null) return const SizedBox.shrink();
    final MonthTotals t = s.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: l10n.duesOverviewMonth(fmt.monthYear(month))),
        StatTile(label: l10n.collExpected, value: fmt.money(t.expected)),
        const SizedBox(height: 8),
        StatTile(label: l10n.collReceived, value: fmt.money(t.received)),
        const SizedBox(height: 8),
        StatTile(label: l10n.collOutstanding, value: fmt.money(t.outstanding)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => GoRouter.maybeOf(context)?.go(Routes.feesCollection),
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(l10n.duesOpenCollection),
        ),
      ],
    );
  }
}

/// Who owes most: a short tappable list that fills the overview pane.
class _TopDues extends ConsumerWidget {
  const _TopDues({required this.report});

  final DuesReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.aurora;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final LocalDate today = ref.watch(todayProvider);
    final DuesView view = buildDuesView(report, const DuesFilter(), today);
    final List<DuesRow> top = view.active.take(6).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: context.l10n.duesSegDues),
        ClipRRect(
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
          child: Material(
            color: tokens.surfaceDense,
            child: Column(
              children: <Widget>[
                for (final DuesRow r in top)
                  InkWell(
                    onTap: () => openDuesStudent(context, r.studentId),
                    hoverColor: tokens.track,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    r.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.titleSmall?.copyWith(color: tokens.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: DuesStatusBadge(row: r, compact: true),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              fmt.money(r.total),
                              maxLines: 1,
                              style: tt.titleSmall?.copyWith(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The detail pane while no student is selected, and the extra-large rail.
class DuesOverview extends ConsumerWidget {
  const DuesOverview({super.key, this.rail = false});

  /// Narrow variant: summary and this month's tiles only.
  final bool rail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final AsyncValue<DuesReport> async = ref.watch(duesReportProvider);
    final DuesReport? report = async.value;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: rail
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              title: Semantics(header: true, child: Text(l10n.duesOverviewTitle)),
            ),
      body: report == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(g, 8, g, g),
              children: <Widget>[
                DuesSummaryCard(report: report),
                const SizedBox(height: 8),
                const _CollectionGlance(),
                if (!rail) ...<Widget>[
                  const SizedBox(height: 8),
                  _TopDues(report: report),
                ],
              ],
            ),
    );
  }
}
