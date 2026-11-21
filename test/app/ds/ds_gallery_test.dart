// The developer gallery renders every section in both themes at phone and
// desktop widths without Material widgets, and is reachable from the
// hidden long-press on the Diagnostics version row.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/ds/gallery/ds_gallery_screen.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/format/lang.dart';

import '../shell/shell_harness.dart';
import 'ds_harness.dart';

void main() {
  final List<(String, Size, int, int, Lang)> cases = <(String, Size, int, int, Lang)>[
    ('desktop both fit bn', const Size(1280, 9000), 2, 2, Lang.bn),
    ('desktop dark desktop-width en', const Size(1280, 9000), 1, 1, Lang.en),
    ('phone light phone-width bn', const Size(360, 12000), 0, 0, Lang.bn),
    ('phone dark fit en', const Size(360, 12000), 1, 2, Lang.en),
    ('phone both desktop-width bn', const Size(360, 12000), 2, 1, Lang.bn),
  ];
  for (final (String name, Size size, int theme, int width, Lang lang) in cases) {
    testWidgets('gallery renders [$name]', (WidgetTester tester) async {
      await pumpDs(
        tester,
        DsGalleryScreen(initialTheme: theme, initialWidth: width),
        size: size,
        lang: lang,
        scroll: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expectClean(tester, name);
      for (final Type t in <Type>[
        BhorButton,
        BhorIconButton,
        BhorTextField,
        BhorSegmented<int>,
        BhorChip,
        BhorTag,
        BhorSwitch,
        BhorCheckbox,
        BhorRadioCard<int>,
        BhorCard,
        BhorListRow,
        BhorSectionHeader,
        BhorAvatar,
        BhorProgress,
        BhorSkeleton,
        BhorEmptyState,
        BhorAttendanceToggle,
        BhorEscalationBar,
        BhorMoney,
        BhorStatText,
        BhorDatePicker,
        BhorTimePicker,
        BhorTabs,
        BhorBottomNav,
        BhorSidebar,
        BhorHeader,
        BhorScaffold,
        BhorSheetFrame,
        BhorDialog,
      ]) {
        expect(find.byWidgetPredicate((Widget w) => w.runtimeType == t), findsWidgets, reason: '$t in gallery');
      }
      expect(find.byType(BhorSelect<String>), findsWidgets);
      expect(materialWidgetsIn(tester), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('gallery theme switch flips to dark', (WidgetTester tester) async {
    await pumpDs(tester, const DsGalleryScreen(), size: const Size(1280, 3000), scroll: false);
    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 300));
    final BhorTheme outer = tester.widgetList<BhorTheme>(find.byType(BhorTheme)).elementAt(1);
    expect(outer.data.isDark, isTrue);
    expectClean(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('route /more/design-system shows the gallery', (WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpShell(tester, location: Routes.moreDesignSystem);
    expect(find.byType(DsGalleryScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press on the Diagnostics version row opens the gallery', (WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpShell(tester, location: Routes.moreDiagnostics);
    expect(find.byType(DsGalleryScreen), findsNothing);
    await tester.longPress(find.byKey(const Key('diag-version')));
    await tester.pumpAndSettle();
    expect(find.byType(DsGalleryScreen), findsOneWidget);
  });
}
