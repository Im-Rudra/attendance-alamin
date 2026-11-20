// The Today bento (UX 3b): which tile sits where for each window class. Pure
// data so a test can check that every row sums to 12 columns.

import 'package:attendance_alamin/app/shell/window_class.dart';

enum TodayTile {
  hero,
  dues,
  timeline,
  collection,
  attendance,
  alerts,
  quick,
  backup,
  recent,
  week,
}

class TileSlot {
  const TileSlot(this.tile, this.col, this.row, this.colSpan, [this.rowSpan = 1]);

  final TodayTile tile;

  /// Zero-based column / row, spans in columns / rows (12-column grid).
  final int col;
  final int row;
  final int colSpan;
  final int rowSpan;
}

/// The tiles of the bento at [wc] (expanded and wider only).
List<TileSlot> bentoSlots(WindowClass wc) {
  switch (wc) {
    case WindowClass.compact:
    case WindowClass.medium:
    case WindowClass.expanded:
      return const <TileSlot>[
        TileSlot(TodayTile.hero, 0, 0, 7),
        TileSlot(TodayTile.dues, 7, 0, 5),
        TileSlot(TodayTile.timeline, 0, 1, 7, 2),
        TileSlot(TodayTile.collection, 7, 1, 5),
        TileSlot(TodayTile.attendance, 7, 2, 5),
        TileSlot(TodayTile.alerts, 0, 3, 5),
        TileSlot(TodayTile.quick, 5, 3, 4),
        TileSlot(TodayTile.backup, 9, 3, 3),
      ];
    case WindowClass.large:
      return const <TileSlot>[
        TileSlot(TodayTile.hero, 0, 0, 5),
        TileSlot(TodayTile.dues, 5, 0, 4),
        TileSlot(TodayTile.collection, 9, 0, 3),
        TileSlot(TodayTile.timeline, 0, 1, 5, 2),
        TileSlot(TodayTile.attendance, 5, 1, 4),
        TileSlot(TodayTile.alerts, 9, 1, 3),
        TileSlot(TodayTile.recent, 5, 2, 4),
        TileSlot(TodayTile.backup, 9, 2, 3),
      ];
    case WindowClass.extraLarge:
      return const <TileSlot>[
        TileSlot(TodayTile.hero, 0, 0, 4),
        TileSlot(TodayTile.dues, 4, 0, 5),
        TileSlot(TodayTile.collection, 9, 0, 3),
        TileSlot(TodayTile.timeline, 0, 1, 4, 2),
        TileSlot(TodayTile.week, 4, 1, 5),
        TileSlot(TodayTile.attendance, 9, 1, 3),
        TileSlot(TodayTile.alerts, 4, 2, 3),
        TileSlot(TodayTile.recent, 7, 2, 3),
        TileSlot(TodayTile.backup, 10, 2, 2),
      ];
  }
}

/// Number of bento rows at [wc].
int bentoRowCount(WindowClass wc) {
  var rows = 0;
  for (final TileSlot s in bentoSlots(wc)) {
    final int end = s.row + s.rowSpan;
    if (end > rows) rows = end;
  }
  return rows;
}

/// Quick actions live in their own tile only at the expanded class; larger
/// windows move them into the top bar.
bool quickActionsInTopBar(WindowClass wc) =>
    wc == WindowClass.large || wc == WindowClass.extraLarge;
