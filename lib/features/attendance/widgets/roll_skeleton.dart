// What the roll call shows while its data loads: grey placeholder rows in the
// shape of the real ones, so the screen has its final layout from the first
// frame instead of a bare spinner.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';

class RollSkeleton extends StatelessWidget {
  const RollSkeleton({super.key, this.rows = 8});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final double g = WindowClass.of(context).gutter;
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusDenseList);
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: tokens.track, borderRadius: BorderRadius.circular(6)),
        );
    return ExcludeSemantics(
      child: ListView(
        key: const Key('roll-skeleton'),
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(g, 8, g, g),
        children: <Widget>[
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: tokens.surfaceDense, borderRadius: br),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: tokens.track, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[bar(140, 14), const SizedBox(height: 8), bar(40, 10)],
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
