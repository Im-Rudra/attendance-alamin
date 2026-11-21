// BhorIcons: the app's icon set, Phosphor (phosphor_flutter, pinned in
// pubspec). Regular weight for UI, Fill for the active nav item and status
// glyphs; Bold never (12-ux-review.md section 1.4). Sizes 16 / 18 / 20 / 24
// ([BhorIconSize]). Screens use these names instead of Material `Icons.*`:
// `Icon(BhorIcons.search)`, `BhorNavItem(icon: BhorIcons.today, activeIcon: BhorIcons.todayFill)`.

import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Icon sizes: inline meta 16, chips/tags 18, rows/buttons 20, nav 24.
abstract final class BhorIconSize {
  static const double inline = 16;
  static const double chip = 18;
  static const double row = 20;
  static const double nav = 24;
}

abstract final class BhorIcons {
  // Navigation destinations (regular / fill pairs).
  static const IconData today = PhosphorIconsRegular.calendarCheck;
  static const IconData todayFill = PhosphorIconsFill.calendarCheck;
  static const IconData batches = PhosphorIconsRegular.usersThree;
  static const IconData batchesFill = PhosphorIconsFill.usersThree;
  static const IconData students = PhosphorIconsRegular.student;
  static const IconData studentsFill = PhosphorIconsFill.student;
  static const IconData fees = PhosphorIconsRegular.wallet;
  static const IconData feesFill = PhosphorIconsFill.wallet;
  static const IconData more = PhosphorIconsRegular.dotsThreeCircle;
  static const IconData moreFill = PhosphorIconsFill.dotsThreeCircle;

  // Actions.
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData rollCall = PhosphorIconsRegular.listChecks;
  static const IconData takeMoney = PhosphorIconsRegular.handCoins;
  static const IconData money = PhosphorIconsRegular.currencyCircleDollar;
  static const IconData remind = PhosphorIconsRegular.bellRinging;
  static const IconData bell = PhosphorIconsRegular.bell;
  static const IconData copy = PhosphorIconsRegular.copy;
  static const IconData share = PhosphorIconsRegular.shareNetwork;
  static const IconData phone = PhosphorIconsRegular.phone;
  static const IconData holiday = PhosphorIconsRegular.calendarX;
  static const IconData calendar = PhosphorIconsRegular.calendarBlank;
  static const IconData archive = PhosphorIconsRegular.archive;
  static const IconData leftStudents = PhosphorIconsRegular.userMinus;
  static const IconData user = PhosphorIconsRegular.userCircle;
  static const IconData backupUp = PhosphorIconsRegular.cloudArrowUp;
  static const IconData backupDown = PhosphorIconsRegular.cloudArrowDown;
  static const IconData notes = PhosphorIconsRegular.notePencil;
  static const IconData edit = PhosphorIconsRegular.pencilSimple;
  static const IconData delete = PhosphorIconsRegular.trash;
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData addCircle = PhosphorIconsRegular.plusCircle;
  static const IconData minus = PhosphorIconsRegular.minus;
  static const IconData filter = PhosphorIconsRegular.funnel;
  static const IconData sliders = PhosphorIconsRegular.sliders;
  static const IconData settings = PhosphorIconsRegular.gear;
  static const IconData refresh = PhosphorIconsRegular.arrowClockwise;
  static const IconData undo = PhosphorIconsRegular.arrowCounterClockwise;
  static const IconData overflow = PhosphorIconsRegular.dotsThree;
  static const IconData overflowVertical = PhosphorIconsRegular.dotsThreeVertical;
  static const IconData storage = PhosphorIconsRegular.database;
  static const IconData explore = PhosphorIconsRegular.compass;
  static const IconData sparkle = PhosphorIconsRegular.sparkle;
  static const IconData light = PhosphorIconsRegular.sun;
  static const IconData dark = PhosphorIconsRegular.moon;
  static const IconData desktop = PhosphorIconsRegular.desktop;
  static const IconData phoneDevice = PhosphorIconsRegular.deviceMobile;
  static const IconData chart = PhosphorIconsRegular.chartBar;
  static const IconData receipt = PhosphorIconsRegular.receipt;

  // Attendance and status.
  static const IconData present = PhosphorIconsRegular.check;
  static const IconData absent = PhosphorIconsRegular.x;
  static const IconData late = PhosphorIconsRegular.clockCountdown;
  static const IconData leave = PhosphorIconsRegular.airplaneTilt;
  static const IconData clock = PhosphorIconsRegular.clock;
  static const IconData check = PhosphorIconsRegular.check;
  static const IconData checkCircle = PhosphorIconsRegular.checkCircle;
  static const IconData checkCircleFill = PhosphorIconsFill.checkCircle;
  static const IconData warning = PhosphorIconsRegular.warningCircle;
  static const IconData warningFill = PhosphorIconsFill.warningCircle;
  static const IconData info = PhosphorIconsRegular.info;
  static const IconData infoFill = PhosphorIconsFill.info;
  static const IconData errorFill = PhosphorIconsFill.xCircle;

  // Chrome.
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData back = PhosphorIconsRegular.caretLeft;
  static const IconData backDesktop = PhosphorIconsRegular.arrowLeft;
  static const IconData arrowRight = PhosphorIconsRegular.arrowRight;
  static const IconData chevronDown = PhosphorIconsRegular.caretDown;
  static const IconData chevronUp = PhosphorIconsRegular.caretUp;
  static const IconData chevronLeft = PhosphorIconsRegular.caretLeft;
  static const IconData chevronRight = PhosphorIconsRegular.caretRight;
  static const IconData sidebarCollapse = PhosphorIconsRegular.caretDoubleLeft;
  static const IconData sidebarExpand = PhosphorIconsRegular.caretDoubleRight;
}
