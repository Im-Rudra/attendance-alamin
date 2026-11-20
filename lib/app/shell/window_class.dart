// Material window size classes (UX 3b): 600 / 840 / 1200 / 1600.

import 'package:flutter/widgets.dart';

enum WindowClass {
  /// < 600: floating bottom pill, single pane.
  compact,

  /// 600–839: frosted rail (80dp), 2-column tiles.
  medium,

  /// 840–1199: frosted rail, list ‖ detail panes.
  expanded,

  /// 1200–1599: extended rail (220dp), list ‖ detail ‖ context.
  large,

  /// ≥ 1600: extended rail, widest layouts.
  extraLarge;

  static const double mediumMin = 600;
  static const double expandedMin = 840;
  static const double largeMin = 1200;
  static const double extraLargeMin = 1600;

  static WindowClass fromWidth(double width) {
    if (width >= extraLargeMin) return WindowClass.extraLarge;
    if (width >= largeMin) return WindowClass.large;
    if (width >= expandedMin) return WindowClass.expanded;
    if (width >= mediumMin) return WindowClass.medium;
    return WindowClass.compact;
  }

  /// Class of the whole window (not of a pane).
  static WindowClass of(BuildContext c) => fromWidth(MediaQuery.sizeOf(c).width);

  /// Wide enough for list ‖ detail panes (≥ 840).
  bool get isWide => index >= WindowClass.expanded.index;

  /// Navigation is a rail (≥ 600) rather than the bottom pill.
  bool get usesRail => this != WindowClass.compact;

  /// The rail shows labels beside the icons (≥ 1200).
  bool get extendedRail => index >= WindowClass.large.index;

  /// Outer padding and gap between tiles (UX 3b table).
  double get gutter => switch (this) {
        WindowClass.compact || WindowClass.medium || WindowClass.expanded => 16,
        WindowClass.large => 20,
        WindowClass.extraLarge => 24,
      };
}
