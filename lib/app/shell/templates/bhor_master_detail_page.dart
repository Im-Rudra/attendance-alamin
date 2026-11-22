// BhorMasterDetailPage (docs/council/16-windows-rebuild-plan.md W1-B 5): the
// Batches / Students / Fees layout. Wide: the list is 360 wide, the detail
// takes the rest. An optional context rail gets its own column only on
// windows >= 1600 (and only when the detail keeps >= 480); otherwise it is
// "folded": the detail reads it with BhorMasterDetailPage.foldedRailOf and
// shows it as one of its sections, so there is never a 4th thin column
// (review B1). Narrow: the detail alone when there is one, else the list.
// Usage:
//   BhorMasterDetailPage(
//     master: BatchList(selectedId: id),
//     detail: id == null ? null : BatchDetail(id: id),
//     emptyDetail: BhorEmptyState(...),
//     rail: WeekRail(...),
//   )
// and inside the detail: `final Widget? rail = BhorMasterDetailPage.foldedRailOf(context);`

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class BhorMasterDetailPage extends StatelessWidget {
  const BhorMasterDetailPage({
    super.key,
    required this.master,
    this.detail,
    this.emptyDetail,
    this.rail,
    this.masterWidth = defaultMasterWidth,
    this.railWidth = defaultRailWidth,
    this.minDetailWidth = defaultMinDetailWidth,
  });

  static const double defaultMasterWidth = 360;
  static const double defaultRailWidth = 320;
  static const double defaultMinDetailWidth = 480;

  /// Window width from which the rail may get its own column.
  static const double railMinWindowWidth = 1600;

  static const Key masterKey = Key('bhor-md-master');
  static const Key detailKey = Key('bhor-md-detail');
  static const Key railKey = Key('bhor-md-rail');

  /// The list pane.
  final Widget master;

  /// The selected item; null shows [emptyDetail] on wide windows and the
  /// list alone on narrow ones.
  final Widget? detail;

  /// Wide window, nothing selected (a BhorEmptyState or an overview).
  final Widget? emptyDetail;

  /// Optional context rail (column >= 1600, folded into the detail below).
  final Widget? rail;
  final double masterWidth;
  final double railWidth;
  final double minDetailWidth;

  /// True when [width] holds the list and a detail side by side.
  static bool twoPane(double width,
          {double masterWidth = defaultMasterWidth, double minDetailWidth = defaultMinDetailWidth}) =>
      width >= masterWidth + 1 + minDetailWidth;

  /// True when the rail gets its own column: a window >= 1600 and room for
  /// list + detail + rail in [paneWidth].
  static bool railColumn(
    double windowWidth,
    double paneWidth, {
    double masterWidth = defaultMasterWidth,
    double minDetailWidth = defaultMinDetailWidth,
    double railWidth = defaultRailWidth,
  }) =>
      windowWidth >= railMinWindowWidth && paneWidth >= masterWidth + minDetailWidth + railWidth + 2;

  /// The rail to show as a section of the detail, or null when the rail has
  /// its own column (or there is none).
  static Widget? foldedRailOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FoldedRail>()?.rail;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    final double window = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double w = box.maxWidth;
        if (!twoPane(w, masterWidth: masterWidth, minDetailWidth: minDetailWidth)) {
          final Widget? d = detail;
          if (d == null) return KeyedSubtree(key: masterKey, child: master);
          return _FoldedRail(rail: rail, child: KeyedSubtree(key: detailKey, child: d));
        }
        final bool ownRail = rail != null &&
            railColumn(window, w, masterWidth: masterWidth, minDetailWidth: minDetailWidth, railWidth: railWidth);
        final Widget divider = SizedBox(width: 1, child: ColoredBox(color: c.line));
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: masterWidth, child: KeyedSubtree(key: masterKey, child: master)),
            divider,
            Expanded(
              child: _FoldedRail(
                rail: ownRail ? null : rail,
                child: KeyedSubtree(key: detailKey, child: detail ?? emptyDetail ?? const SizedBox.shrink()),
              ),
            ),
            if (ownRail) ...<Widget>[
              divider,
              SizedBox(width: railWidth, child: KeyedSubtree(key: railKey, child: rail!)),
            ],
          ],
        );
      },
    );
  }
}

class _FoldedRail extends InheritedWidget {
  const _FoldedRail({required this.rail, required super.child});

  final Widget? rail;

  @override
  bool updateShouldNotify(_FoldedRail oldWidget) => oldWidget.rail != rail;
}
