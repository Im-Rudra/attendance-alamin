// Unselected chips must look enabled (naive-tester C5: the Friday chip looked
// disabled): a clearly visible outline and full-contrast text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/features/schedule/widgets/sched_chip.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('an unselected SchedChip has a visible outline (${mode.name})', (WidgetTester tester) async {
      await pumpApp(
        tester,
        Scaffold(body: Center(child: SchedChip(label: 'Fri', selected: false, onTap: () {}))),
        themeMode: mode,
      );
      final Material m = tester.widget<Material>(
        find.descendant(of: find.byType(SchedChip), matching: find.byType(Material)).first,
      );
      final BuildContext ctx = tester.element(find.byType(SchedChip));
      final RoundedRectangleBorder shape = m.shape! as RoundedRectangleBorder;
      expect(shape.side.color, ctx.aurora.textSecondary.withValues(alpha: 0.6), reason: 'not the 7% hairline');
      final Text label = tester.widget<Text>(find.text('Fri'));
      expect(label.style?.color, ctx.aurora.textPrimary);
    });
  }
}
