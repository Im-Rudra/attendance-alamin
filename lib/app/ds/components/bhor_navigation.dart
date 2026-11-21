// Navigation chrome: BhorTabs (underline), BhorBottomNav (phone),
// BhorSidebar (desktop, collapsible) and BhorHeader (replaces AppBar).

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_button.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

/// One destination of a [BhorBottomNav] / [BhorSidebar].
class BhorNavItem {
  const BhorNavItem({required this.icon, required this.label, this.activeIcon, this.badge, this.semanticLabel});

  final IconData icon;
  final IconData? activeIcon;
  final String label;

  /// Short badge text ("৩"); null hides it.
  final String? badge;

  /// What a screen reader says (e.g. "বেতন, বকেয়া ৩"); defaults to the
  /// label plus the badge.
  final String? semanticLabel;

  String get a11yLabel => semanticLabel ?? (badge == null ? label : '$label, $badge');
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: b.colors.danger, borderRadius: BorderRadius.circular(9)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: BhorType.tabular(b.type.caption).copyWith(color: b.colors.onDanger, fontWeight: FontWeight.w600, height: 1.5),
      ),
    );
  }
}

/// Underline tabs (scroll horizontally when they do not fit).
/// Usage: `BhorTabs(tabs: ['শিক্ষার্থী', 'রুটিন'], index: i, onChanged: f)`.
class BhorTabs extends StatelessWidget {
  const BhorTabs({super.key, required this.tabs, required this.index, required this.onChanged});

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < tabs.length; i++)
              BhorPressable(
                onTap: () => onChanged(i),
                selected: i == index,
                inMutuallyExclusiveGroup: true,
                semanticLabel: tabs[i],
                excludeChildSemantics: true,
                scaleOnPress: false,
                radius: 8,
                builder: (BuildContext context, BhorStates s) => SizedBox(
                  height: BhorSize.control,
                  child: Stack(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            tabs[i],
                            maxLines: 1,
                            style: (i == index ? b.type.bodyStrong : b.type.body)
                                .copyWith(color: i == index ? c.accent : (s.hovered ? c.text : c.text2)),
                          ),
                        ),
                      ),
                      Positioned(
                        left: BhorSpace.s8,
                        right: BhorSpace.s8,
                        bottom: 0,
                        child: AnimatedContainer(
                          duration: BhorMotion.base,
                          curve: BhorMotion.curve,
                          height: 2,
                          decoration: BoxDecoration(
                            color: i == index ? c.accent : (s.hovered ? c.line : null),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Phone bottom navigation: flat bar, top hairline, active icon in an
/// accent-tint pill. Usage: `BhorBottomNav(items: [...], index: i, onTap: go)`.
class BhorBottomNav extends StatelessWidget {
  const BhorBottomNav({super.key, required this.items, required this.index, required this.onTap});

  final List<BhorNavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: BhorPressable(
                    onTap: () => onTap(i),
                    selected: i == index,
                    semanticLabel: items[i].a11yLabel,
                    excludeChildSemantics: true,
                    radius: 12,
                    builder: (BuildContext context, BhorStates s) {
                      final bool on = i == index;
                      final Color fg = on ? c.accent : (s.hovered ? c.text : c.text2);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: BhorMotion.base,
                            curve: BhorMotion.curve,
                            width: 56,
                            height: 30,
                            decoration: BoxDecoration(
                              color: on ? c.accentTint : null,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: <Widget>[
                                Icon(on ? (items[i].activeIcon ?? items[i].icon) : items[i].icon, size: 22, color: fg),
                                if (items[i].badge != null)
                                  Positioned(top: -2, right: 6, child: _Badge(items[i].badge!)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: b.type.caption.copyWith(color: fg, fontWeight: on ? FontWeight.w600 : FontWeight.w400),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop sidebar: brand, nav items with badges, optional footer;
/// collapsible to icons (72 wide). Usage:
/// `BhorSidebar(brand: 'হাজিরা খাতা', items: [...], index: i, onTap: go, collapsed: c, onToggleCollapsed: t)`.
class BhorSidebar extends StatelessWidget {
  const BhorSidebar({
    super.key,
    required this.brand,
    required this.items,
    required this.index,
    required this.onTap,
    this.collapsed = false,
    this.onToggleCollapsed,
    this.toggleLabel,
    this.footer,
  });

  final String brand;
  final List<BhorNavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  /// Accessible name of the collapse button.
  final String? toggleLabel;

  /// Shown under the items in both states (build it for [collapsed]).
  final Widget? footer;

  static const double width = 248;
  static const double collapsedWidth = 72;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return AnimatedContainer(
      duration: BhorMotion.slow,
      curve: BhorMotion.curve,
      width: collapsed ? collapsedWidth : width,
      decoration: BoxDecoration(color: c.surface, border: Border(right: BorderSide(color: c.line))),
      child: SafeArea(
        right: false,
        child: ClipRect(
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            // Content at the target width while the box animates (clipped).
            minWidth: (collapsed ? collapsedWidth : width) - 1,
            maxWidth: (collapsed ? collapsedWidth : width) - 1,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: 64,
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 14),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: c.heroGradient,
                        borderRadius: BorderRadius.circular(BhorRadius.avatar),
                      ),
                      alignment: Alignment.center,
                      child: Text(brand.characters.first, style: b.type.heading.copyWith(color: c.onHero, height: 1.2)),
                    ),
                    if (!collapsed) ...<Widget>[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(brand, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.heading),
                      ),
                    ] else
                      const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  children: <Widget>[
                    for (int i = 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: BhorTooltip(
                          message: items[i].label,
                          enabled: collapsed,
                          child: BhorPressable(
                            onTap: () => onTap(i),
                            selected: i == index,
                            semanticLabel: items[i].a11yLabel,
                            excludeChildSemantics: true,
                            scaleOnPress: false,
                            builder: (BuildContext context, BhorStates s) {
                              final bool on = i == index;
                              final Color fg = on ? c.accent : (s.hovered ? c.text : c.text2);
                              return AnimatedContainer(
                                duration: BhorMotion.fast,
                                height: BhorSize.control,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: on ? c.accentTint : (s.hovered ? c.surface2 : null),
                                  borderRadius: BorderRadius.circular(BhorRadius.control),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: <Widget>[
                                        Icon(on ? (items[i].activeIcon ?? items[i].icon) : items[i].icon, size: 22, color: fg),
                                        if (collapsed && items[i].badge != null)
                                          Positioned(top: -6, right: -10, child: _Badge(items[i].badge!)),
                                      ],
                                    ),
                                    if (!collapsed) ...<Widget>[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          items[i].label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: (on ? b.type.bodyStrong : b.type.body).copyWith(color: on ? c.accent : c.text),
                                        ),
                                      ),
                                      if (items[i].badge != null) _Badge(items[i].badge!),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ?footer,
              if (onToggleCollapsed != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: Align(
                    alignment: collapsed ? Alignment.center : Alignment.centerLeft,
                    child: BhorIconButton(
                      icon: collapsed ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded,
                      semanticLabel: toggleLabel ?? brand,
                      onPressed: onToggleCollapsed,
                    ),
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// Screen header: optional back button, title + subtitle (date), actions.
/// Usage: `BhorHeader(title: 'আজ', subtitle: fmt.weekdayDate(today), actions: [...])`.
/// [titleWidget] replaces the title text (a search field, a two-line roll-call
/// title); [leading] replaces the back button (e.g. a close button).
class BhorHeader extends StatelessWidget {
  const BhorHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.actions = const <Widget>[],
    this.showBack,
    this.onBack,
    this.leading,
    this.large = false,
    this.divider = false,
  }) : assert(title != null || titleWidget != null, 'BhorHeader needs a title or a titleWidget');

  final String? title;

  /// Custom title; wins over [title] and [subtitle].
  final Widget? titleWidget;
  final String? subtitle;

  /// Widget before the title instead of the automatic back button.
  final Widget? leading;
  final List<Widget> actions;

  /// Null shows the back button when the navigator can pop.
  final bool? showBack;
  final VoidCallback? onBack;

  /// Display-size title (top-level tabs).
  final bool large;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool back = leading == null && (showBack ?? (onBack != null || (ModalRoute.of(context)?.canPop ?? false)));
    final Widget titleBlock = titleWidget ??
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: large ? b.type.display : b.type.title,
              ),
            ),
            if (subtitle != null)
              Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
          ],
        );
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: EdgeInsets.fromLTRB(
          back || leading != null ? BhorSpace.s4 : BhorSpace.s16, BhorSpace.s8, BhorSpace.s8, BhorSpace.s8),
      decoration: divider ? BoxDecoration(border: Border(bottom: BorderSide(color: c.line))) : null,
      child: Row(
        children: <Widget>[
          ?leading,
          if (back)
            BhorIconButton(
              icon: Icons.arrow_back_rounded,
              semanticLabel: context.l10n.commonBack,
              color: c.text,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
          Expanded(child: titleBlock),
          ...actions,
        ],
      ),
    );
  }
}
