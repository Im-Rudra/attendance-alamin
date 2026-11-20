// Sticky group header of the dues list (UX 2d): the level badge with the
// student count, or the grey "ছেড়ে যাওয়া / আর্কাইভ" header with its
// expand / collapse toggle.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';

class DuesGroupHeader extends StatelessWidget {
  /// A severity group ("মেয়াদোত্তীর্ণ (৩)").
  const DuesGroupHeader.level({super.key, required this.level, required this.count})
      : expanded = false,
        onToggle = null;

  /// The grey group; [onToggle] expands / collapses it.
  const DuesGroupHeader.inactive({
    super.key,
    required this.count,
    required this.expanded,
    required this.onToggle,
  }) : level = null;

  final DueLevel? level;
  final int count;
  final bool expanded;
  final VoidCallback? onToggle;

  static const double extent = 52;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final TextTheme tt = Theme.of(context).textTheme;
    final double g = WindowClass.of(context).gutter;
    final String countText = l10n.duesGroupCount(context.fmt.number(count));
    final DueLevel? lv = level;
    final Widget title;
    if (lv != null) {
      title = Row(
        children: <Widget>[
          Flexible(child: SeverityBadge(level: lv)),
          const SizedBox(width: 8),
          Text(countText, style: tt.titleSmall?.copyWith(color: tokens.textSecondary)),
        ],
      );
    } else {
      title = Row(
        children: <Widget>[
          Icon(Icons.inventory_2_outlined, size: 20, color: tokens.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                l10n.duesInactiveGroup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(color: tokens.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(countText, style: tt.titleSmall?.copyWith(color: tokens.textSecondary)),
        ],
      );
    }
    final Widget row = Row(
      children: <Widget>[
        Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: title)),
        if (onToggle != null)
          IconButton(
            tooltip: expanded ? l10n.duesCollapse : l10n.duesExpand,
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onPressed: onToggle,
          ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceSolid.withValues(alpha: 0.96),
        border: Border(bottom: BorderSide(color: tokens.hairline)),
      ),
      child: SizedBox(
        height: extent,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: g),
          child: row,
        ),
      ),
    );
  }
}

/// Pins a [DuesGroupHeader] to the top while its group scrolls.
class DuesGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  const DuesGroupHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => DuesGroupHeader.extent;

  @override
  double get maxExtent => DuesGroupHeader.extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant DuesGroupHeaderDelegate oldDelegate) => true;
}
