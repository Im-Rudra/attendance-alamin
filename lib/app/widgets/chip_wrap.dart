// A free-flowing row of chips that animates when a chip's check grows it and
// re-wraps the row, instead of jumping (visual QA C9). Use it only for
// free-flowing chips, not fixed-width day grids.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

/// A [Wrap] whose height change animates.
class ChipWrap extends StatelessWidget {
  const ChipWrap({
    super.key,
    required this.children,
    this.spacing = BhorSpace.s8,
    this.runSpacing = BhorSpace.s8,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: BhorMotion.of(context, BhorMotion.fast),
        curve: BhorMotion.ease,
        alignment: AlignmentDirectional.topStart,
        child: Wrap(spacing: spacing, runSpacing: runSpacing, children: children),
      );
}
