// Today (UX 1, 2g, 3, 3b): the daily cockpit. Phone: stacked cards (hero, dues,
// day strip + timeline, collection, attendance, quick actions). Medium: the
// same on a 12-column grid (6 + 6). Expanded and wider: a 12-column bento whose
// rows all sum to 12 with equal-height tiles, plus a দিন/সপ্তাহ toggle that
// swaps the bento for the real week grid.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/language_chip.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/widgets/bento_grid.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/classes/classes_entry.dart';
import 'package:attendance_alamin/features/home/controllers/bento_layout.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
import 'package:attendance_alamin/features/home/widgets/absence_alerts_tile.dart';
import 'package:attendance_alamin/features/home/widgets/attendance_today_tile.dart';
import 'package:attendance_alamin/features/home/widgets/backup_nudge_tile.dart';
import 'package:attendance_alamin/features/home/widgets/collection_tile.dart';
import 'package:attendance_alamin/features/home/widgets/conflict_banner.dart';
import 'package:attendance_alamin/features/home/widgets/dues_card.dart';
import 'package:attendance_alamin/features/home/widgets/hero_class_card.dart';
import 'package:attendance_alamin/features/home/widgets/quick_actions.dart';
import 'package:attendance_alamin/features/home/widgets/recent_payments_tile.dart';
import 'package:attendance_alamin/features/home/widgets/reminder_hint.dart';
import 'package:attendance_alamin/features/home/widgets/timeline.dart';
import 'package:attendance_alamin/features/home/widgets/week_glance_tile.dart';

/// Height of a hero + dues row on medium windows (two equal tiles).
const double _kMediumTopRow = 280;

/// Height of the collection + attendance row on medium windows.
const double _kMediumStatRow = 232;

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final WindowClass wc = WindowClass.of(context);
    final LocalDate today = ref.watch(todayProvider);
    final TodayView view = ref.watch(todayViewProvider);
    final bool wide = wc.isWide;

    final List<Widget> actions = <Widget>[
      if (wide)
        Padding(
          padding: const EdgeInsets.only(left: BhorSpace.s8),
          child: SizedBox(
            width: 190,
            child: Semantics(
              container: true,
              label: l10n.todayViewLabel,
              child: BhorSegmented<TodayView>(
                compact: true,
                segments: <BhorSegment<TodayView>>[
                  BhorSegment<TodayView>(TodayView.day, l10n.todayViewDay),
                  BhorSegment<TodayView>(TodayView.week, l10n.todayViewWeek),
                ],
                value: view,
                onChanged: (TodayView v) => ref.read(todayViewProvider.notifier).set(v),
              ),
            ),
          ),
        ),
      if (quickActionsInTopBar(wc)) ..._topBarQuick(context, today),
      BhorIconButton(
        semanticLabel: l10n.commonSearch,
        icon: Icons.search,
        onPressed: () => GoRouter.maybeOf(context)?.push(Routes.search),
      ),
      const LanguageChip(),
      const SizedBox(width: BhorSpace.s8),
    ];

    return BhorScaffold(
      header: BhorHeader(
        title: l10n.navToday,
        subtitle: context.fmt.weekdayDate(today),
        large: true,
        showBack: false,
        actions: actions,
      ),
      body: wide
          ? _WideBody(wc: wc, today: today, week: view == TodayView.week)
          : _StackedBody(wc: wc, today: today),
    );
  }

  /// Large windows move the quick actions into the top bar. Labels show only
  /// when the bar has room; icons with tooltips otherwise.
  List<Widget> _topBarQuick(BuildContext context, LocalDate today) {
    if (MediaQuery.sizeOf(context).width >= 1500) {
      return quickActionBarButtons(context, today);
    }
    return <Widget>[
      for (final QuickAction q in quickActionsOf(context, today).take(3))
        BhorIconButton(
          semanticLabel: q.label,
          icon: q.icon,
          variant: BhorButtonVariant.secondary,
          onPressed: q.onTap,
        ),
    ];
  }
}

// ---- expanded and wider ------------------------------------------------------

class _WideBody extends ConsumerWidget {
  const _WideBody({required this.wc, required this.today, required this.week});

  final WindowClass wc;
  final LocalDate today;
  final bool week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double g = wc.gutter;
    return Padding(
      padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, g),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ConflictBanner(),
          const ReminderHint(),
          Expanded(child: week ? _weekBody(ref) : _bento()),
        ],
      ),
    );
  }

  Widget _weekBody(WidgetRef ref) {
    final int weekStart = ref.watch(weekStartProvider).value ?? 6;
    return BhorCard(
      padding: const EdgeInsets.all(BhorSpace.s12),
      child: WeekGrid(weekStart: weekStartFor(today, weekStart)),
    );
  }

  Widget _bento() {
    return BentoGrid(
      gutter: wc.gutter,
      rowCount: bentoRowCount(wc),
      placements: <BentoPlacement>[
        for (final TileSlot s in bentoSlots(wc))
          BentoPlacement(
            col: s.col,
            row: s.row,
            colSpan: s.colSpan,
            rowSpan: s.rowSpan,
            child: _tile(s.tile),
          ),
      ],
    );
  }

  Widget _tile(TodayTile tile) {
    switch (tile) {
      case TodayTile.hero:
        return HeroClassCard(date: today, fill: true);
      case TodayTile.dues:
        return const DuesCard();
      case TodayTile.timeline:
        return TodayTimeline(date: today, bounded: true);
      case TodayTile.collection:
        return const CollectionTile();
      case TodayTile.attendance:
        return const AttendanceTodayTile();
      case TodayTile.alerts:
        return const AbsenceAlertsTile();
      case TodayTile.quick:
        return QuickActionsTile(date: today);
      case TodayTile.backup:
        return const BackupNudgeTile();
      case TodayTile.recent:
        return const RecentPaymentsTile();
      case TodayTile.week:
        return const WeekGlanceTile();
    }
  }
}

// ---- compact and medium ------------------------------------------------------

class _StackedBody extends ConsumerWidget {
  const _StackedBody({required this.wc, required this.today});

  final WindowClass wc;
  final LocalDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double g = wc.gutter;
    final LocalDate selected = ref.watch(todaySelectedDateProvider) ?? today;
    final bool isToday = selected == today;
    final bool medium = wc == WindowClass.medium;
    // On a phone the floating nav pill sits over the page: scroll under it and
    // leave room for the last card to rest above it.
    final double bottom = MediaQuery.paddingOf(context).bottom;

    final Widget strip = DayStrip(
      selected: selected,
      onSelected: (LocalDate d) =>
          ref.read(todaySelectedDateProvider.notifier).select(d == today ? null : d),
    );

    const Widget gap = SizedBox(height: BhorSpace.s12);

    Widget pair(double height, Widget a, Widget b) => SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: a),
              SizedBox(width: g),
              Expanded(child: b),
            ],
          ),
        );

    final List<Widget> children = <Widget>[
      const ConflictBanner(),
      const ReminderHint(),
      if (medium && isToday)
        pair(_kMediumTopRow, HeroClassCard(date: selected, fill: true), const DuesCard())
      else
        HeroClassCard(date: selected),
      gap,
      if (!medium && isToday) ...<Widget>[const DuesCard(), gap],
      const BackupNudgeTile(onlyWhenDue: true, gapBelow: BhorSpace.s12),
      if (!medium) const AbsenceAlertsTile(maxItems: 3, hideWhenEmpty: true, gapBelow: BhorSpace.s12),
      TodayTimeline(date: selected, strip: strip),
      gap,
      if (medium) ...<Widget>[
        pair(_kMediumStatRow, const CollectionTile(), const AttendanceTodayTile()),
        gap,
        const AbsenceAlertsTile(maxItems: 3, hideWhenEmpty: true, gapBelow: BhorSpace.s12),
      ] else ...<Widget>[
        const CollectionTile(),
        gap,
        const AttendanceTodayTile(),
        gap,
      ],
      QuickActionsCard(date: selected),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, g + bottom),
      children: children,
    );
  }
}
