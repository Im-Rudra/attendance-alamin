// M4-D: the reduced-effects path renders no BackdropFilter and no grain;
// the full path blurs only where asked; the grain tile is generated once.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/widgets/effects_mode.dart';
import 'package:attendance_alamin/app/widgets/glass_card.dart';
import 'package:attendance_alamin/app/widgets/grain_tile.dart';
import 'package:attendance_alamin/app/widgets/mesh_background.dart';

import 'harness.dart';

Widget screen() => const MeshBackground(
      child: Column(
        children: <Widget>[
          GlassCard(blur: true, child: Text('nav')),
          GlassCard(blur: true, child: Text('hero')),
          GlassCard(child: Text('no blur')),
          GlassCard(dense: true, blur: true, child: Text('dense')),
        ],
      ),
    );

void main() {
  for (final Brightness b in Brightness.values) {
    testWidgets('reduced effects: no BackdropFilter [${b.name}]', (WidgetTester tester) async {
      await pumpAurora(tester, screen(), brightness: b, reduced: true);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('hero'), findsOneWidget);
    });

    testWidgets('full effects: only blur:true, non-dense cards blur [${b.name}]', (WidgetTester tester) async {
      await pumpAurora(tester, screen(), brightness: b, reduced: false);
      expect(find.byType(BackdropFilter), findsNWidgets(2));
    });
  }

  testWidgets('OS reduce-motion forces the reduced path', (WidgetTester tester) async {
    await pumpAurora(
      tester,
      screen(),
      reduced: false,
      media: (MediaQueryData d) => d.copyWith(disableAnimations: true),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('OS high contrast forces the reduced path', (WidgetTester tester) async {
    await pumpAurora(
      tester,
      screen(),
      reduced: false,
      media: (MediaQueryData d) => d.copyWith(highContrast: true),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('reducedOf: default is false, explicit true wins', (WidgetTester tester) async {
    bool? plain;
    bool? explicit;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Column(
          children: <Widget>[
            Builder(builder: (BuildContext c) {
              plain = EffectsMode.reducedOf(c);
              return const SizedBox();
            }),
            EffectsMode(
              reduced: true,
              child: Builder(builder: (BuildContext c) {
                explicit = EffectsMode.reducedOf(c);
                return const SizedBox();
              }),
            ),
          ],
        ),
      ),
    );
    expect(plain, isFalse);
    expect(explicit, isTrue);
  });

  group('GrainTile', () {
    test('pixels are deterministic, opaque and varied', () {
      final a = GrainTile.pixels();
      final b = GrainTile.pixels();
      expect(a.length, GrainTile.size * GrainTile.size * 4);
      expect(a, orderedEquals(b));
      expect(a[3], 255);
      final Set<int> distinct = <int>{for (int i = 0; i < a.length; i += 4) a[i]};
      expect(distinct.length, greaterThan(20));
    });

    test('tile edges are seamless', () {
      final a = GrainTile.pixels();
      int at(int x, int y) => a[(y * GrainTile.size + x) * 4];
      // Neighbour across the wrap is as close as any inner neighbour.
      int maxInner = 0;
      for (int y = 0; y < GrainTile.size; y++) {
        for (int x = 0; x < GrainTile.size - 1; x++) {
          final int d = (at(x, y) - at(x + 1, y)).abs();
          if (d > maxInner) maxInner = d;
        }
      }
      for (int y = 0; y < GrainTile.size; y++) {
        expect((at(GrainTile.size - 1, y) - at(0, y)).abs(), lessThanOrEqualTo(maxInner + 1));
      }
    });

    testWidgets('generated once and cached', (WidgetTester tester) async {
      final ui.Image? first = await tester.runAsync(() => GrainTile.load().timeout(const Duration(seconds: 10)));
      final ui.Image? second = await tester.runAsync(() => GrainTile.load().timeout(const Duration(seconds: 10)));
      expect(first, isNotNull);
      expect(identical(first, second), isTrue);
      expect(GrainTile.debugGenerations, 1);
      expect(GrainTile.image, same(first));
    });
  });
}
