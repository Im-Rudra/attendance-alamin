// Master-detail panes for wide windows (UX 3b pane-allocation rule).
//
// Extra width goes to the detail pane first (up to [detailMax]), then to the
// optional context pane (280..[contextWidth]), then to the list (up to
// [listMax]) when its width is not pinned by the user. Panes abut with 1px
// hairline dividers, never gaps. The list/detail divider carries an 8dp drag
// handle (resize cursor); double-tap resets it. The parent remembers the width
// (local preferences) and passes it back through [listWidth].

import 'package:flutter/services.dart' show SystemMouseCursors;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

/// Resulting pane widths (0 = pane not shown).
class PaneWidths {
  const PaneWidths({required this.list, required this.detail, required this.context});

  final double list;
  final double detail;
  final double context;
}

class PaneLayout extends StatelessWidget {
  const PaneLayout({
    super.key,
    required this.list,
    required this.detail,
    this.contextPane,
    this.listWidth,
    this.onListWidthChanged,
    this.listMin = 320,
    this.listMax = 440,
    this.detailMax = 720,
    this.contextWidth = 320,
  });

  final Widget list;
  final Widget detail;
  final Widget? contextPane;

  /// Remembered list width; null = automatic.
  final double? listWidth;

  /// Called while dragging and on double-tap (with [defaultListWidth]).
  final ValueChanged<double>? onListWidthChanged;
  final double listMin;
  final double listMax;
  final double detailMax;
  final double contextWidth;

  static const double defaultListWidth = 360;
  static const double detailMin = 480;
  static const double contextMin = 280;
  static const double dividerWidth = 1;
  static const double handleWidth = 8;

  /// Pure allocation, shared with the tests.
  static PaneWidths compute({
    required double width,
    required bool hasContext,
    double? listWidth,
    double listMin = 320,
    double listMax = 440,
    double detailMax = 720,
    double contextWidth = 320,
  }) {
    if (width < listMin + dividerWidth + detailMin) {
      return PaneWidths(list: 0, detail: width, context: 0);
    }
    double l = (listWidth ?? defaultListWidth).clamp(listMin, listMax).toDouble();
    final double maxList = width - dividerWidth - detailMin;
    if (l > maxList) l = maxList;
    final double rest = width - l - dividerWidth;
    double ctx = 0;
    if (hasContext && rest - dividerWidth - contextMin >= detailMin) {
      ctx = (rest - dividerWidth - detailMax).clamp(contextMin, contextWidth).toDouble();
      if (rest - dividerWidth - ctx < detailMin) ctx = rest - dividerWidth - detailMin;
    }
    double d = ctx > 0 ? rest - dividerWidth - ctx : rest;
    if (listWidth == null && d > detailMax) {
      final double grow = (d - detailMax) < (listMax - l) ? (d - detailMax) : (listMax - l);
      if (grow > 0) {
        l += grow;
        d -= grow;
      }
    }
    return PaneWidths(list: l, detail: d, context: ctx);
  }

  @override
  Widget build(BuildContext context) {
    final BhorColors colors = context.bhor.colors;
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints c) {
        final PaneWidths w = compute(
          width: c.maxWidth,
          hasContext: contextPane != null,
          listWidth: listWidth,
          listMin: listMin,
          listMax: listMax,
          detailMax: detailMax,
          contextWidth: contextWidth,
        );
        if (w.list == 0) return detail;
        final Widget divider = SizedBox(
          width: dividerWidth,
          child: ColoredBox(color: colors.line),
        );
        final bool bounded = c.hasBoundedHeight;
        final Widget panes = Row(
          crossAxisAlignment: bounded ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: w.list, child: list),
            divider,
            SizedBox(width: w.detail, child: detail),
            if (w.context > 0) ...<Widget>[
              divider,
              SizedBox(width: w.context, child: contextPane),
            ],
          ],
        );
        // Panes are full height: header and lists fill their pane.
        final Widget row = SizedBox(
          width: c.maxWidth,
          height: bounded ? c.maxHeight : null,
          child: panes,
        );
        final ValueChanged<double>? changed = onListWidthChanged;
        if (changed == null) return row;
        double clampList(double v) => v.clamp(listMin, listMax).toDouble();
        return Stack(
          children: <Widget>[
            row,
            Positioned(
              left: w.list + dividerWidth / 2 - handleWidth / 2,
              top: 0,
              bottom: 0,
              width: handleWidth,
              child: Semantics(
                label: ctx.l10n.uiPaneResize,
                onIncrease: () => changed(clampList(w.list + 24)),
                onDecrease: () => changed(clampList(w.list - 24)),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (DragUpdateDetails d) =>
                        changed(clampList(w.list + d.delta.dx)),
                    onDoubleTap: () => changed(clampList(defaultListWidth)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
