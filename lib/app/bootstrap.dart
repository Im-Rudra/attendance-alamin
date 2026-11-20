// App start (plan M5-A, Arch 1.6 + 4B):
//  1. show a loading frame at once (never a blank window);
//  2. open the database and ensure this device's id; if that fails (e.g. a
//     browser that blocks the web database), show a full-screen localised
//     error with a retry instead of crashing;
//  3. ask the browser to keep our storage (web, fire and forget);
//  4. preload the device preferences (language, theme, effects, onboarding);
//  5. pick the first route: onboarding, a notification's roll call, or Today;
//  6. run the app; on web, run the one-time raster check (UX 4 rule 5).

import 'dart:async';
import 'dart:ui' show FrameTiming, TimingsCallback;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/app.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/services/reminder_bootstrap.dart';
import 'package:attendance_alamin/app/shell/startup_screens.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/connection/open_connection.dart';
import 'package:attendance_alamin/data/db/connection/storage_persist.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';

/// How long the first database query may take before we call it a failure.
const Duration kDatabaseOpenTimeout = Duration(seconds: 30);

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StartupApp.loading());
  final ProviderContainer? container = await _start();
  if (container == null) return;
  runApp(UncontrolledProviderScope(container: container, child: const App()));
  if (kIsWeb) _startWebRasterCheck(container);
}

/// Opens everything; returns null after showing the error screen.
Future<ProviderContainer?> _start() async {
  AppDatabase? db;
  ProviderContainer? container;
  try {
    final AppDatabase opened = db = AppDatabase(openConnection());
    // The first query opens the connection (web: WasmDatabase.open).
    final String deviceId = await ensureDeviceId(opened).timeout(kDatabaseOpenTimeout);
    if (kIsWeb) unawaited(requestPersistentStorage());

    late final AppPrefs prefs;
    String location = Routes.today;
    final ProviderContainer c = container = ProviderContainer(
      retry: (int _, Object __) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(opened),
        deviceIdProvider.overrideWithValue(deviceId),
        initialPrefsProvider.overrideWith((Ref ref) => prefs),
        initialLocationProvider.overrideWith((Ref ref) => location),
      ],
    );
    prefs = await loadAppPrefs(c.read(settingsRepositoryProvider), c.read(localMetaRepositoryProvider));
    if (!prefs.onboardingDone) location = Routes.onboarding;

    // Reminders never block the start: a failure only means no launch route.
    String? launch;
    try {
      launch = await initRemindersAndGetLaunchRoute(c);
    } catch (_) {
      launch = null;
    }
    if (launch != null) location = launch;
    return c;
  } catch (error) {
    container?.dispose();
    runApp(StartupApp.error(error: error, onRetry: () => unawaited(bootstrap())));
    final AppDatabase? failed = db;
    if (failed != null) unawaited(_closeQuietly(failed));
    return null;
  }
}

Future<void> _closeQuietly(AppDatabase db) async {
  try {
    await db.close().timeout(const Duration(seconds: 5));
  } catch (_) {
    // The connection never opened; nothing to release.
  }
}

/// Web only (UX 4 rule 5): if the first 120 frames average more than 12 ms of
/// raster time, turn reduced effects on. Runs once per device; the result is
/// remembered in local_meta.
void _startWebRasterCheck(ProviderContainer container) {
  container.read(localMetaRepositoryProvider).getRaw(kEffectsRasterMetaKey).then((String? done) {
    if (done != null) return;
    const int frames = 120;
    final List<int> rasterUs = <int>[];
    late final TimingsCallback callback;
    callback = (List<FrameTiming> timings) {
      for (final FrameTiming t in timings) {
        rasterUs.add(t.rasterDuration.inMicroseconds);
      }
      if (rasterUs.length < frames) return;
      SchedulerBinding.instance.removeTimingsCallback(callback);
      int sum = 0;
      for (int i = 0; i < frames; i++) {
        sum += rasterUs[i];
      }
      final bool slow = sum ~/ frames > 12000;
      unawaited(container.read(reducedEffectsProvider.notifier).reportRasterCheck(slow: slow));
    };
    SchedulerBinding.instance.addTimingsCallback(callback);
  }, onError: (Object _) {});
}
