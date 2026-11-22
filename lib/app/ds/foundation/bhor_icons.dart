// BhorIcons: the app's icon set, Phosphor (phosphor_flutter, pinned in
// pubspec). Regular weight for UI, Fill for the active nav item and status
// glyphs; Bold never (12-ux-review.md section 1.4). Sizes 16 / 18 / 20 / 24
// ([BhorIconSize]). Screens use these names instead of Material `Icons.*`:
// `Icon(BhorIcons.search)`, `BhorNavItem(icon: BhorIcons.today, activeIcon: BhorIcons.todayFill)`.

import 'package:flutter/widgets.dart';

/// Icon sizes: inline meta 16, chips/tags 18, rows/buttons 20, nav 24.
abstract final class BhorIconSize {
  static const double inline = 16;
  static const double chip = 18;
  static const double row = 20;
  static const double nav = 24;
}

/// Regular / Fill Phosphor glyph. phosphor_flutter 2.1.0's own IconData
/// subclass cannot compile on Flutter 3.47 (IconData is final), so we use the
/// package's bundled fonts (declared in its pubspec) with plain IconData and
/// never import its Dart library. Code points: phosphor_flutter 2.1.0.
const String _pkg = 'phosphor_flutter';
const String _regular = 'PhosphorRegular';
const String _fill = 'PhosphorFill';

abstract final class BhorIcons {
  // Navigation destinations (regular / fill pairs).
  static const IconData today = IconData(0xe712, fontFamily: _regular, fontPackage: _pkg);
  static const IconData todayFill = IconData(0xe712, fontFamily: _fill, fontPackage: _pkg);
  static const IconData batches = IconData(0xe68e, fontFamily: _regular, fontPackage: _pkg);
  static const IconData batchesFill = IconData(0xe68e, fontFamily: _fill, fontPackage: _pkg);
  static const IconData students = IconData(0xe73e, fontFamily: _regular, fontPackage: _pkg);
  static const IconData studentsFill = IconData(0xe73e, fontFamily: _fill, fontPackage: _pkg);
  static const IconData fees = IconData(0xe68a, fontFamily: _regular, fontPackage: _pkg);
  static const IconData feesFill = IconData(0xe68a, fontFamily: _fill, fontPackage: _pkg);
  static const IconData more = IconData(0xe200, fontFamily: _regular, fontPackage: _pkg);
  static const IconData moreFill = IconData(0xe200, fontFamily: _fill, fontPackage: _pkg);

  // Actions.
  static const IconData search = IconData(0xe30c, fontFamily: _regular, fontPackage: _pkg);
  static const IconData rollCall = IconData(0xeadc, fontFamily: _regular, fontPackage: _pkg);
  static const IconData takeMoney = IconData(0xea8c, fontFamily: _regular, fontPackage: _pkg);
  static const IconData money = IconData(0xe54c, fontFamily: _regular, fontPackage: _pkg);
  static const IconData remind = IconData(0xe5e8, fontFamily: _regular, fontPackage: _pkg);
  static const IconData bell = IconData(0xe0ce, fontFamily: _regular, fontPackage: _pkg);
  static const IconData copy = IconData(0xe1ca, fontFamily: _regular, fontPackage: _pkg);
  static const IconData share = IconData(0xe408, fontFamily: _regular, fontPackage: _pkg);
  static const IconData phone = IconData(0xe3b8, fontFamily: _regular, fontPackage: _pkg);
  static const IconData holiday = IconData(0xe10c, fontFamily: _regular, fontPackage: _pkg);
  static const IconData calendar = IconData(0xe10a, fontFamily: _regular, fontPackage: _pkg);
  static const IconData archive = IconData(0xe00c, fontFamily: _regular, fontPackage: _pkg);
  static const IconData leftStudents = IconData(0xe4ce, fontFamily: _regular, fontPackage: _pkg);
  static const IconData user = IconData(0xe4c4, fontFamily: _regular, fontPackage: _pkg);
  static const IconData backupUp = IconData(0xe1ae, fontFamily: _regular, fontPackage: _pkg);
  static const IconData backupDown = IconData(0xe1ac, fontFamily: _regular, fontPackage: _pkg);
  static const IconData notes = IconData(0xe34c, fontFamily: _regular, fontPackage: _pkg);
  static const IconData edit = IconData(0xe3b4, fontFamily: _regular, fontPackage: _pkg);
  static const IconData delete = IconData(0xe4a6, fontFamily: _regular, fontPackage: _pkg);
  static const IconData add = IconData(0xe3d4, fontFamily: _regular, fontPackage: _pkg);
  static const IconData addCircle = IconData(0xe3d6, fontFamily: _regular, fontPackage: _pkg);
  static const IconData minus = IconData(0xe32a, fontFamily: _regular, fontPackage: _pkg);
  static const IconData filter = IconData(0xe266, fontFamily: _regular, fontPackage: _pkg);
  static const IconData sliders = IconData(0xe432, fontFamily: _regular, fontPackage: _pkg);
  static const IconData settings = IconData(0xe270, fontFamily: _regular, fontPackage: _pkg);
  static const IconData refresh = IconData(0xe036, fontFamily: _regular, fontPackage: _pkg);
  static const IconData undo = IconData(0xe038, fontFamily: _regular, fontPackage: _pkg);
  static const IconData overflow = IconData(0xe1fe, fontFamily: _regular, fontPackage: _pkg);
  static const IconData overflowVertical = IconData(0xe208, fontFamily: _regular, fontPackage: _pkg);
  static const IconData storage = IconData(0xe1de, fontFamily: _regular, fontPackage: _pkg);
  static const IconData explore = IconData(0xe1c8, fontFamily: _regular, fontPackage: _pkg);
  static const IconData sparkle = IconData(0xe6a2, fontFamily: _regular, fontPackage: _pkg);
  static const IconData light = IconData(0xe472, fontFamily: _regular, fontPackage: _pkg);
  static const IconData dark = IconData(0xe330, fontFamily: _regular, fontPackage: _pkg);
  static const IconData desktop = IconData(0xe560, fontFamily: _regular, fontPackage: _pkg);
  static const IconData phoneDevice = IconData(0xe1e0, fontFamily: _regular, fontPackage: _pkg);
  static const IconData chart = IconData(0xe150, fontFamily: _regular, fontPackage: _pkg);
  static const IconData receipt = IconData(0xe3ec, fontFamily: _regular, fontPackage: _pkg);

  // Attendance and status.
  static const IconData present = IconData(0xe182, fontFamily: _regular, fontPackage: _pkg);
  static const IconData absent = IconData(0xe4f6, fontFamily: _regular, fontPackage: _pkg);
  static const IconData late = IconData(0xed2c, fontFamily: _regular, fontPackage: _pkg);
  static const IconData leave = IconData(0xe5d6, fontFamily: _regular, fontPackage: _pkg);
  static const IconData clock = IconData(0xe19a, fontFamily: _regular, fontPackage: _pkg);
  static const IconData check = IconData(0xe182, fontFamily: _regular, fontPackage: _pkg);
  static const IconData checkCircle = IconData(0xe184, fontFamily: _regular, fontPackage: _pkg);
  static const IconData checkCircleFill = IconData(0xe184, fontFamily: _fill, fontPackage: _pkg);
  static const IconData warning = IconData(0xe4e2, fontFamily: _regular, fontPackage: _pkg);
  static const IconData warningFill = IconData(0xe4e2, fontFamily: _fill, fontPackage: _pkg);
  static const IconData info = IconData(0xe2ce, fontFamily: _regular, fontPackage: _pkg);
  static const IconData infoFill = IconData(0xe2ce, fontFamily: _fill, fontPackage: _pkg);
  static const IconData errorFill = IconData(0xe4f8, fontFamily: _fill, fontPackage: _pkg);

  // Chrome.
  static const IconData close = IconData(0xe4f6, fontFamily: _regular, fontPackage: _pkg);
  static const IconData back = IconData(0xe138, fontFamily: _regular, fontPackage: _pkg);
  static const IconData backDesktop = IconData(0xe058, fontFamily: _regular, fontPackage: _pkg);
  static const IconData arrowRight = IconData(0xe06c, fontFamily: _regular, fontPackage: _pkg);
  static const IconData chevronDown = IconData(0xe136, fontFamily: _regular, fontPackage: _pkg);
  static const IconData chevronUp = IconData(0xe13c, fontFamily: _regular, fontPackage: _pkg);
  static const IconData chevronLeft = IconData(0xe138, fontFamily: _regular, fontPackage: _pkg);
  static const IconData chevronRight = IconData(0xe13a, fontFamily: _regular, fontPackage: _pkg);
  static const IconData sidebarCollapse = IconData(0xe128, fontFamily: _regular, fontPackage: _pkg);
  static const IconData sidebarExpand = IconData(0xe12a, fontFamily: _regular, fontPackage: _pkg);

  /// Read-only field marker (lock-simple).
  static const IconData lock = IconData(0xe308, fontFamily: _regular, fontPackage: _pkg);
}
