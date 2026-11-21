// M5-A acceptance (Bhor shell): phone bottom nav vs sidebar at the UX 3b
// breakpoints, branch switching (tap + Ctrl+1..5), Ctrl+F search, pane width
// remembered.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/adaptive_scaffold.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/widgets/pane_layout.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/features/batches/ui/batches_screen.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_overview.dart';
import 'package:attendance_alamin/features/dues/ui/fees_screen.dart';
import 'package:attendance_alamin/features/home/ui/today_screen.dart';
import 'package:attendance_alamin/features/search/ui/search_screen.dart';
import 'package:attendance_alamin/features/students/ui/students_screen.dart';

import '../../helpers/fakes/fake_settings_repos.dart';
import 'shell_harness.dart';

/// Product of the FadeTransition / Opacity values above [finder] (0 when
/// offstage or absent).
double _visible(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return 0;
  final Element e = finder.evaluate().first;
  double o = 1;
  e.visitAncestorElements((Element a) {
    final Widget w = a.widget;
    if (w is FadeTransition) {
      o *= w.opacity.value.clamp(0.0, 1.0);
    } else if (w is Opacity) {
      o *= w.opacity;
    } else if (w is Offstage && w.offstage) {
      o = 0;
    }
    return o > 0;
  });
  return o;
}

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

  const double icons = BhorSidebar.collapsedWidth;
  const double full = BhorSidebar.width;
  final Map<double, (bool bottomNav, double? sidebar)> cases = <double, (bool, double?)>{
    360: (true, null),
    599: (true, null),
    600: (false, icons),
    839: (false, icons),
    840: (false, icons),
    1199: (false, icons),
    1200: (false, full),
    1600: (false, full),
  };
  for (final MapEntry<double, (bool, double?)> c in cases.entries) {
    testWidgets('navigation at width ${c.key.toInt()}', (WidgetTester tester) async {
      await pumpShell(tester, size: Size(c.key, 800));
      expect(find.byKey(AdaptiveScaffold.bottomNavKey), c.value.$1 ? findsOneWidget : findsNothing);
      final double? sidebar = c.value.$2;
      if (sidebar == null) {
        expect(find.byKey(AdaptiveScaffold.sidebarKey), findsNothing);
      } else {
        expect(tester.getSize(find.byKey(AdaptiveScaffold.sidebarKey)).width, sidebar);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone bottom nav is a floating pill inset 10 from the edges', (WidgetTester tester) async {
    await pumpShell(tester);
    final Finder area = find.byKey(AdaptiveScaffold.bottomNavKey);
    final Rect nav = tester.getRect(area);
    expect(nav.bottom, kPhone.height);
    expect(nav.width, kPhone.width);
    expect(nav.height, AdaptiveScaffold.bottomNavHeight);
    // The pill: inset 10, r20, a line edge, no shadow.
    final Finder pill = find.descendant(
      of: area,
      matching: find.byWidgetPredicate((Widget w) =>
          w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).borderRadius != null),
    ).first;
    final Rect r = tester.getRect(pill);
    expect(r.left, BhorBottomNav.inset);
    expect(r.right, kPhone.width - BhorBottomNav.inset);
    expect(r.bottom, kPhone.height - BhorBottomNav.inset);
    expect(r.height, BhorBottomNav.pillHeight);
    final BoxDecoration d = tester.widget<Container>(pill).decoration! as BoxDecoration;
    expect(d.borderRadius, BorderRadius.circular(BhorRadius.nav));
    expect((d.border! as Border).top.width, 1);
    expect(d.boxShadow, isNull);
    // The page above ends where the nav area starts.
    expect(tester.getRect(find.byType(TodayScreen)).bottom, nav.top);
  });

  testWidgets('switching branches fades through and keeps branch state', (WidgetTester tester) async {
    await pumpShell(tester);
    final l10n = l10nOf(Lang.bn);
    // The branch stack sits in one fade-through (it is never built twice).
    expect(find.byType(BhorBranchFadeThrough), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(AdaptiveScaffold.bottomNavKey), matching: find.text(l10n.navBatches)));
    await tester.pump();
    // Fade-through: Today fades out before the batches tab fades in; at no
    // frame are both tabs visible.
    for (int f = 0; f < 24; f++) {
      await tester.pump(const Duration(milliseconds: 16));
      final double today = _visible(tester, find.byType(TodayScreen, skipOffstage: false));
      final double batches = _visible(tester, find.byType(BatchesScreen, skipOffstage: false));
      expect(today > 0.02 && batches > 0.02, isFalse, reason: 'frame $f: today $today, batches $batches');
    }
    await tester.pumpAndSettle();
    expect(find.byType(BatchesScreen), findsOneWidget);
    expect(_visible(tester, find.byType(TodayScreen, skipOffstage: false)), 0);
    await tester.tap(find.descendant(of: find.byKey(AdaptiveScaffold.bottomNavKey), matching: find.text(l10n.navToday)));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop body carries the sidebar inset for side panels', (WidgetTester tester) async {
    await pumpShell(tester, size: kDesktop);
    final BhorChromeInset inset = tester.widget<BhorChromeInset>(find.byType(BhorChromeInset));
    expect(inset.start, BhorSidebar.width);
  });

  testWidgets('phone toasts sit above the bottom nav', (WidgetTester tester) async {
    await pumpShell(tester);
    BhorToast.show(tester.element(find.byType(TodayScreen)), message: 'toast-probe');
    await tester.pumpAndSettle();
    final Rect nav = tester.getRect(find.byKey(AdaptiveScaffold.bottomNavKey));
    expect(tester.getRect(find.text('toast-probe')).bottom, lessThan(nav.top));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('toast-probe'), findsNothing);
  });

  testWidgets('tapping the bottom nav switches branches', (WidgetTester tester) async {
    await pumpShell(tester);
    final l10n = l10nOf(Lang.bn);
    await tester.tap(find.descendant(of: find.byKey(AdaptiveScaffold.bottomNavKey), matching: find.text(l10n.navBatches)));
    await tester.pumpAndSettle();
    expect(find.byType(BatchesScreen), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(AdaptiveScaffold.bottomNavKey), matching: find.text(l10n.navFees)));
    await tester.pumpAndSettle();
    expect(find.byType(FeesScreen), findsOneWidget);
  });

  testWidgets('sidebar collapses and expands on large windows', (WidgetTester tester) async {
    await pumpShell(tester, size: kDesktop);
    final l10n = l10nOf(Lang.bn);
    Finder toggle(String label) =>
        find.byWidgetPredicate((Widget w) => w is BhorIconButton && w.semanticLabel == label);
    final Finder sidebar = find.byKey(AdaptiveScaffold.sidebarKey);
    expect(tester.getSize(sidebar).width, BhorSidebar.width);
    expect(find.descendant(of: sidebar, matching: find.text(l10n.commonAppTitle)), findsOneWidget);
    await tester.tap(toggle(l10n.shellRailCollapse));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, BhorSidebar.collapsedWidth);
    await tester.tap(toggle(l10n.shellRailExpand));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, BhorSidebar.width);
  });

  testWidgets('the sidebar search opens search', (WidgetTester tester) async {
    await pumpShell(tester, size: kDesktop);
    final l10n = l10nOf(Lang.bn);
    await tester.tap(find.descendant(of: find.byKey(AdaptiveScaffold.sidebarKey), matching: find.text(l10n.commonSearch)));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
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
    // 860 - 72 sidebar = 788 < 320 + 1 + 480: one pane only.
    await pumpShell(tester, location: Routes.batches, size: const Size(860, 700));
    expect(find.byType(PaneLayout), findsNothing);
    expect(find.byType(BatchesScreen), findsOneWidget);
    expect(find.byType(BatchesOverview), findsNothing);
  });
}
