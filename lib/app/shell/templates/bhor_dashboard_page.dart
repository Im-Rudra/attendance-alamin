// BhorDashboardPage (docs/council/16-windows-rebuild-plan.md W1-B 5): the
// Today-style page. A header (date overline, greeting title, actions), an
// optional full-width hero, then content-sized cards in a masonry (1 / 2 / 3
// columns by width, BhorMasonry) so no card is hollow or clipped (review T1).
// The whole column is at most 1320 wide and centred; it scrolls as one.
// Usage:
//   BhorDashboardPage(
//     overline: fmt.weekdayDate(today),
//     title: l10n.todayGreeting,
//     actions: [newButton],
//     hero: NextClassHero(...),
//     children: [classesCard, paymentsCard, backupCard],
//   )

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class BhorDashboardPage extends StatelessWidget {
  const BhorDashboardPage({
    super.key,
    required this.title,
    required this.children,
    this.overline,
    this.subtitle,
    this.actions = const <Widget>[],
    this.hero,
    this.maxWidth = defaultMaxWidth,
    this.minColumnWidth = 340,
    this.controller,
  });

  /// Widest the content column gets (centred beyond it).
  static const double defaultMaxWidth = 1320;

  /// Key of the scroll view (tests).
  static const Key scrollKey = Key('bhor-dashboard-scroll');

  /// Greeting / page title (display size).
  final String title;

  /// Small line above the title (the date).
  final String? overline;
  final String? subtitle;

  /// Header actions, right-aligned (New…, search).
  final List<Widget> actions;

  /// Full-width block above the cards (the hero card).
  final Widget? hero;

  /// The dashboard cards, content-sized, in reading order.
  final List<Widget> children;
  final double maxWidth;

  /// A masonry column is never narrower than this.
  final double minColumnWidth;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final bool wide = context.bhorIsWide;
    final double gutter = wide ? BhorSpace.screenDesktop : BhorSpace.screenPhone;
    final double gap = wide ? BhorSpace.s20 : BhorSpace.s16;
    return BhorScaffold(
      body: SingleChildScrollView(
        key: scrollKey,
        controller: controller,
        padding: EdgeInsets.fromLTRB(gutter, wide ? BhorSpace.s24 : BhorSpace.s12, gutter, BhorSpace.s32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (overline != null)
                            Text(overline!, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
                          Semantics(
                            header: true,
                            child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: b.type.display),
                          ),
                          if (subtitle != null)
                            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
                        ],
                      ),
                    ),
                    for (int i = 0; i < actions.length; i++) ...<Widget>[
                      SizedBox(width: i == 0 ? BhorSpace.s12 : BhorSpace.s8),
                      actions[i],
                    ],
                  ],
                ),
                SizedBox(height: gap),
                if (hero != null) ...<Widget>[hero!, SizedBox(height: gap)],
                BhorMasonry(gap: gap, minColumnWidth: minColumnWidth, children: children),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
