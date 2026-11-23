// Device preferences that drive the whole app (plan M5-A): language, theme,
// reduced effects, onboarding flag. Loaded once in bootstrap (no flash of the
// wrong theme or language), then owned by these controllers. Every `set`
// updates the state first, so the UI switches instantly, then persists.

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/text_size.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_repository.dart';

class AppPrefs {
  const AppPrefs({
    required this.lang,
    required this.themeMode,
    required this.reducedEffects,
    required this.onboardingDone,
    this.textSize = TextSizeLevel.normal,
  });

  final Lang lang;
  final TextSizeLevel textSize;
  final ThemeMode themeMode;

  /// Resolved app-level choice: the Settings toggle is "on" OR the one-time
  /// web raster check found this device slow. The OS flags (reduce motion,
  /// high contrast) are applied on top by `EffectsMode.reducedOf`.
  final bool reducedEffects;
  final bool onboardingDone;
}

/// `local_meta` key remembering the one-time web raster check: `slow` / `ok`.
const kEffectsRasterMetaKey = 'effects_raster';

ThemeMode themeModeFromCode(String code) => switch (code) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

String themeModeCode(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

/// Reads every preference the first frame needs.
Future<AppPrefs> loadAppPrefs(SettingsRepository settings, LocalMetaRepository meta) async {
  final String locale = await settings.get(SettingKeys.locale);
  final String theme = await settings.get(SettingKeys.themeMode);
  final String effects = await settings.get(SettingKeys.reducedEffects);
  final bool onboardingDone = await settings.get(SettingKeys.onboardingDone);
  final String size = await settings.get(SettingKeys.textSize);
  final bool slow = await meta.getRaw(kEffectsRasterMetaKey) == 'slow';
  return AppPrefs(
    lang: Lang.fromCode(locale),
    textSize: TextSizeLevel.fromCode(size),
    themeMode: themeModeFromCode(theme),
    reducedEffects: effects == 'on' || slow,
    onboardingDone: onboardingDone,
  );
}

/// Overridden in bootstrap (and tests) with the preloaded [AppPrefs].
final initialPrefsProvider = Provider<AppPrefs>((ref) => throw UnimplementedError());

/// First location of the router: onboarding, a notification's roll call, or
/// Today. Overridden in bootstrap.
final initialLocationProvider = Provider<String>((ref) => Routes.today);

final langProvider = NotifierProvider<LangController, Lang>(LangController.new);
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
final textSizeProvider = NotifierProvider<TextSizeController, TextSizeLevel>(TextSizeController.new);
final reducedEffectsProvider =
    NotifierProvider<ReducedEffectsController, bool>(ReducedEffectsController.new);

class LangController extends Notifier<Lang> {
  @override
  Lang build() => ref.watch(initialPrefsProvider).lang;

  /// Switches the UI language now and remembers it on this device.
  Future<void> set(Lang lang) async {
    if (state == lang) return;
    state = lang;
    await ref.read(settingsRepositoryProvider).set(SettingKeys.locale, lang.code);
  }
}

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialPrefsProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(settingsRepositoryProvider).set(SettingKeys.themeMode, themeModeCode(mode));
  }
}

/// App text size: switches the whole app now, then remembers it on this device.
class TextSizeController extends Notifier<TextSizeLevel> {
  @override
  TextSizeLevel build() => ref.watch(initialPrefsProvider).textSize;

  Future<void> set(TextSizeLevel level) async {
    if (state == level) return;
    state = level;
    await ref.read(settingsRepositoryProvider).set(SettingKeys.textSize, level.code);
  }

  /// One level bigger (+1) or smaller (-1); Ctrl + = / Ctrl + -.
  Future<void> step(int delta) => set(state.step(delta));

  /// Back to Normal; Ctrl + 0.
  Future<void> reset() => set(TextSizeLevel.normal);
}

/// Reduced effects (UX 4 rule 5). State = Settings toggle "on" OR the
/// remembered web raster check said "slow". The OS reduce-motion / high
/// contrast flags are honoured separately by `EffectsMode.reducedOf`.
/// Android low-RAM detection needs a platform channel and is not wired in v1.
class ReducedEffectsController extends Notifier<bool> {
  bool? _slowRaster;

  @override
  bool build() => ref.watch(initialPrefsProvider).reducedEffects;

  /// The Settings toggle: true = "on", false = "auto".
  Future<void> set(bool on) async {
    final bool slow = _slowRaster ??=
        await ref.read(localMetaRepositoryProvider).getRaw(kEffectsRasterMetaKey) == 'slow';
    if (!ref.mounted) return;
    state = on || slow;
    await ref.read(settingsRepositoryProvider).set(SettingKeys.reducedEffects, on ? 'on' : 'auto');
  }

  /// Result of the one-time web raster check (remembered on this device).
  Future<void> reportRasterCheck({required bool slow}) async {
    _slowRaster = slow;
    if (slow) state = true;
    await ref.read(localMetaRepositoryProvider).setRaw(kEffectsRasterMetaKey, slow ? 'slow' : 'ok');
  }
}

/// First route of the app. Onboarding wins while it is not done, then a tapped
/// reminder; otherwise a deep link / reload lands on its own route and only a
/// bare "/" falls back to Today (QA-11).
String pickInitialLocation({
  required String entryRoute,
  required bool onboardingDone,
  String? launchRoute,
}) {
  if (launchRoute != null) return launchRoute;
  if (!onboardingDone) return Routes.onboarding;
  final Uri? uri = Uri.tryParse(entryRoute);
  if (uri == null || !entryRoute.startsWith('/') || uri.path == '/' || uri.path.isEmpty) {
    return Routes.today;
  }
  return entryRoute;
}
