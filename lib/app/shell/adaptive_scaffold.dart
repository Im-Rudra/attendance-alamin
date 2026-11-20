// The navigation shell (UX 1, 3b, 4 "Floating nav").
//
// - compact (< 600): a floating frosted pill (glassNav, 64dp, inset 12dp from
//   the edges and above the gesture bar); the selected item sits in an
//   accentContainer pill. Hidden while the keyboard is open.
// - medium / expanded (600–1199): a full-height frosted rail, 80dp, icons +
//   labels.
// - large / extra-large (≥ 1200): an extended rail with labels, 220dp,
//   collapsible to 80dp.
// Desktop keys: Ctrl+1…5 destinations, Ctrl+F / Ctrl+K search, `?` shortcut
// list. The mesh is painted once behind the whole window by App.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const Key pillKey = Key('shell-nav-pill');
  static const Key railKey = Key('shell-nav-rail');

  void _select(int index) =>
      navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final WindowClass wc = WindowClass.of(context);
    final List<_Destination> dests = _Destination.all(context.l10n);
    final int index = navigationShell.currentIndex;
    final Widget scaffold;
    if (!wc.usesRail) {
      final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      scaffold = Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        body: navigationShell,
        bottomNavigationBar: keyboardOpen
            ? null
            : _NavPill(key: pillKey, destinations: dests, index: index, onSelect: _select),
      );
    } else {
      scaffold = Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _NavRail(
              key: railKey,
              destinations: dests,
              index: index,
              onSelect: _select,
              canExtend: wc.extendedRail,
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    return _ShellKeys(onSelect: _select, child: scaffold);
  }
}

class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  static List<_Destination> all(AppLocalizations l10n) => <_Destination>[
        _Destination(Icons.today_outlined, Icons.today, l10n.navToday),
        _Destination(Icons.groups_outlined, Icons.groups, l10n.navBatches),
        _Destination(Icons.person_outline, Icons.person, l10n.navStudents),
        _Destination(Icons.payments_outlined, Icons.payments, l10n.navFees),
        _Destination(Icons.menu, Icons.menu, l10n.navMore),
      ];
}

/// Frosted navigation surface: glassNav + blur σ24, or the solid fallback in
/// reduced-effects mode.
class _Frosted extends StatelessWidget {
  const _Frosted({required this.borderRadius, required this.border, required this.child});

  final BorderRadius borderRadius;
  final Border border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final bool reduced = EffectsMode.reducedOf(context);
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: reduced ? tokens.surfaceSolid.withValues(alpha: 0.92) : tokens.glassNav,
        borderRadius: borderRadius,
        border: border,
      ),
      child: child,
    );
    if (!reduced) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AuroraMetrics.blurNav, sigmaY: AuroraMetrics.blurNav),
        child: surface,
      );
    }
    return ClipRRect(borderRadius: borderRadius, child: surface);
  }
}

// ---------------------------------------------------------------------------
// Phone: floating pill

class _NavPill extends StatelessWidget {
  const _NavPill({super.key, required this.destinations, required this.index, required this.onSelect});

  final List<_Destination> destinations;
  final int index;
  final ValueChanged<int> onSelect;

  static const double height = 64;
  static const double inset = 12;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final double bottom = MediaQuery.viewPaddingOf(context).bottom;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, inset + bottom),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuroraMetrics.radiusPill),
            boxShadow: <BoxShadow>[
              BoxShadow(color: tokens.scrim.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: _Frosted(
            borderRadius: BorderRadius.circular(AuroraMetrics.radiusPill),
            border: Border.all(color: tokens.hairline),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _PillItem(
                          destination: destinations[i],
                          selected: i == index,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const _PillItem({required this.destination, required this.selected, required this.onTap});

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final Color fg = selected ? tokens.onAccentContainer : tokens.textSecondary;
    final TextStyle? style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        );
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: selected ? tokens.accentContainer : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(selected ? destination.selectedIcon : destination.icon, size: 22, color: fg),
                const SizedBox(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(destination.label, maxLines: 1, style: style),
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

// ---------------------------------------------------------------------------
// Tablet / desktop: frosted rail

class _NavRail extends StatefulWidget {
  const _NavRail({
    super.key,
    required this.destinations,
    required this.index,
    required this.onSelect,
    required this.canExtend,
  });

  final List<_Destination> destinations;
  final int index;
  final ValueChanged<int> onSelect;

  /// The window is wide enough for the 220dp labelled rail.
  final bool canExtend;

  static const double width = 80;
  static const double extendedWidth = 220;

  @override
  State<_NavRail> createState() => _NavRailState();
}

class _NavRailState extends State<_NavRail> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final bool extended = widget.canExtend && !_collapsed;
    final TextTheme tt = Theme.of(context).textTheme;

    final Widget header;
    if (extended) {
      header = Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.commonAppTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleMedium?.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: l10n.shellRailCollapse,
              icon: const Icon(Icons.menu_open),
              onPressed: () => setState(() => _collapsed = true),
            ),
          ],
        ),
      );
    } else if (widget.canExtend) {
      header = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: IconButton(
          tooltip: l10n.shellRailExpand,
          icon: const Icon(Icons.menu),
          onPressed: () => setState(() => _collapsed = false),
        ),
      );
    } else {
      header = const SizedBox(height: 20);
    }

    final Widget search = extended
        ? _RailItem(
            destination: _Destination(Icons.search, Icons.search, l10n.commonSearch),
            selected: false,
            extended: true,
            onTap: () => context.push(Routes.search),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: IconButton(
              tooltip: l10n.commonSearch,
              icon: Icon(Icons.search, color: tokens.textSecondary),
              onPressed: () => context.push(Routes.search),
            ),
          );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox(
        width: extended ? _NavRail.extendedWidth : _NavRail.width,
        child: _Frosted(
          borderRadius: BorderRadius.zero,
          border: Border(right: BorderSide(color: tokens.hairline)),
          child: SafeArea(
            right: false,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      header,
                      for (int i = 0; i < widget.destinations.length; i++)
                        _RailItem(
                          destination: widget.destinations[i],
                          selected: i == widget.index,
                          extended: extended,
                          onTap: () => widget.onSelect(i),
                        ),
                      const SizedBox(height: 8),
                      search,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final Color fg = selected ? tokens.onAccentContainer : tokens.textSecondary;
    final TextTheme tt = Theme.of(context).textTheme;
    final Widget icon = Icon(selected ? destination.selectedIcon : destination.icon, size: 24, color: fg);
    final Color fill = selected ? tokens.accentContainer : Colors.transparent;

    final Widget content;
    if (extended) {
      content = Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: ShapeDecoration(shape: const StadiumBorder(), color: fill),
        child: Row(
          children: <Widget>[
            icon,
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(color: selected ? fg : tokens.textPrimary),
              ),
            ),
          ],
        ),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              height: 32,
              decoration: ShapeDecoration(shape: const StadiumBorder(), color: fill),
              child: icon,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  destination.label,
                  maxLines: 1,
                  style: tt.labelMedium?.copyWith(color: selected ? fg : tokens.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: extended ? const StadiumBorder() : null,
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop keys

/// Window-wide shortcuts, active while the shell is the top route. Character
/// keys are ignored while a text field has focus.
class _ShellKeys extends StatefulWidget {
  const _ShellKeys({required this.onSelect, required this.child});

  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  State<_ShellKeys> createState() => _ShellKeysState();
}

class _ShellKeysState extends State<_ShellKeys> {
  static final List<LogicalKeyboardKey> _digits = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
  ];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _typing() {
    final BuildContext? ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final HardwareKeyboard kb = HardwareKeyboard.instance;
    if (kb.isControlPressed && !kb.isAltPressed) {
      final int digit = _digits.indexOf(event.logicalKey);
      if (digit >= 0) {
        widget.onSelect(digit);
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyF || event.logicalKey == LogicalKeyboardKey.keyK) {
        GoRouter.of(context).push(Routes.search);
        return true;
      }
      return false;
    }
    if (event.character == '?' && !_typing()) {
      showShortcutHelp(context);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The `?` sheet: keyboard shortcuts handled by the shell.
Future<void> showShortcutHelp(BuildContext context) {
  final l10n = context.l10n;
  final List<(String, String)> rows = <(String, String)>[
    (l10n.shellKeysDestinations, l10n.shellShortcutDestinations),
    (l10n.shellKeysSearch, l10n.shellShortcutSearch),
    (l10n.shellKeysHelp, l10n.shellShortcutHelp),
  ];
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      final tokens = ctx.aurora;
      final TextTheme tt = Theme.of(ctx).textTheme;
      return AlertDialog(
        title: Text(l10n.shellShortcutsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (String keys, String what) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.track,
                        borderRadius: BorderRadius.circular(AuroraMetrics.radiusChip),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(keys, style: tt.labelMedium?.copyWith(color: tokens.textPrimary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(what, style: tt.bodyMedium?.copyWith(color: tokens.textPrimary))),
                  ],
                ),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.commonClose)),
        ],
      );
    },
  );
}
