// Today (UX 1, 2g, 3, 3b): the daily cockpit. Desktop (>= 840): the dashboard
// template (BhorDashboardPage): a full-width hero, then content-sized cards in
// a masonry, so no card is hollow or clipped; a দিন/সপ্তাহ toggle swaps the
// cards for the real week grid, and one "নতুন…" menu holds the quick actions.
// Phone and medium: stacked cards (hero, dues, day strip + timeline,
// collection, attendance, quick actions) as before.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/shell/templates/templates.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/classes/classes_entry.dart';
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

/// Below this window width "New…" becomes an icon button with a tooltip so
/// the header never loses it (review T8).
const double _kNewIconBelow = 1100;

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final WindowClass wc = WindowClass.of(context);
    final LocalDate today = ref.watch(todayProvider);
    final TodayView view = ref.watch(todayViewProvider);

    // "শুভ সকাল / বিকাল / সন্ধ্যা" over the weekday-date line.
    final int nowMin = ref.watch(nowMinutesProvider);
    final String greeting = nowMin < 12 * 60
        ? l10n.todayGreetMorning
        : (nowMin < 17 * 60 ? l10n.todayGreetAfternoon : l10n.todayGreetEvening);

    if (wc.isWide) {
      return _WideBody(
        today: today,
        week: view == TodayView.week,
        overline: context.fmt.weekdayDate(today),
        title: greeting,
        actions: <Widget>[
          SizedBox(
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
          _NewMenuButton(date: today),
        ],
      );
    }

    return BhorScaffold(
      header: BhorHeader(
        overline: context.fmt.weekdayDate(today),
        title: greeting,
        large: true,
        showBack: false,
      ),
      body: _StackedBody(wc: wc, today: today),
    );
  }
}

/// Desktop: one "নতুন…" button that lists the quick actions (collect fee, add
/// student, extra class), each opening in place. At narrow desktop widths it
/// is an icon button with a tooltip, so it never disappears.
class _NewMenuButton extends StatelessWidget {
  const _NewMenuButton({required this.date});

  final LocalDate date;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool iconOnly = MediaQuery.sizeOf(context).width < _kNewIconBelow;
    return Builder(
      builder: (BuildContext bc) {
        void open() {
          final List<QuickAction> actions = quickActionsOf(context, date).take(3).toList();
          showBhorMenu(
            bc,
            items: <BhorMenuItem>[
              for (final QuickAction a in actions) BhorMenuItem(icon: a.icon, label: a.label, onTap: a.onTap),
            ],
          );
        }

        if (iconOnly) {
          return BhorIconButton(
            semanticLabel: l10n.todayNewMenu,
            icon: BhorIcons.add,
            variant: BhorButtonVariant.secondary,
            circle: true,
            onPressed: open,
          );
        }
        return BhorButton(
          label: l10n.todayNewMenu,
          icon: BhorIcons.add,
          variant: BhorButtonVariant.secondary,
          onPressed: open,
        );
      },
    );
  }
}

// ---- expanded and wider ------------------------------------------------------

class _WideBody extends ConsumerWidget {
  const _WideBody({
    required this.today,
    required this.week,
    required this.overline,
    required this.title,
    required this.actions,
  });

  final LocalDate today;
  final bool week;
  final String overline;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WindowClass wc = WindowClass.of(context);
    const Widget banners = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[ConflictBanner(), ReminderHint()],
    );

    final Widget hero;
    final List<Widget> cards;
    if (week) {
      final int weekStart = ref.watch(weekStartProvider).value ?? 6;
      // The week grid needs a bounded height; the page scrolls if the window
      // is shorter than the grid's minimum.
      final double h = (MediaQuery.sizeOf(context).height - 220).clamp(560.0, 1400.0);
      hero = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          banners,
          SizedBox(
            height: h,
            child: BhorCard(
              padding: const EdgeInsets.all(BhorSpace.s12),
              child: WeekGrid(weekStart: weekStartFor(today, weekStart)),
            ),
          ),
        ],
      );
      cards = const <Widget>[];
    } else {
      hero = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[banners, HeroClassCard(date: today, wide: true)],
      );
      cards = <Widget>[
        const DuesCard(),
        TodayTimeline(date: today),
        const CollectionTile(),
        const AttendanceTodayTile(),
        const RecentPaymentsTile(),
        const AbsenceAlertsTile(),
        if (wc == WindowClass.extraLarge) const WeekGlanceTile(),
        const BackupNudgeTile(),
      ];
    }

    return BhorDashboardPage(
      overline: overline,
      title: title,
      actions: actions,
      hero: hero,
      children: cards,
    );
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
    int n = 0;
    Widget st(Widget w) => BhorStagger(index: n++, child: w);

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
        st(pair(_kMediumTopRow, HeroClassCard(date: selected, fill: true), const DuesCard()))
      else
        st(HeroClassCard(date: selected)),
      gap,
      if (!medium && isToday) ...<Widget>[st(const DuesCard()), gap],
      const BackupNudgeTile(onlyWhenDue: true, gapBelow: BhorSpace.s12),
      if (!medium) const AbsenceAlertsTile(maxItems: 3, hideWhenEmpty: true, gapBelow: BhorSpace.s12),
      st(TodayTimeline(date: selected, strip: strip)),
      gap,
      if (medium) ...<Widget>[
        st(pair(_kMediumStatRow, const CollectionTile(), const AttendanceTodayTile())),
        gap,
        const AbsenceAlertsTile(maxItems: 3, hideWhenEmpty: true, gapBelow: BhorSpace.s12),
      ] else ...<Widget>[
        st(const CollectionTile()),
        gap,
        st(const AttendanceTodayTile()),
        gap,
      ],
      st(QuickActionsCard(date: selected)),
    ];

    return BhorStaggerScope(
      child: ListView(
        padding: EdgeInsets.fromLTRB(g, BhorSpace.s4, g, g + bottom),
        children: children,
      ),
    );
  }
}
