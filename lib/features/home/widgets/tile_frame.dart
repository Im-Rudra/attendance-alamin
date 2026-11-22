// The shell of every Today tile: a Bhor card with an optional header. Inside
// the bento (bounded height) the body fills the tile and scrolls instead of
// overflowing; inside a scrolling page (unbounded height) it wraps its content.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class TileFrame extends StatelessWidget {
  const TileFrame({
    super.key,
    this.header,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(BhorSpace.s16),
    this.scroll = true,
  });

  final Widget? header;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Wrap [child] in a scroll view that fills the tile (the child may then
  /// centre itself or use `spaceBetween`). Pass false when [child] scrolls on
  /// its own.
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    return BhorCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final Widget? head = header;
          final Widget body;
          if (c.hasBoundedHeight) {
            final Widget fill = scroll ? _FillScroll(child: child) : child;
            body = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (head != null) ...<Widget>[head, const SizedBox(height: BhorSpace.s8)],
                Expanded(child: fill),
              ],
            );
          } else {
            body = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (head != null) ...<Widget>[head, const SizedBox(height: BhorSpace.s8)],
                child,
              ],
            );
          }
          return Padding(padding: padding, child: body);
        },
      ),
    );
  }
}

class _FillScroll extends StatelessWidget {
  const _FillScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) => SingleChildScrollView(
        primary: false,
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

/// Icon, title and an optional trailing widget on one line.
class TileHeader extends StatelessWidget {
  const TileHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 28),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(child: Icon(icon, size: 20, color: b.colors.accent)),
          const SizedBox(width: BhorSpace.s8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: b.type.heading,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[const SizedBox(width: BhorSpace.s8), trailing!],
        ],
      ),
    );
  }
}

/// A small centred message for an empty tile: icon over one sentence. Meant
/// as the child of a [TileFrame] so it fills the tile.
class TileMessage extends StatelessWidget {
  const TileMessage({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // The shared compact empty state: it hugs its content, so an empty card
    // stays small (review T1).
    return Center(
      child: BhorEmptyState(
        size: BhorEmptySize.compact,
        icon: icon,
        title: message,
        action: action,
      ),
    );
  }
}
