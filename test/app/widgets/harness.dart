// Local pump helper for the Aurora widget tests (M5-B's pumpApp is not merged
// yet). Real theme, real generated l10n, explicit effects mode.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/theme/app_theme.dart';
import 'package:attendance_alamin/app/widgets/effects_mode.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// The four theme x language combinations every widget is tested in.
const List<(Brightness, Lang)> kMatrix = <(Brightness, Lang)>[
  (Brightness.light, Lang.bn),
  (Brightness.light, Lang.en),
  (Brightness.dark, Lang.bn),
  (Brightness.dark, Lang.en),
];

String matrixName((Brightness, Lang) m) => '${m.$1.name} ${m.$2.name}';

AppLocalizations l10nFor(Lang lang) => lookupAppLocalizations(Locale(lang.code));

Future<void> pumpAurora(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  Lang lang = Lang.bn,
  Size size = const Size(800, 900),
  bool reduced = true,
  MediaQueryData Function(MediaQueryData data)? media,
  bool scaffold = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness),
      locale: Locale(lang.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (BuildContext context, Widget? home) {
        MediaQueryData data = MediaQuery.of(context);
        if (media != null) data = media(data);
        return MediaQuery(
          data: data,
          child: EffectsMode(reduced: reduced, child: home!),
        );
      },
      home: scaffold ? Scaffold(body: child) : child,
    ),
  );
  await tester.pump();
}
