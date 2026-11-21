// The dues card of Today (UX 5): total owed, "N unpaid / M overdue", the
// 10-segment escalation bar with today ringed, a level legend, and a tap that
// opens Fees. With nobody owing it turns into the green "everyone paid" card.

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
import 'package:attendance_alamin/features/payments/payments_entry.dart';

class DuesCard extends ConsumerWidget {
  const DuesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DuesReport? report = ref.watch(duesReportProvider).value;
    final LocalDate today = ref.watch(todayProvider);
    final l10n = context.l10n;
    if (report == null) {
      return TileFrame(
        header: TileHeader(icon: BhorIcons.fees, title: l10n.todayDuesTitle),
        child: const BhorSkeleton(height: 96, radius: 12),
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

    final List<StudentDues> all = report.active;
    // The bar only means something with a ringed day; past day 10 every
    // segment is filled (day 11 = "beyond").
    final int barDay = escalationDayOf(today) ?? 11;

    return TileFrame(
      scroll: false,
      onTap: () => goRoute(context, Routes.fees),
      header: TileHeader(
        icon: BhorIcons.fees,
        title: l10n.todayDuesTitle,
        trailing: BhorTooltip(
          message: l10n.todayDuesOpen,
          child: Icon(BhorIcons.chevronRight, color: b.colors.text2),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          // Rows that fit below the figure, headline and bar (never clip
          // mid-row): 3 on a scrolling page, else whatever the tile allows.
          int cap = 3;
          if (c.hasBoundedHeight) {
            cap = ((c.maxHeight - _kDuesFixed) / _kDueRowHeight).floor().clamp(0, 3);
          }
          final bool more = all.length > cap && cap > 0;
          final int shown = more ? cap - 1 : (all.length < cap ? all.length : cap);
          final List<StudentDues> rows = all.take(shown).toList();
          final int rest = all.length - rows.length;
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: BhorCountUp.money(amount: report.totalOutstandingActive, style: b.type.display),
                  ),
                  Text(
                    l10n.todayDuesHeadline(
                      fmt.number(report.studentsWithDues),
                      fmt.number(report.overdueStudents),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: b.type.meta,
                  ),
                ],
              ),
              const SizedBox(height: BhorSpace.s12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // The rows below already carry each student's level (QA-18).
                  BhorEscalationBar(day: barDay),
                  if (rows.isNotEmpty || (more && rest > 0)) const SizedBox(height: BhorSpace.s8),
                  for (final StudentDues d in rows) _DueRow(dues: d),
                  if (more && rest > 0) _MoreRow(count: rest),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Height reserved above the rows: figure, headline, gaps and the bar.
const double _kDuesFixed = 120;

/// One [_DueRow] (min height 52).
const double _kDueRowHeight = 52;

/// "আরও N জন →": the tail of the list when more students owe than fit.
class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                context.l10n.todayDuesMore(context.fmt.number(count)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: b.type.label.copyWith(color: b.colors.accent),
              ),
            ),
            Icon(BhorIcons.chevronRight, size: 18, color: b.colors.accent),
          ],
        ),
      ),
    );
  }
}

/// One owing student: avatar, name, level tag and the amount. Opens the
/// payment flow for that student.
class _DueRow extends StatelessWidget {
  const _DueRow({required this.dues});

  final StudentDues dues;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final DueLevel? level = dues.worst;
    return BhorPressable(
      onTap: () => showCollectPaymentSheet(context, studentId: dues.studentId),
      semanticLabel: '${dues.name}, ${context.fmt.money(dues.totalOutstanding)}',
      excludeChildSemantics: true,
      radius: BhorRadius.control,
      builder: (BuildContext context, BhorStates s) => AnimatedContainer(
        duration: BhorMotion.of(context, BhorMotion.instant),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s8, vertical: BhorSpace.s8),
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? b.colors.soft : b.colors.soft.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(BhorRadius.control),
        ),
        child: Row(
          children: <Widget>[
            BhorAvatar(name: dues.name, size: 32),
            const SizedBox(width: BhorSpace.s12),
            Expanded(
              child: Text(dues.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.bodyStrong),
            ),
            if (level != null) ...<Widget>[
              const SizedBox(width: BhorSpace.s8),
              BhorTag.severity(level: level.severityLevel, label: level.label(l10n)),
            ],
            const SizedBox(width: BhorSpace.s8),
            BhorMoney(dues.totalOutstanding, style: b.type.bodyStrong),
          ],
        ),
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
        icon: BhorIcons.fees,
        title: l10n.todayDuesTitle,
        trailing: Icon(BhorIcons.chevronRight, color: b.colors.text2),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(color: b.colors.okBg, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(BhorSpace.s12),
                child: Icon(notStarted ? BhorIcons.clock : BhorIcons.check, size: 32, color: b.colors.ok),
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
