// Local pump helper for the shared layout widgets (BentoGrid, PaneLayout):
// a plain WidgetsApp with the app's Bhor root (theme, l10n, toast host), an
// explicit effects mode and an optional MediaQuery tweak.

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/app.dart' show BhorAppRoot;
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/widgets/effects_mode.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

AppLocalizations l10nFor(Lang lang) => lookupAppLocalizations(Locale(lang.code));

Future<void> pumpLayout(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  Lang lang = Lang.bn,
  Size size = const Size(800, 900),
  bool reduced = true,
  MediaQueryData Function(MediaQueryData data)? media,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    WidgetsApp(
      debugShowCheckedModeBanner: false,
      color: BhorThemeData.light().colors.accent,
      locale: Locale(lang.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (BuildContext context, Animation<double> a, Animation<double> s) => builder(context),
      ),
      builder: (BuildContext context, Widget? home) {
        MediaQueryData data = MediaQuery.of(context);
        if (media != null) data = media(data);
        return MediaQuery(
          data: data,
          child: BhorAppRoot(
            themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            child: EffectsMode(reduced: reduced, child: home!),
          ),
        );
      },
      home: child,
    ),
  );
  await tester.pump();
}
