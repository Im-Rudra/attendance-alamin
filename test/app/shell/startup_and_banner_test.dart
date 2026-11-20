// Start-up safety (lead note on M3-A): a database that cannot open shows a
// localised full-screen error with retry, never a blank app; an in-memory
// web database shows the permanent red banner.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/shell/startup_screens.dart';
import 'package:attendance_alamin/app/shell/storage_banner.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/data/db/connection/web_storage_report.dart';
import 'package:attendance_alamin/features/home/ui/today_screen.dart';

import 'shell_harness.dart';

void main() {
  tearDown(() => webStorageReport.value = null);

  testWidgets('loading frame shows the app name, not a blank page', (WidgetTester tester) async {
    await tester.pumpWidget(const StartupApp.loading());
    await tester.pump();
    // The test locale is en-US: the device language decides here.
    expect(find.text(l10nOf(Lang.en).commonAppTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('database failure: localised error with a working retry', (WidgetTester tester) async {
    tester.view.physicalSize = kPhone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int retries = 0;
    await tester.pumpWidget(StartupApp.error(error: StateError('WasmDatabase.open failed'), onRetry: () => retries++));
    await tester.pumpAndSettle();
    final l10n = l10nOf(Lang.en);
    expect(find.text(l10n.shellStartupErrorTitle), findsOneWidget);
    expect(find.text(l10n.shellStartupErrorBody), findsOneWidget);
    // Technical text only behind the details expander.
    expect(find.textContaining('WasmDatabase'), findsNothing);
    await tester.tap(find.text(l10n.commonDetails));
    await tester.pumpAndSettle();
    expect(find.textContaining('WasmDatabase'), findsOneWidget);

    await tester.tap(find.text(l10n.commonRetry));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-memory web storage shows the red banner above every route', (WidgetTester tester) async {
    webStorageReport.value = const WebStorageInfo('inMemory', <String>['indexedDb']);
    await pumpShell(tester);
    expect(find.byKey(StorageBanner.bannerKey), findsOneWidget);
    expect(find.text(l10nOf(Lang.bn).shellStorageInMemory), findsOneWidget);
    final Rect banner = tester.getRect(find.byKey(StorageBanner.bannerKey));
    final Rect page = tester.getRect(find.byType(TodayScreen));
    expect(banner.top, 0);
    expect(page.top, greaterThanOrEqualTo(banner.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('persistent web storage shows no banner', (WidgetTester tester) async {
    webStorageReport.value = const WebStorageInfo('sharedIndexedDb', <String>[]);
    await pumpShell(tester);
    expect(find.byKey(StorageBanner.bannerKey), findsNothing);
  });

  testWidgets('native (no report) shows no banner', (WidgetTester tester) async {
    await pumpShell(tester, size: kDesktop);
    expect(find.byKey(StorageBanner.bannerKey), findsNothing);
  });
}
