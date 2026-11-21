// Root widget: WidgetsApp.router (no MaterialApp) with the Bhor theme picked
// by the saved theme mode (light / dark / follow the system; switches
// instantly, no restart), the saved language, the reduced-effects flag, the
// app-level toast host and the in-memory storage banner. Everything below it
// reads `context.bhor`; nothing visible comes from Material.

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/router.dart';
import 'package:attendance_alamin/app/shell/storage_banner.dart';
import 'package:attendance_alamin/app/widgets/effects_mode.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    final Lang lang = ref.watch(langProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final bool reduced = ref.watch(reducedEffectsProvider);
    return WidgetsApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      color: BhorThemeData.light().colors.accent,
      onGenerateTitle: (BuildContext context) => context.l10n.commonAppTitle,
      locale: Locale(lang.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (BuildContext context, Widget? child) => BhorAppRoot(
        themeMode: themeMode,
        child: EffectsMode(
          reduced: reduced,
          child: StorageBanner(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// The Bhor theme of [themeMode] ([ThemeMode.system] follows the platform
/// brightness), default text and icon styles for every route (sheets and
/// dialogs included) and the toast host. Used by [App] and the test harnesses.
class BhorAppRoot extends StatelessWidget {
  const BhorAppRoot({super.key, required this.themeMode, required this.child});

  final ThemeMode themeMode;
  final Widget child;

  static Brightness brightnessOf(ThemeMode mode, Brightness platform) => switch (mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => platform,
      };

  @override
  Widget build(BuildContext context) {
    final Brightness platform = MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    final BhorThemeData theme = BhorThemeData.of(brightnessOf(themeMode, platform));
    return BhorTheme(
      data: theme,
      child: DefaultTextStyle(
        style: theme.type.body,
        child: IconTheme(
          data: IconThemeData(color: theme.colors.text2, size: 22),
          child: ColoredBox(
            color: theme.colors.bg,
            child: BhorToastHost(child: child),
          ),
        ),
      ),
    );
  }
}
