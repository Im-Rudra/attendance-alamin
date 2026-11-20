// Bento grid (UX 3b "Today bento"): 12 columns, every row's spans sum to 12,
// all tiles of a row have equal height, edges align on both axes.
//
// Row-unit height = max(minRowUnit, (available height - gutters) / 3) so a
// bento with 3 rows fills the window exactly; with more rows (or a short
// window) the grid scrolls by itself. A tile spanning N rows is
// N units + (N - 1) gutters tall.

import 'package:flutter/material.dart';

/// One tile. [col] and [row] are ZERO-based; spans are in columns / rows.
class BentoPlacement {
  const BentoPlacement({
    required this.col,
    required this.row,
    required this.colSpan,
    this.rowSpan = 1,
    required this.child,
  });

  final int col;
  final int row;
  final int colSpan;
  final int rowSpan;
  final Widget child;
}

class BentoGrid extends StatelessWidget {
  const BentoGrid({
    super.key,
    required this.placements,
    required this.rowCount,
    required this.gutter,
    this.columns = 12,
    this.minRowUnit = 184,
  });

  final List<BentoPlacement> placements;
  final int rowCount;
  final double gutter;
  final int columns;
  final double minRowUnit;

  /// Returns null when the placements tile the [rowCount] x [columns] grid
  /// exactly (no overlap, no hole, nothing out of range), else a message that
  /// names the first problem (for example "row 1 sums to 11, not 12").
  static String? validate(List<BentoPlacement> placements, int rowCount, int columns) {
    if (rowCount < 1 || columns < 1) return 'rowCount and columns must be positive';
    final List<List<int>> owner = <List<int>>[
      for (int r = 0; r < rowCount; r++) List<int>.filled(columns, -1),
    ];
    for (int i = 0; i < placements.length; i++) {
      final BentoPlacement p = placements[i];
      if (p.colSpan < 1 || p.rowSpan < 1) return 'placement $i has an empty span';
      if (p.col < 0 || p.row < 0 || p.col + p.colSpan > columns || p.row + p.rowSpan > rowCount) {
        return 'placement $i leaves the $rowCount x $columns grid';
      }
      for (int r = p.row; r < p.row + p.rowSpan; r++) {
        for (int c = p.col; c < p.col + p.colSpan; c++) {
          if (owner[r][c] != -1) return 'placements ${owner[r][c]} and $i overlap at row $r, column $c';
          owner[r][c] = i;
        }
      }
    }
    for (int r = 0; r < rowCount; r++) {
      final int covered = owner[r].where((int o) => o != -1).length;
      if (covered != columns) return 'row $r sums to $covered, not $columns';
    }
    return null;
  }

  /// Height of one row unit for [availableHeight] (null or infinite = unbounded).
  static double rowUnit({
    required double? availableHeight,
    required int rowCount,
    required double gutter,
    required double minRowUnit,
  }) {
    if (availableHeight == null || availableHeight.isInfinite) return minRowUnit;
    final int divisor = rowCount < 1 ? 1 : (rowCount > 3 ? 3 : rowCount);
    final double u = (availableHeight - (divisor - 1) * gutter) / divisor;
    return u > minRowUnit ? u : minRowUnit;
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      final String? problem = validate(placements, rowCount, columns);
      if (problem != null) throw AssertionError('BentoGrid: $problem');
      return true;
    }());
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double width = c.maxWidth;
        final double cw = (width - gutter * (columns - 1)) / columns;
        final double unit = rowUnit(
          availableHeight: c.hasBoundedHeight ? c.maxHeight : null,
          rowCount: rowCount,
          gutter: gutter,
          minRowUnit: minRowUnit,
        );
        final double total = rowCount * unit + (rowCount - 1) * gutter;
        final Widget grid = SizedBox(
          width: width,
          height: total,
          child: Stack(
            children: <Widget>[
              for (final BentoPlacement p in placements)
                Positioned(
                  left: p.col * (cw + gutter),
                  top: p.row * (unit + gutter),
                  width: p.colSpan * cw + (p.colSpan - 1) * gutter,
                  height: p.rowSpan * unit + (p.rowSpan - 1) * gutter,
                  child: p.child,
                ),
            ],
          ),
        );
        if (c.hasBoundedHeight && total > c.maxHeight + 0.5) {
          return SingleChildScrollView(primary: false, child: grid);
        }
        return grid;
      },
    );
  }
}
