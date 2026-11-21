// M4-D: BentoGrid (12 columns, rows sum to 12, equal row heights, ragged row
// asserts) at expanded / large / extra-large widths, and PaneLayout allocation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/widgets/bento_grid.dart';
import 'package:attendance_alamin/app/widgets/pane_layout.dart';

import 'harness.dart';

/// (name, row, col, colSpan, rowSpan): the UX 3b Today bento tables.
typedef Spec = (String, int, int, int, int);

const List<Spec> expandedSpec = <Spec>[
  ('hero', 0, 0, 7, 1),
  ('dues', 0, 7, 5, 1),
  ('timeline', 1, 0, 7, 2),
  ('collection', 1, 7, 5, 1),
  ('attendance', 2, 7, 5, 1),
  ('alerts', 3, 0, 5, 1),
  ('quick', 3, 5, 4, 1),
  ('backup', 3, 9, 3, 1),
];

const List<Spec> largeSpec = <Spec>[
  ('hero', 0, 0, 5, 1),
  ('dues', 0, 5, 4, 1),
  ('collection', 0, 9, 3, 1),
  ('timeline', 1, 0, 5, 2),
  ('attendance', 1, 5, 4, 1),
  ('alerts', 1, 9, 3, 1),
  ('recent', 2, 5, 4, 1),
  ('backup', 2, 9, 3, 1),
];

const List<Spec> xlSpec = <Spec>[
  ('hero', 0, 0, 4, 1),
  ('dues', 0, 4, 5, 1),
  ('collection', 0, 9, 3, 1),
  ('timeline', 1, 0, 4, 2),
  ('week', 1, 4, 5, 1),
  ('attendance', 1, 9, 3, 1),
  ('alerts', 2, 4, 3, 1),
  ('recent', 2, 7, 3, 1),
  ('backup', 2, 10, 2, 1),
];

List<BentoPlacement> placementsOf(List<Spec> spec) => <BentoPlacement>[
      for (final Spec s in spec)
        BentoPlacement(
          col: s.$3,
          row: s.$2,
          colSpan: s.$4,
          rowSpan: s.$5,
          child: ColoredBox(key: ValueKey<String>(s.$1), color: Colors.transparent),
        ),
    ];

void main() {
  group('BentoGrid.validate', () {
    test('accepts the three UX tables', () {
      expect(BentoGrid.validate(placementsOf(expandedSpec), 4, 12), isNull);
      expect(BentoGrid.validate(placementsOf(largeSpec), 3, 12), isNull);
      expect(BentoGrid.validate(placementsOf(xlSpec), 3, 12), isNull);
    });

    test('rejects a ragged row, a hole, an overlap and an overflow', () {
      List<BentoPlacement> row(List<int> spans, {int r = 0}) {
        int c = 0;
        final List<BentoPlacement> out = <BentoPlacement>[];
        for (final int s in spans) {
          out.add(BentoPlacement(col: c, row: r, colSpan: s, child: const SizedBox()));
          c += s;
        }
        return out;
      }

      expect(BentoGrid.validate(row(<int>[7, 4]), 1, 12), contains('sums to 11'));
      expect(BentoGrid.validate(row(<int>[7, 6]), 1, 12), contains('leaves'));
      expect(
        BentoGrid.validate(<BentoPlacement>[
          ...row(<int>[7, 5]),
          const BentoPlacement(col: 6, row: 0, colSpan: 2, child: SizedBox()),
        ], 1, 12),
        contains('overlap'),
      );
      expect(BentoGrid.validate(row(<int>[12], r: 1), 1, 12), contains('leaves'));
    });
  });

  testWidgets('a ragged row asserts when built', (WidgetTester tester) async {
    await pumpLayout(
      tester,
      BentoGrid(
        rowCount: 1,
        gutter: 16,
        placements: const <BentoPlacement>[
          BentoPlacement(col: 0, row: 0, colSpan: 7, child: SizedBox()),
          BentoPlacement(col: 7, row: 0, colSpan: 4, child: SizedBox()),
        ],
      ),
    );
    expect(tester.takeException(), isA<AssertionError>());
  });

  void checkGrid(WidgetTester tester, List<Spec> spec, double width, double height, double gutter, int rows) {
    final double unit = BentoGrid.rowUnit(
      availableHeight: height,
      rowCount: rows,
      gutter: gutter,
      minRowUnit: 184,
    );
    expect(unit, greaterThanOrEqualTo(184));
    final Rect grid = tester.getRect(find.byType(BentoGrid));
    for (int r = 0; r < rows; r++) {
      // Tiles that cover row r, left to right.
      final List<Spec> covering = spec.where((Spec s) => s.$2 <= r && r < s.$2 + s.$5).toList()
        ..sort((Spec a, Spec b) => a.$3.compareTo(b.$3));
      final List<Rect> rects = <Rect>[
        for (final Spec s in covering) tester.getRect(find.byKey(ValueKey<String>(s.$1))),
      ];
      // Columns sum to 12 ...
      expect(covering.fold<int>(0, (int a, Spec s) => a + s.$4), 12, reason: 'row $r');
      // ... widths plus gutters fill the grid exactly, edges abut on the gutter.
      expect(rects.first.left, closeTo(grid.left, 0.01));
      expect(rects.last.right, closeTo(grid.right, 0.01));
      for (int i = 1; i < rects.length; i++) {
        expect(rects[i].left - rects[i - 1].right, closeTo(gutter, 0.01), reason: 'row $r gutter');
      }
    }
    // Equal heights: a one-row tile is one unit, a two-row tile 2 units + gutter,
    // and every tile of a row starts at the same top.
    for (final Spec s in spec) {
      final Rect rect = tester.getRect(find.byKey(ValueKey<String>(s.$1)));
      expect(rect.height, closeTo(s.$5 * unit + (s.$5 - 1) * gutter, 0.01), reason: s.$1);
      expect(rect.top - grid.top, closeTo(s.$2 * (unit + gutter), 0.01), reason: '${s.$1} top');
    }
  }

  final Map<String, (List<Spec>, double, double, int)> cases = <String, (List<Spec>, double, double, int)>{
    'expanded 1000 (gutter 16)': (expandedSpec, 1000, 16, 4),
    'large 1400 (gutter 20)': (largeSpec, 1400, 20, 3),
    'extra-large 1800 (gutter 24)': (xlSpec, 1800, 24, 3),
  };
  for (final MapEntry<String, (List<Spec>, double, double, int)> e in cases.entries) {
    for (final double height in <double>[560, 900]) {
      testWidgets('${e.key}: rows sum to 12 and heights are equal at window height $height',
          (WidgetTester tester) async {
        final (List<Spec> spec, double width, double gutter, int rows) = e.value;
        await pumpLayout(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: BentoGrid(placements: placementsOf(spec), rowCount: rows, gutter: gutter),
            ),
          ),
          size: Size(width, height + 100),
        );
        expect(tester.takeException(), isNull);
        checkGrid(tester, spec, width, height, gutter, rows);
      });
    }
  }

  testWidgets('three rows fill a tall window exactly', (WidgetTester tester) async {
    await pumpLayout(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 1400,
          height: 900,
          child: BentoGrid(placements: placementsOf(largeSpec), rowCount: 3, gutter: 20),
        ),
      ),
      size: const Size(1400, 1000),
    );
    final Rect timeline = tester.getRect(find.byKey(const ValueKey<String>('timeline')));
    expect(timeline.bottom, closeTo(900, 0.01));
  });

  group('PaneLayout.compute', () {
    test('panes always add up to the width, respect minimums and maximums', () {
      for (double w = 840; w <= 2400; w += 40) {
        for (final bool ctx in <bool>[false, true]) {
          final PaneWidths p = PaneLayout.compute(width: w, hasContext: ctx);
          final double dividers = ctx && p.context > 0 ? 2 : 1;
          expect(p.list + p.detail + p.context + dividers, closeTo(w, 0.01), reason: 'w=$w ctx=$ctx');
          expect(p.list, inInclusiveRange(320, 440), reason: 'w=$w');
          expect(p.detail, greaterThanOrEqualTo(480), reason: 'w=$w');
          if (p.context > 0) expect(p.context, inInclusiveRange(280, 320));
          if (!ctx) expect(p.context, 0);
        }
      }
    });

    test('extra width: detail up to 720, then context, then list', () {
      final PaneWidths a = PaneLayout.compute(width: 1200, hasContext: true);
      expect(a.detail, lessThanOrEqualTo(720));
      expect(a.context, greaterThanOrEqualTo(280));
      final PaneWidths b = PaneLayout.compute(width: 1920, hasContext: true);
      expect(b.context, 320);
      expect(b.list, 440);
    });

    test('a pinned list width is kept within its bounds', () {
      expect(PaneLayout.compute(width: 1400, hasContext: false, listWidth: 400).list, 400);
      expect(PaneLayout.compute(width: 1400, hasContext: false, listWidth: 900).list, 440);
      expect(PaneLayout.compute(width: 1400, hasContext: false, listWidth: 10).list, 320);
    });

    test('below list + detail minimum only the detail shows', () {
      final PaneWidths p = PaneLayout.compute(width: 700, hasContext: true);
      expect(p.list, 0);
      expect(p.detail, 700);
    });
  });

  group('PaneLayout widget', () {
    testWidgets('three panes abut with hairline dividers and the handle resizes', (WidgetTester tester) async {
      final List<double> changes = <double>[];
      await pumpLayout(
        tester,
        PaneLayout(
          list: const ColoredBox(key: ValueKey<String>('list'), color: Colors.transparent),
          detail: const ColoredBox(key: ValueKey<String>('detail'), color: Colors.transparent),
          contextPane: const ColoredBox(key: ValueKey<String>('context'), color: Colors.transparent),
          onListWidthChanged: changes.add,
        ),
        size: const Size(1400, 800),
      );
      final Rect l = tester.getRect(find.byKey(const ValueKey<String>('list')));
      final Rect d = tester.getRect(find.byKey(const ValueKey<String>('detail')));
      final Rect c = tester.getRect(find.byKey(const ValueKey<String>('context')));
      expect(d.left - l.right, 1);
      expect(c.left - d.right, 1);
      expect(l.height, 800);

      await tester.dragFrom(Offset(l.right + 0.5, 300), const Offset(40, 0));
      expect(changes, isNotEmpty);
      expect(changes.last, greaterThanOrEqualTo(l.width));
      expect(changes.last, lessThanOrEqualTo(440));

      changes.clear();
      await tester.tapAt(Offset(l.right + 0.5, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(Offset(l.right + 0.5, 300));
      await tester.pumpAndSettle();
      expect(changes, <double>[PaneLayout.defaultListWidth]);
    });
  });
}
