// Root widget: MaterialApp.router with the Aurora themes, the saved language
// and theme mode (switch instantly, no restart), the reduced-effects flag, the
// mesh painted once behind the whole window and the in-memory storage banner.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/router.dart';
import 'package:attendance_alamin/app/shell/storage_banner.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Built once: theme switches must not rebuild ThemeData.
final ThemeData _lightTheme = buildTheme(Brightness.light);
final ThemeData _darkTheme = buildTheme(Brightness.dark);

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    final Lang lang = ref.watch(langProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final bool reduced = ref.watch(reducedEffectsProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      onGenerateTitle: (BuildContext context) => context.l10n.commonAppTitle,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      locale: Locale(lang.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (BuildContext context, Widget? child) => EffectsMode(
        reduced: reduced,
        child: MeshBackground(
          child: StorageBanner(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
