// Pump helper for Bhor design-system tests: a plain WidgetsApp (no
// MaterialApp, no Material theme), real localisation, a BhorTheme and a
// scrollable page so components render exactly as they will after the
// shell migration.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Every theme x language combination.
const List<(Brightness, Lang)> kDsCases = <(Brightness, Lang)>[
  (Brightness.light, Lang.bn),
  (Brightness.dark, Lang.bn),
  (Brightness.light, Lang.en),
  (Brightness.dark, Lang.en),
];

String dsCaseLabel((Brightness, Lang) c) => '${c.$1.name} ${c.$2.code}';

AppLocalizations dsL10n(Lang lang) => lookupAppLocalizations(Locale(lang.code));

/// Pumps [child] in a WidgetsApp + BhorTheme. [scroll] wraps it in a
/// padded ListView; otherwise it fills the page. [disableAnimations]
/// freezes repeating animations (spinner, skeleton) so pumpAndSettle works.
Future<void> pumpDs(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  Lang lang = Lang.bn,
  Size size = const Size(400, 800),
  bool scroll = true,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (disableAnimations) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final BhorThemeData theme = BhorThemeData.of(brightness);
  await tester.pumpWidget(
    WidgetsApp(
      color: theme.colors.accent,
      debugShowCheckedModeBanner: false,
      locale: Locale(lang.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (BuildContext context, Animation<double> a, Animation<double> s) => builder(context),
      ),
      home: BhorTheme(
        data: theme,
        child: BhorScaffold(
          wash: false,
          body: scroll
              ? ListView(padding: const EdgeInsets.all(16), children: <Widget>[child])
              : child,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Fails when the framework recorded an exception (overflow, assertion...).
void expectClean(WidgetTester tester, [String when = '']) {
  final Object? e = tester.takeException();
  if (e != null) fail('Exception $when: $e');
}

/// Material widget types that must never appear in a Bhor tree.
const Set<String> kMaterialWidgetNames = <String>{
  'Material',
  'InkWell',
  'InkResponse',
  'Ink',
  'Scaffold',
  'AppBar',
  'ElevatedButton',
  'FilledButton',
  'TextButton',
  'OutlinedButton',
  'IconButton',
  'FloatingActionButton',
  'TextField',
  'TextFormField',
  'Card',
  'Chip',
  'FilterChip',
  'ChoiceChip',
  'InputChip',
  'NavigationBar',
  'NavigationRail',
  'BottomNavigationBar',
  'AlertDialog',
  'Dialog',
  'SnackBar',
  'Switch',
  'Checkbox',
  'Radio',
  'ListTile',
  'TabBar',
  'DropdownButton',
  'PopupMenuButton',
  'Tooltip',
  'CircularProgressIndicator',
  'LinearProgressIndicator',
  'BottomSheet',
};

/// Names of Material widgets found in the current tree.
Set<String> materialWidgetsIn(WidgetTester tester) => <String>{
      for (final Element e in tester.allElements)
        if (kMaterialWidgetNames.contains(e.widget.runtimeType.toString().split('<').first))
          e.widget.runtimeType.toString(),
    };
