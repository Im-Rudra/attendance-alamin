// One menu component for every ⋮ / ⋯ / "New…" menu (docs/council/16 W1-A,
// G8): an anchored popover at its trigger on desktop (a small centred card
// when there is no trigger), a bottom sheet on phones. No title header and
// no ✕; an icon on every item; destructive items red, last, after a
// divider. Keyboard: ↑ / ↓ (also Home / End) move, Enter / Space pick,
// Esc closes.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_overlays.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';

/// One row of a [showBhorMenu] menu. [onTap] runs after the menu has
/// closed; null shows the row disabled.
class BhorMenuItem {
  const BhorMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Red, and placed last after a divider.
  final bool destructive;

  /// Key of the row (tests and automation tap it).
  final Key? key;
}

/// [items] in menu order: the normal ones as given, then the destructive
/// ones.
List<BhorMenuItem> bhorMenuOrder(List<BhorMenuItem> items) => <BhorMenuItem>[
      for (final BhorMenuItem i in items)
        if (!i.destructive) i,
      for (final BhorMenuItem i in items)
        if (i.destructive) i,
    ];

/// Opens a menu of [items] at the control that opened it (see
/// [bhorAnchorRect]: a button's own context, [anchor], or the control just
/// pressed inside [context]) and runs the picked item's `onTap` after the
/// menu has closed. Desktop: an anchored popover (a small centred card when
/// there is no anchor). Phone: a bottom sheet.
/// Usage:
/// `showBhorMenu(context, items: <BhorMenuItem>[BhorMenuItem(icon: BhorIcons.edit, label: l10n.commonEdit, onTap: _edit), BhorMenuItem(icon: BhorIcons.delete, label: l10n.commonDelete, onTap: _delete, destructive: true)])`.
Future<void> showBhorMenu(
  BuildContext context, {
  required List<BhorMenuItem> items,
  BuildContext? anchor,
  double width = 260,
}) async {
  final List<BhorMenuItem> ordered = bhorMenuOrder(items);
  Widget menu(BuildContext ctx) => BhorMenu(items: ordered, onPick: (int i) => Navigator.of(ctx).pop(i));
  int? picked;
  if (context.bhorIsWide) {
    if (bhorAnchorRect(anchor ?? context) != null) {
      picked = await showBhorPopover<int>(
        context,
        anchor: anchor,
        width: width,
        padding: const EdgeInsets.fromLTRB(BhorSpace.s4, 0, BhorSpace.s4, BhorSpace.s4),
        builder: menu,
      );
    } else {
      picked = await showBhorDialog<int>(
        context,
        builder: (BuildContext ctx) => _MenuCard(width: width + 40, child: menu(ctx)),
      );
    }
  } else {
    picked = await showBhorSheet<int>(
      context,
      builder: (BuildContext ctx) => SingleChildScrollView(child: menu(ctx)),
    );
  }
  if (picked != null && picked >= 0 && picked < ordered.length) ordered[picked].onTap?.call();
}

/// The menu rows (usable inline, e.g. in the gallery and tests). [items]
/// are shown in the given order with a divider before the first
/// destructive one; [onPick] gets the index of the picked row.
class BhorMenu extends StatefulWidget {
  const BhorMenu({super.key, required this.items, required this.onPick});

  final List<BhorMenuItem> items;
  final ValueChanged<int> onPick;

  @override
  State<BhorMenu> createState() => _BhorMenuState();
}

class _BhorMenuState extends State<BhorMenu> {
  final FocusNode _list = FocusNode(debugLabel: 'bhor-menu', skipTraversal: true);
  List<FocusNode> _nodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _syncNodes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Opened from the keyboard: start on the first row; otherwise hold
      // the focus on the list so ↑ / ↓ work right away.
      if (FocusManager.instance.highlightMode == FocusHighlightMode.traditional) {
        _move(1);
      } else if (!_list.hasFocus) {
        _list.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(BhorMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) _syncNodes();
  }

  void _syncNodes() {
    final List<FocusNode> old = _nodes;
    _nodes = <FocusNode>[
      for (int i = 0; i < widget.items.length; i++)
        i < old.length ? old[i] : FocusNode(debugLabel: 'bhor-menu-$i'),
    ];
    for (int i = widget.items.length; i < old.length; i++) {
      old[i].dispose();
    }
  }

  @override
  void dispose() {
    for (final FocusNode n in _nodes) {
      n.dispose();
    }
    _list.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final List<int> enabled = <int>[
      for (int i = 0; i < widget.items.length; i++)
        if (widget.items[i].onTap != null) i,
    ];
    if (enabled.isEmpty) return;
    final int current = enabled.indexWhere((int i) => _nodes[i].hasPrimaryFocus);
    final int next = current < 0
        ? (delta > 0 ? 0 : enabled.length - 1)
        : (current + delta) % enabled.length;
    _nodes[enabled[next < 0 ? next + enabled.length : next]].requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _focusEdge(first: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _focusEdge(first: false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusEdge({required bool first}) {
    for (int k = 0; k < widget.items.length; k++) {
      final int i = first ? k : widget.items.length - 1 - k;
      if (widget.items[i].onTap != null) {
        _nodes[i].requestFocus();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final double rowHeight = context.bhorIsWide ? 40 : BhorSize.phoneRow;
    final int firstDanger = widget.items.indexWhere((BhorMenuItem i) => i.destructive);
    return Focus(
      focusNode: _list,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < widget.items.length; i++) ...<Widget>[
            if (i == firstDanger && i > 0)
              Padding(
                key: const ValueKey<String>('bhor-menu-divider'),
                padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4, horizontal: BhorSpace.s8),
                child: SizedBox(height: 1, child: ColoredBox(color: c.line)),
              ),
            _MenuRow(
              item: widget.items[i],
              focusNode: _nodes[i],
              height: rowHeight,
              onTap: widget.items[i].onTap == null ? null : () => widget.onPick(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.focusNode, required this.height, required this.onTap});

  final BhorMenuItem item;
  final FocusNode focusNode;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return BhorPressable(
      key: item.key,
      focusNode: focusNode,
      onTap: onTap,
      semanticLabel: item.label,
      excludeChildSemantics: true,
      radius: BhorRadius.chip,
      scaleOnPress: false,
      builder: (BuildContext context, BhorStates st) {
        final Color fg = !st.enabled
            ? c.text3
            : item.destructive
                ? c.danger
                : c.text;
        final Color bg = st.pressed
            ? c.soft2
            : (st.hovered || st.focused)
                ? (item.destructive ? c.dangerBg : c.soft)
                : const Color(0x00000000);
        return AnimatedContainer(
          duration: BhorMotion.of(context, BhorMotion.fast),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BhorRadius.chip)),
          child: Row(
            children: <Widget>[
              Icon(item.icon, size: 18, color: fg),
              const SizedBox(width: BhorSpace.s12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: b.type.body.copyWith(color: fg),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The no-anchor desktop menu: a small floating card (no title, no ✕).
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    return Container(
      margin: const EdgeInsets.all(BhorSpace.s16),
      constraints: BoxConstraints(maxWidth: width),
      padding: const EdgeInsets.all(BhorSpace.s4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(BhorRadius.card),
        border: Border.all(color: c.line),
        boxShadow: c.floatShadow,
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}
