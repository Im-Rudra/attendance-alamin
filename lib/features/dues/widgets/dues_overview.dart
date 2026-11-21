// Overview of the dues (UX 5 "dues card" and 3b Fees): the big total, the
// "N unpaid · M overdue" headline, the 10-segment escalation bar with today
// ringed, and the per-level counts. The overview pane (nothing selected on a
// wide window, and the level rail on extra-large windows) adds this month's
// collection and the students who owe most.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_empty.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_tags.dart';

/// Card: total due, headline, escalation bar, level legend.
class DuesSummaryCard extends ConsumerWidget {
  const DuesSummaryCard({super.key, required this.report});

  final DuesReport report;

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
            Icon(Icons.check_circle, color: b.colors.accent, size: 28),
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

    final List<Widget> legend = <Widget>[
      for (final DueLevel level in kDuesGroupOrder)
        if ((report.countByLevel[level] ?? 0) > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              dueLevelTag(context, level, compact: true),
              const SizedBox(width: BhorSpace.s4),
              Text(fmt.number(report.countByLevel[level] ?? 0), style: b.type.label),
            ],
          ),
    ];

    return BhorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.duesTotalLabel, style: b.type.meta),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: BhorMoney(report.totalOutstandingActive, style: b.type.stat),
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
            if (legend.isNotEmpty) ...<Widget>[
              const SizedBox(height: BhorSpace.s8),
              Wrap(spacing: BhorSpace.s12, runSpacing: 6, children: legend),
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
    Widget tile(String label, int amount) => BhorCard(
          padding: const EdgeInsets.all(BhorSpace.s12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: BhorStatText.money(label: label, amount: amount),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorSectionHeader(title: l10n.duesOverviewMonth(fmt.monthYear(month))),
        tile(l10n.collExpected, t.expected),
        const SizedBox(height: BhorSpace.s8),
        tile(l10n.collReceived, t.received),
        const SizedBox(height: BhorSpace.s8),
        tile(l10n.collOutstanding, t.outstanding),
        const SizedBox(height: BhorSpace.s8),
        BhorButton(
          variant: BhorButtonVariant.secondary,
          icon: Icons.receipt_long_outlined,
          label: l10n.duesOpenCollection,
          onPressed: () => GoRouter.maybeOf(context)?.go(Routes.feesCollection),
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
    final BhorThemeData b = context.bhor;
    final LocalDate today = ref.watch(todayProvider);
    final DuesView view = buildDuesView(report, const DuesFilter(), today);
    final List<DuesRow> top = view.active.take(6).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorSectionHeader(title: context.l10n.duesSegDues),
        BhorCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < top.length; i++)
                BhorPressable(
                  onTap: () => openDuesStudent(context, top[i].studentId),
                  semanticLabel: top[i].name,
                  scaleOnPress: false,
                  radius: 0,
                  builder: (BuildContext context, BhorStates s) => Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: 6),
                    decoration: BoxDecoration(
                      color: s.hovered || s.pressed ? b.colors.surface2 : null,
                      border: i < top.length - 1 ? Border(bottom: BorderSide(color: b.colors.line)) : null,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                top[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: b.type.bodyStrong,
                              ),
                              const SizedBox(height: 2),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: DuesStatusBadge(row: top[i], compact: true),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: BhorSpace.s8),
                        BhorMoney(top[i].total, style: b.type.bodyStrong),
                      ],
                    ),
                  ),
                ),
            ],
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
    return BhorScaffold(
      header: rail ? null : BhorHeader(title: l10n.duesOverviewTitle, showBack: false),
      body: report == null
          ? const Center(child: BhorSpinner())
          : ListView(
              padding: EdgeInsets.fromLTRB(g, BhorSpace.s8, g, g),
              children: <Widget>[
                DuesSummaryCard(report: report),
                const SizedBox(height: BhorSpace.s8),
                const _CollectionGlance(),
                if (!rail) ...<Widget>[
                  const SizedBox(height: BhorSpace.s8),
                  _TopDues(report: report),
                ],
              ],
            ),
    );
  }
}
