// Quick actions (UX 3, 3b): collect a fee, add a student, add an extra class,
// search. A 2x2 tile on expanded windows, a card on phones and mediums, and
// buttons in the top bar on large windows.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/classes/classes_entry.dart';
import 'package:attendance_alamin/features/home/widgets/tile_frame.dart';
import 'package:attendance_alamin/features/home/widgets/today_actions.dart';

class QuickAction {
  const QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// The four actions, in the order of UX 3b.
List<QuickAction> quickActionsOf(BuildContext context, LocalDate date) {
  final l10n = context.l10n;
  return <QuickAction>[
    QuickAction(
      icon: Icons.payments_outlined,
      label: l10n.todayQuickCollect,
      onTap: () => goRoute(context, Routes.fees),
    ),
    QuickAction(
      icon: Icons.person_add_alt_1_outlined,
      label: l10n.todayQuickAddStudent,
      onTap: () => pushRoute(context, Routes.studentNew),
    ),
    QuickAction(
      icon: Icons.add_circle_outline,
      label: l10n.todayQuickExtra,
      onTap: () => showExtraClassSheet(context, date: date),
    ),
    QuickAction(
      icon: Icons.search,
      label: l10n.todayQuickSearch,
      onTap: () => pushRoute(context, Routes.search),
    ),
  ];
}

/// The bento tile: a 2x2 grid of pills that fills the tile (needs a bounded
/// height, which the bento always gives).
class QuickActionsTile extends StatelessWidget {
  const QuickActionsTile({super.key, required this.date});

  final LocalDate date;

  @override
  Widget build(BuildContext context) {
    final List<QuickAction> a = quickActionsOf(context, date);
    return TileFrame(
      scroll: false,
      header: TileHeader(icon: Icons.bolt_outlined, title: context.l10n.todayQuickTitle),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(child: _QuickPill(action: a[0])),
                const SizedBox(width: BhorSpace.s8),
                Expanded(child: _QuickPill(action: a[1])),
              ],
            ),
          ),
          const SizedBox(height: BhorSpace.s8),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(child: _QuickPill(action: a[2])),
                const SizedBox(width: BhorSpace.s8),
                Expanded(child: _QuickPill(action: a[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone / medium card: the same four pills at a fixed height.
class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key, required this.date});

  final LocalDate date;

  @override
  Widget build(BuildContext context) {
    final List<QuickAction> a = quickActionsOf(context, date);
    return TileFrame(
      header: TileHeader(icon: Icons.bolt_outlined, title: context.l10n.todayQuickTitle),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: SizedBox(height: 56, child: _QuickPill(action: a[0]))),
              const SizedBox(width: BhorSpace.s8),
              Expanded(child: SizedBox(height: 56, child: _QuickPill(action: a[1]))),
            ],
          ),
          const SizedBox(height: BhorSpace.s8),
          Row(
            children: <Widget>[
              Expanded(child: SizedBox(height: 56, child: _QuickPill(action: a[2]))),
              const SizedBox(width: BhorSpace.s8),
              Expanded(child: SizedBox(height: 56, child: _QuickPill(action: a[3]))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Top-bar buttons on large windows (search already has its own icon there).
List<Widget> quickActionBarButtons(BuildContext context, LocalDate date) {
  final List<QuickAction> a = quickActionsOf(context, date);
  return <Widget>[
    for (final QuickAction q in a.take(3))
      Padding(
        padding: const EdgeInsets.only(left: BhorSpace.s8),
        child: BhorButton(
          label: q.label,
          icon: q.icon,
          variant: BhorButtonVariant.secondary,
          onPressed: q.onTap,
        ),
      ),
  ];
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return BhorPressable(
      onTap: action.onTap,
      semanticLabel: action.label,
      isButton: true,
      excludeChildSemantics: true,
      radius: BhorRadius.card,
      builder: (BuildContext context, BhorStates s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12),
        decoration: BoxDecoration(
          color: s.hovered ? c.surface2 : c.surface,
          borderRadius: BorderRadius.circular(BhorRadius.card),
          border: Border.all(color: s.hovered ? c.accentLine : c.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(action.icon, size: 22, color: c.accent),
            const SizedBox(width: BhorSpace.s8),
            Flexible(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: b.type.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
