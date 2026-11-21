// Sticky group header of the dues list (UX 2d): the level tag with the
// student count, or the grey "ছেড়ে যাওয়া / আর্কাইভ" header with its
// expand / collapse toggle.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_tags.dart';

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
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final String countText = l10n.duesGroupCount(context.fmt.number(count));
    final DueLevel? lv = level;
    final Widget title;
    if (lv != null) {
      title = Row(
        children: <Widget>[
          Flexible(child: dueLevelTag(context, lv)),
          const SizedBox(width: BhorSpace.s8),
          Text(countText, style: b.type.bodyStrong.copyWith(color: b.colors.text2)),
        ],
      );
    } else {
      title = Row(
        children: <Widget>[
          Icon(BhorIcons.archive, size: 20, color: b.colors.text2),
          const SizedBox(width: BhorSpace.s8),
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                l10n.duesInactiveGroup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: b.type.bodyStrong.copyWith(color: b.colors.text2),
              ),
            ),
          ),
          const SizedBox(width: BhorSpace.s8),
          Text(countText, style: b.type.bodyStrong.copyWith(color: b.colors.text2)),
        ],
      );
    }
    final Widget row = Row(
      children: <Widget>[
        Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: title)),
        if (onToggle != null)
          BhorIconButton(
            key: const ValueKey<String>('dues-group-toggle'),
            icon: expanded ? BhorIcons.chevronUp : BhorIcons.chevronDown,
            semanticLabel: expanded ? l10n.duesCollapse : l10n.duesExpand,
            onPressed: onToggle,
          ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: b.colors.bg,
        border: Border(bottom: BorderSide(color: b.colors.line)),
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
