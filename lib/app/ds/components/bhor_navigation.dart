// Navigation chrome (docs/council/13-fluid-ui-spec.md): BhorTabs (gliding
// underline), BhorBottomNav (phone: floating pill, inset 10, r20, line edge;
// an accent-tint indicator glides between items, the active icon switches
// regular -> fill), BhorSidebar (desktop: solid brand mark, h40 r12 items, a
// gliding indicator, collapsible to icons) and BhorHeader (replaces AppBar;
// soft r13 back button).

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_button.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

/// One destination of a [BhorBottomNav] / [BhorSidebar].
class BhorNavItem {
  const BhorNavItem({required this.icon, required this.label, this.activeIcon, this.badge, this.semanticLabel});

  /// Regular-weight icon.
  final IconData icon;

  /// Fill-weight icon for the active item.
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
        style: BhorType.tabular(b.type.caption)
            .copyWith(color: b.colors.onDanger, fontWeight: FontWeight.w600, height: 1.4, fontSize: 11.5),
      ),
    );
  }
}

/// Regular -> fill icon swap: 140 ms cross-fade + scale .9 -> 1.
class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.item, required this.active, required this.color, this.size = BhorIconSize.nav});

  final BhorNavItem item;
  final bool active;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final IconData glyph = active ? (item.activeIcon ?? item.icon) : item.icon;
    final bool reduced = BhorMotion.reduced(context);
    return AnimatedSwitcher(
      duration: BhorMotion.of(context, const Duration(milliseconds: 140)),
      switchInCurve: BhorMotion.ease,
      transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(
        opacity: a,
        child: reduced ? child : ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1).animate(a), child: child),
      ),
      child: Icon(glyph, key: ValueKey<IconData>(glyph), size: size, color: color),
    );
  }
}

/// Underline tabs (scroll horizontally when they do not fit); the accent
/// underline glides to the selected tab.
/// Usage: `BhorTabs(tabs: ['শিক্ষার্থী', 'রুটিন'], index: i, onChanged: f)`.
class BhorTabs extends StatefulWidget {
  const BhorTabs({super.key, required this.tabs, required this.index, required this.onChanged});

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  State<BhorTabs> createState() => _BhorTabsState();
}

class _BhorTabsState extends State<BhorTabs> {
  final GlobalKey _rowKey = GlobalKey();
  List<GlobalKey> _keys = <GlobalKey>[];
  (double, double)? _bar;

  void _syncKeys() {
    if (_keys.length != widget.tabs.length) {
      _keys = List<GlobalKey>.generate(widget.tabs.length, (_) => GlobalKey());
    }
  }

  void _measure() {
    if (!mounted) return;
    final RenderBox? row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final int i = widget.index;
    if (row == null || i < 0 || i >= _keys.length) return;
    final RenderBox? tab = _keys[i].currentContext?.findRenderObject() as RenderBox?;
    if (tab == null || !tab.hasSize) return;
    final double left = tab.localToGlobal(Offset.zero, ancestor: row).dx + BhorSpace.s8;
    final double width = tab.size.width - 2 * BhorSpace.s8;
    if (_bar == null || (_bar!.$1 - left).abs() > 0.5 || (_bar!.$2 - width).abs() > 0.5) {
      setState(() => _bar = (left, width));
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncKeys();
    SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final (double, double)? bar = _bar;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Stack(
          key: _rowKey,
          children: <Widget>[
            Row(
              children: <Widget>[
                for (int i = 0; i < widget.tabs.length; i++)
                  KeyedSubtree(
                    key: _keys[i],
                    child: BhorPressable(
                      onTap: () => widget.onChanged(i),
                      selected: i == widget.index,
                      inMutuallyExclusiveGroup: true,
                      semanticLabel: widget.tabs[i],
                      excludeChildSemantics: true,
                      scaleOnPress: false,
                      radius: 10,
                      builder: (BuildContext context, BhorStates s) => SizedBox(
                        height: BhorSize.control,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16),
                          child: Center(
                            widthFactor: 1,
                            child: AnimatedDefaultTextStyle(
                              duration: BhorMotion.of(context, BhorMotion.fast),
                              style: (i == widget.index ? b.type.bodyStrong : b.type.body)
                                  .copyWith(color: i == widget.index ? c.accent : (s.hovered ? c.text : c.text2)),
                              child: Text(widget.tabs[i], maxLines: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (bar != null)
              AnimatedPositioned(
                duration: BhorMotion.of(context, BhorMotion.glide),
                curve: BhorMotion.curveOf(context, BhorMotion.spring),
                left: bar.$1,
                width: bar.$2,
                bottom: 0,
                height: 2.5,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Phone bottom navigation: a floating pill bar (inset 10, r20, line
/// edge) with an accent-tint indicator that glides between items (spring
/// 450 ms); the active icon switches regular -> fill.
/// Usage: `BhorBottomNav(items: [...], index: i, onTap: go)`.
class BhorBottomNav extends StatelessWidget {
  const BhorBottomNav({super.key, required this.items, required this.index, required this.onTap});

  final List<BhorNavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  /// Height of the pill itself.
  static const double pillHeight = 60;

  /// Pill + its insets (top 6, bottom 10), without the gesture-bar inset.
  static const double height = pillHeight + 16;

  static const double inset = 10;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final int n = items.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(inset, 6, inset, inset),
        child: Container(
          height: pillHeight,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(BhorRadius.nav),
            border: Border.all(color: c.line),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double w = n == 0 ? 0 : (box.maxWidth - 2) / n;
              return Stack(
                children: <Widget>[
                  if (index >= 0 && index < n)
                    AnimatedPositioned(
                      duration: BhorMotion.of(context, BhorMotion.slow),
                      curve: BhorMotion.curveOf(context, BhorMotion.spring),
                      left: index * w + 5,
                      width: w - 10,
                      top: 5,
                      bottom: 5,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.accentTint,
                            borderRadius: BorderRadius.circular(BhorRadius.control),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < n; i++)
                        Expanded(
                          child: BhorPressable(
                            onTap: () => onTap(i),
                            selected: i == index,
                            semanticLabel: items[i].a11yLabel,
                            excludeChildSemantics: true,
                            radius: BhorRadius.control,
                            pressScale: 0.92,
                            builder: (BuildContext context, BhorStates s) {
                              final bool on = i == index;
                              final Color fg = on ? c.accent : (s.hovered ? c.text : c.text2);
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: <Widget>[
                                      _NavIcon(item: items[i], active: on, color: fg),
                                      if (items[i].badge != null)
                                        PositionedDirectional(top: -6, end: -10, child: _Badge(items[i].badge!)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  AnimatedDefaultTextStyle(
                                    duration: BhorMotion.of(context, BhorMotion.fast),
                                    style: b.type.caption.copyWith(
                                      color: fg,
                                      fontSize: 12,
                                      height: 1.3,
                                      fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                                    ),
                                    child: Text(items[i].label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The solid brand mark: accent rounded square with the first grapheme of
/// [brand] ("হা"). Usage: `BhorBrandMark(brand: 'হাজিরা খাতা')`.
class BhorBrandMark extends StatelessWidget {
  const BhorBrandMark({super.key, required this.brand, this.size = 34});

  final String brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: b.colors.accentFill,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        alignment: Alignment.center,
        child: Text(
          brand.characters.isEmpty ? '' : brand.characters.first,
          style: b.type.heading.copyWith(color: b.colors.onAccentFill, height: 1.2, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Desktop sidebar: brand mark, nav items (h40 r12) with badges and an
/// accent-tint indicator that glides between them, optional [top] (e.g.
/// search) and [footer]; collapsible to icons (72 wide). Usage:
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
    this.top,
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

  /// Shown between the brand and the items (build it for [collapsed]).
  final Widget? top;

  /// Shown under the items in both states (build it for [collapsed]).
  final Widget? footer;

  static const double width = 248;
  static const double collapsedWidth = 72;
  static const double itemHeight = 40;
  static const double itemGap = 2;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final double target = collapsed ? collapsedWidth : width;
    return AnimatedContainer(
      duration: BhorMotion.of(context, BhorMotion.base),
      curve: BhorMotion.ease,
      width: target,
      decoration: BoxDecoration(color: c.surface, border: Border(right: BorderSide(color: c.line))),
      child: SafeArea(
        right: false,
        child: ClipRect(
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            // Content at the target width while the box animates (clipped).
            minWidth: target - 1,
            maxWidth: target - 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 68,
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 19),
                      BhorBrandMark(brand: brand),
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
                ?top,
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Stack(
                      children: <Widget>[
                        if (index >= 0 && index < items.length)
                          AnimatedPositioned(
                            duration: BhorMotion.of(context, BhorMotion.slow),
                            curve: BhorMotion.curveOf(context, BhorMotion.spring),
                            top: index * (itemHeight + itemGap),
                            left: 0,
                            right: 0,
                            height: itemHeight,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: c.accentTint,
                                  borderRadius: BorderRadius.circular(BhorRadius.sidebarItem),
                                ),
                              ),
                            ),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (int i = 0; i < items.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: itemGap),
                                child: BhorTooltip(
                                  message: items[i].label,
                                  enabled: collapsed,
                                  child: BhorPressable(
                                    onTap: () => onTap(i),
                                    selected: i == index,
                                    semanticLabel: items[i].a11yLabel,
                                    excludeChildSemantics: true,
                                    scaleOnPress: false,
                                    radius: BhorRadius.sidebarItem,
                                    builder: (BuildContext context, BhorStates s) {
                                      final bool on = i == index;
                                      final Color fg = on ? c.accent : (s.hovered ? c.text : c.text2);
                                      return AnimatedContainer(
                                        duration: BhorMotion.of(context, BhorMotion.instant),
                                        height: itemHeight,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: !on && (s.hovered || s.pressed) ? c.soft : c.soft.withValues(alpha: 0),
                                          borderRadius: BorderRadius.circular(BhorRadius.sidebarItem),
                                        ),
                                        child: Row(
                                          children: <Widget>[
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: <Widget>[
                                                _NavIcon(item: items[i], active: on, color: fg, size: BhorIconSize.row + 2),
                                                if (collapsed && items[i].badge != null)
                                                  PositionedDirectional(top: -6, end: -10, child: _Badge(items[i].badge!)),
                                              ],
                                            ),
                                            if (!collapsed) ...<Widget>[
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  items[i].label,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: (on ? b.type.bodyStrong : b.type.body)
                                                      .copyWith(color: on ? c.accent : c.text),
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
                      ],
                    ),
                  ),
                ),
                ?footer,
                if (onToggleCollapsed != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                    child: Align(
                      alignment: collapsed ? Alignment.center : AlignmentDirectional.centerStart,
                      child: BhorIconButton(
                        icon: collapsed ? BhorIcons.sidebarExpand : BhorIcons.sidebarCollapse,
                        semanticLabel: toggleLabel ?? brand,
                        size: BhorButtonSize.sm,
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

/// Screen header: optional back button (soft, r13), small [overline]
/// (date) above a title + subtitle, actions.
/// Usage: `BhorHeader(title: 'আজ', subtitle: fmt.weekdayDate(today), actions: [...])`,
/// `BhorHeader(overline: 'শনিবার, ২১ নভেম্বর', title: 'শুভ সকাল', large: true)`.
/// [titleWidget] replaces the title text (a search field, a two-line roll-call
/// title); [leading] replaces the back button (e.g. a close button).
class BhorHeader extends StatelessWidget {
  const BhorHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.overline,
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

  /// Small text above the title (e.g. the date over a greeting).
  final String? overline;

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
            if (overline != null)
              Text(overline!, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
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
      constraints: const BoxConstraints(minHeight: 60),
      padding: EdgeInsets.fromLTRB(
          back || leading != null ? BhorSpace.s12 : BhorSpace.s16, BhorSpace.s8, BhorSpace.s12, BhorSpace.s8),
      decoration: divider ? BoxDecoration(border: Border(bottom: BorderSide(color: c.line))) : null,
      child: Row(
        children: <Widget>[
          ?leading,
          if (back) ...<Widget>[
            BhorIconButton(
              icon: context.bhorIsWide ? BhorIcons.backDesktop : BhorIcons.back,
              semanticLabel: context.l10n.commonBack,
              variant: BhorButtonVariant.secondary,
              size: BhorButtonSize.sm,
              color: c.text,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: BhorSpace.s8),
          ],
          Expanded(child: titleBlock),
          ...actions,
        ],
      ),
    );
  }
}
