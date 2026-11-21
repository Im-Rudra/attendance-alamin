// What the roll call shows while its data loads: grey placeholder rows in the
// shape of the real ones, so the screen has its final layout from the first
// frame instead of a bare spinner.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';

class RollSkeleton extends StatelessWidget {
  const RollSkeleton({super.key, this.rows = 8});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    final double g = WindowClass.of(context).gutter;
    final BorderRadius br = BorderRadius.circular(BhorRadius.card);
    // Static on purpose: a looping shimmer would keep pumpAndSettle busy.
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(BhorRadius.tag)),
        );
    return ExcludeSemantics(
      child: ListView(
        key: const Key('roll-skeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(g, BhorSpace.s8, g, g),
        children: <Widget>[
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: BhorSpace.s8),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: br,
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: BhorSpace.s12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[bar(140, 14), const SizedBox(height: BhorSpace.s8), bar(40, 10)],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
