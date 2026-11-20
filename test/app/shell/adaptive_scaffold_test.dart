// M5-A acceptance: phone pill vs rail at the UX 3b breakpoints, branch
// switching (tap + Ctrl+1..5), Ctrl+F search, pane width remembered.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/adaptive_scaffold.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/features/batches/ui/batches_screen.dart';
import 'package:attendance_alamin/features/dues/ui/fees_screen.dart';
import 'package:attendance_alamin/features/home/ui/today_screen.dart';
import 'package:attendance_alamin/features/search/ui/search_screen.dart';
import 'package:attendance_alamin/features/students/ui/students_screen.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import 'shell_harness.dart';

void main() {
  test('window classes follow 600 / 840 / 1200 / 1600', () {
    expect(WindowClass.fromWidth(599), WindowClass.compact);
    expect(WindowClass.fromWidth(600), WindowClass.medium);
    expect(WindowClass.fromWidth(839), WindowClass.medium);
    expect(WindowClass.fromWidth(840), WindowClass.expanded);
    expect(WindowClass.fromWidth(1199), WindowClass.expanded);
    expect(WindowClass.fromWidth(1200), WindowClass.large);
    expect(WindowClass.fromWidth(1600), WindowClass.extraLarge);
    expect(WindowClass.expanded.isWide, isTrue);
    expect(WindowClass.medium.isWide, isFalse);
    expect(WindowClass.compact.usesRail, isFalse);
    expect(WindowClass.large.extendedRail, isTrue);
  });

  final Map<double, (bool pill, double? rail)> cases = <double, (bool, double?)>{
    360: (true, null),
    599: (true, null),
    600: (false, 80),
    839: (false, 80),
    840: (false, 80),
    1199: (false, 80),
    1200: (false, 220),
    1600: (false, 220),
  };
  for (final MapEntry<double, (bool, double?)> c in cases.entries) {
    testWidgets('navigation at width ${c.key.toInt()}', (WidgetTester tester) async {
      await pumpShell(tester, size: Size(c.key, 800));
      expect(find.byKey(AdaptiveScaffold.pillKey), c.value.$1 ? findsOneWidget : findsNothing);
      final double? rail = c.value.$2;
      if (rail == null) {
        expect(find.byKey(AdaptiveScaffold.railKey), findsNothing);
      } else {
        expect(tester.getSize(find.byKey(AdaptiveScaffold.railKey)).width, rail);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone pill floats inset above the bottom edge', (WidgetTester tester) async {
    await pumpShell(tester);
    final Rect pill = tester.getRect(find.byKey(AdaptiveScaffold.pillKey));
    expect(pill.bottom, kPhone.height);
    // 12dp inset: the frosted surface is narrower than the window.
    final Rect surface = tester.getRect(
      find.descendant(of: find.byKey(AdaptiveScaffold.pillKey), matching: find.byType(ClipRRect)).first,
    );
    expect(surface.left, 12);
    expect(surface.height, 64);
  });

  testWidgets('tapping the pill switches branches', (WidgetTester tester) async {
    await pumpShell(tester);
    final l10n = l10nOf(Lang.bn);
    await tester.tap(find.descendant(of: find.byKey(AdaptiveScaffold.pillKey), matching: find.text(l10n.navBatches)));
    await tester.pumpAndSettle();
    expect(find.byType(BatchesScreen), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(AdaptiveScaffold.pillKey), matching: find.text(l10n.navFees)));
    await tester.pumpAndSettle();
    expect(find.byType(FeesScreen), findsOneWidget);
  });

  testWidgets('rail collapses and expands on large windows', (WidgetTester tester) async {
    await pumpShell(tester, size: kDesktop);
    final l10n = l10nOf(Lang.bn);
    expect(tester.getSize(find.byKey(AdaptiveScaffold.railKey)).width, 220);
    await tester.tap(find.byTooltip(l10n.shellRailCollapse));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(AdaptiveScaffold.railKey)).width, 80);
    await tester.tap(find.byTooltip(l10n.shellRailExpand));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(AdaptiveScaffold.railKey)).width, 220);
  });

  testWidgets('Ctrl+1..5 switch destinations, Ctrl+F opens search', (WidgetTester tester) async {
    await pumpShell(tester, size: kDesktop);
    Future<void> ctrl(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await ctrl(LogicalKeyboardKey.digit3);
    expect(find.byType(StudentsScreen), findsOneWidget);
    await ctrl(LogicalKeyboardKey.digit2);
    expect(find.byType(BatchesScreen), findsOneWidget);
    await ctrl(LogicalKeyboardKey.digit1);
    expect(find.byType(TodayScreen), findsOneWidget);
    await ctrl(LogicalKeyboardKey.keyF);
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('the shortcut sheet lists the shell keys', (WidgetTester tester) async {
    await pumpShell(tester, size: kDesktop, lang: Lang.en);
    final BuildContext context = tester.element(find.byType(TodayScreen));
    showShortcutHelp(context);
    await tester.pumpAndSettle();
    final l10n = l10nOf(Lang.en);
    expect(find.text(l10n.shellShortcutsTitle), findsOneWidget);
    expect(find.text(l10n.shellKeysDestinations), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list width is remembered per screen in local meta', (WidgetTester tester) async {
    final FakeLocalMetaRepository meta = FakeLocalMetaRepository();
    await pumpShell(tester, location: Routes.batch('b1'), size: kDesktop, meta: meta);
    final PaneLayout pane = tester.widget(find.byType(PaneLayout));
    expect(pane.listWidth, isNull);
    pane.onListWidthChanged!(400);
    await tester.pump();
    expect(tester.widget<PaneLayout>(find.byType(PaneLayout)).listWidth, 400);
    await tester.pump(const Duration(milliseconds: 500));
    expect(meta.values[LocalMetaKeys.pane('batches')], '400.0');
  });

  testWidgets('a stored list width is applied', (WidgetTester tester) async {
    final FakeLocalMetaRepository meta = FakeLocalMetaRepository(<String, String>{
      LocalMetaKeys.pane('students'): '420.0',
    });
    await pumpShell(tester, location: Routes.student('s1'), size: kDesktop, meta: meta);
    expect(tester.widget<PaneLayout>(find.byType(PaneLayout)).listWidth, 420);
  });

  testWidgets('no selection on a too-narrow wide window shows the list', (WidgetTester tester) async {
    // 860 - 80 rail = 780 < 320 + 1 + 480: one pane only.
    await pumpShell(tester, location: Routes.batches, size: const Size(860, 700));
    expect(find.byType(PaneLayout), findsNothing);
    expect(find.text(l10nOf(Lang.bn).shellStubBatches), findsOneWidget);
  });
}
