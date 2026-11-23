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
import 'package:attendance_alamin/app/providers/text_size.dart';
import 'package:attendance_alamin/app/router.dart';
import 'package:attendance_alamin/app/shell/storage_banner.dart';
import 'package:attendance_alamin/app/shell/window_chrome.dart';
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
    final TextSizeLevel textSize = ref.watch(textSizeProvider);
    return WidgetsApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      color: BhorThemeData.light().colors.accent,
      onGenerateTitle: (BuildContext context) => context.l10n.commonAppTitle,
      locale: Locale(lang.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (BuildContext context, Widget? child) => AppTextScale(
        level: textSize,
        child: BhorAppRoot(
          themeMode: themeMode,
          child: EffectsMode(
            reduced: reduced,
            child: StorageBanner(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

/// The Bhor theme of [themeMode] ([ThemeMode.system] follows the platform
/// brightness) with the desktop type step on windows >= 1200 wide, default
/// text and icon styles for every route (sheets and dialogs included) and the
/// toast host. It also keeps the Windows title bar in the app's brightness
/// (BhorWindowChrome) and shows focus rings only for keyboard traversal
/// (BhorKeyboardFocusMode). Used by [App] and the test harnesses.
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
    final Brightness brightness = brightnessOf(themeMode, platform);
    final BhorThemeData theme = BhorThemeData.forWidth(brightness, MediaQuery.maybeSizeOf(context)?.width ?? 0);
    return BhorWindowChrome(
      brightness: brightness,
      child: BhorKeyboardFocusMode(
        child: BhorTheme(
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
        ),
      ),
    );
  }
}
