// The navigation shell (UX 1, 3b; Bhor: docs/council/10-design-system-bhor.md).
//
// - compact (< 600): BhorScaffold + BhorBottomNav, a flat bar with a top
//   hairline; the active icon sits in an accent-tint pill. Hidden while the
//   keyboard is open. Bottom toasts are lifted above it (BhorToastInset).
// - medium / expanded (600–1199): BhorSidebar collapsed to icons (72).
// - large / extra-large (≥ 1200): the full BhorSidebar (brand, labels,
//   badges, 248), collapsible to icons.
// The বেতন item carries the number of overdue students. Desktop keys:
// Ctrl+1…5 destinations, Ctrl+F / Ctrl+K search, `?` shortcut list.

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class AdaptiveScaffold extends ConsumerStatefulWidget {
  const AdaptiveScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const Key bottomNavKey = Key('shell-bottom-nav');
  static const Key sidebarKey = Key('shell-sidebar');

  /// Height of the phone bottom nav (without the gesture-bar inset).
  static const double bottomNavHeight = 64;

  @override
  ConsumerState<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends ConsumerState<AdaptiveScaffold> {
  /// The user folded the full sidebar to icons (large windows).
  bool _collapsed = false;

  StatefulNavigationShell get _shell => widget.navigationShell;

  void _select(int index) => _shell.goBranch(index, initialLocation: index == _shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final WindowClass wc = WindowClass.of(context);
    final AppLocalizations l10n = context.l10n;
    // The বেতন item carries the number of overdue students (UX 1).
    final int overdue = ref.watch(duesReportProvider).value?.overdueStudents ?? 0;
    final List<BhorNavItem> items = _items(context, l10n, overdue);
    final int index = _shell.currentIndex;
    final Widget scaffold;
    if (!wc.usesRail) {
      final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      scaffold = BhorScaffold(
        wash: false,
        body: BhorToastInset(
          bottom: keyboardOpen ? 0 : AdaptiveScaffold.bottomNavHeight,
          child: _shell,
        ),
        bottomNav: keyboardOpen
            ? null
            : MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: BhorBottomNav(
                  key: AdaptiveScaffold.bottomNavKey,
                  items: items,
                  index: index,
                  onTap: _select,
                ),
              ),
      );
    } else {
      final bool canExtend = wc.extendedRail;
      final bool collapsed = !canExtend || _collapsed;
      scaffold = BhorScaffold(
        wash: false,
        sidebar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: BhorSidebar(
            key: AdaptiveScaffold.sidebarKey,
            brand: l10n.commonAppTitle,
            items: items,
            index: index,
            onTap: _select,
            collapsed: collapsed,
            onToggleCollapsed: canExtend ? () => setState(() => _collapsed = !_collapsed) : null,
            toggleLabel: collapsed ? l10n.shellRailExpand : l10n.shellRailCollapse,
            footer: _SidebarSearch(collapsed: collapsed),
          ),
        ),
        body: _shell,
      );
    }
    return _ShellKeys(onSelect: _select, child: scaffold);
  }

  static List<BhorNavItem> _items(BuildContext context, AppLocalizations l10n, int overdue) {
    final String? badge = overdue <= 0
        ? null
        : overdue > 99
            ? '${context.fmt.number(99)}+'
            : context.fmt.number(overdue);
    return <BhorNavItem>[
      BhorNavItem(icon: Icons.today_outlined, activeIcon: Icons.today, label: l10n.navToday),
      BhorNavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups, label: l10n.navBatches),
      BhorNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: l10n.navStudents),
      BhorNavItem(
        icon: Icons.payments_outlined,
        activeIcon: Icons.payments,
        label: l10n.navFees,
        badge: badge,
        // What a screen reader says: the label plus "Overdue 3".
        semanticLabel: badge == null ? null : '${l10n.navFees}, ${l10n.uiOverdueCount(context.fmt.number(overdue))}',
      ),
      BhorNavItem(icon: Icons.menu, label: l10n.navMore),
    ];
  }
}

/// Global search under the sidebar items: an icon when collapsed, an icon
/// and the word when the sidebar is full width.
class _SidebarSearch extends StatelessWidget {
  const _SidebarSearch({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final String label = context.l10n.commonSearch;
    void open() => context.push(Routes.search);
    return Padding(
      padding: const EdgeInsets.fromLTRB(BhorSpace.s12, BhorSpace.s4, BhorSpace.s12, BhorSpace.s4),
      child: Align(
        alignment: collapsed ? Alignment.center : AlignmentDirectional.centerStart,
        child: collapsed
            ? BhorIconButton(icon: Icons.search, semanticLabel: label, onPressed: open)
            : BhorButton(
                label: label,
                icon: Icons.search,
                variant: BhorButtonVariant.ghost,
                onPressed: open,
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

/// The `?` dialog: keyboard shortcuts handled by the shell.
Future<void> showShortcutHelp(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  final List<(String, String)> rows = <(String, String)>[
    (l10n.shellKeysDestinations, l10n.shellShortcutDestinations),
    (l10n.shellKeysSearch, l10n.shellShortcutSearch),
    (l10n.shellKeysHelp, l10n.shellShortcutHelp),
  ];
  return showBhorDialog<void>(
    context,
    builder: (BuildContext ctx) {
      final BhorThemeData b = ctx.bhor;
      return BhorDialog(
        title: l10n.shellShortcutsTitle,
        body: Column(
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
                        color: b.colors.surface2,
                        borderRadius: BorderRadius.circular(BhorRadius.tag),
                        border: Border.all(color: b.colors.line),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(keys, style: BhorType.tabular(b.type.label)),
                      ),
                    ),
                    const SizedBox(width: BhorSpace.s12),
                    Expanded(child: Text(what, style: b.type.body)),
                  ],
                ),
              ),
          ],
        ),
        actions: <Widget>[
          BhorButton(
            label: l10n.commonClose,
            variant: BhorButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      );
    },
  );
}
