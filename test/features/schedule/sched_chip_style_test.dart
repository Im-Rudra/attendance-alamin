// Unselected chips must look enabled (naive-tester C5: the Friday chip looked
// disabled): a visible outline and full-contrast text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/features/schedule/widgets/sched_chip.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('an unselected SchedChip has a visible outline (${mode.name})', (WidgetTester tester) async {
      await pumpApp(
        tester,
        BhorScaffold(body: Center(child: SchedChip(label: 'Fri', selected: false, onTap: () {}))),
        themeMode: mode,
      );
      expect(find.descendant(of: find.byType(SchedChip), matching: find.byType(BhorChip)), findsOneWidget);
      final BuildContext ctx = tester.element(find.byType(SchedChip));
      final BhorColors c = ctx.bhor.colors;
      final AnimatedContainer box = tester.widget<AnimatedContainer>(
        find.descendant(of: find.byType(BhorChip), matching: find.byType(AnimatedContainer)),
      );
      final BoxDecoration deco = box.decoration! as BoxDecoration;
      expect((deco.border! as Border).top.color, c.line, reason: 'a hairline outline');
      final Text label = tester.widget<Text>(find.text('Fri'));
      expect(label.style?.color, c.text, reason: 'full-contrast text');
    });
  }
}
