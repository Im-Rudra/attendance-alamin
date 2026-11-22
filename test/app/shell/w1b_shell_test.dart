// W1-B shell: the roll call lives inside the shell (sidebar stays on desktop,
// bottom nav hidden on phones), both roll-call routes still resolve, and the
// Windows title bar follows the app theme through `bhor/window`.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/app.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/router.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/adaptive_scaffold.dart';
import 'package:attendance_alamin/app/shell/window_chrome.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/attendance/ui/batch_roll_call_launcher.dart';
import 'package:attendance_alamin/features/attendance/ui/roll_call_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batch_detail_screen.dart';
import 'package:attendance_alamin/features/home/ui/today_screen.dart';

import 'shell_harness.dart';

const LocalDate _day = LocalDate(2026, 11, 21);

void main() {
  group('roll call inside the shell', () {
    testWidgets('desktop deep link /rollcall/:occ keeps the sidebar', (WidgetTester tester) async {
      await pumpShell(tester, location: Routes.rollCall('s.x.20261121'), size: kDesktop);
      expect(find.byType(RollCallScreen), findsOneWidget);
      expect(find.byKey(AdaptiveScaffold.sidebarKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop batch roll call keeps the sidebar', (WidgetTester tester) async {
      await pumpShell(tester, location: Routes.batchRollCall('b1', _day), size: kDesktop);
      expect(find.byType(BatchRollCallLauncher), findsOneWidget);
      expect(find.byKey(AdaptiveScaffold.sidebarKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone roll call hides the bottom nav; leaving shows it again', (WidgetTester tester) async {
      await pumpShell(tester, location: Routes.rollCall('s.x.20261121'));
      expect(find.byType(RollCallScreen), findsOneWidget);
      expect(find.byKey(AdaptiveScaffold.bottomNavKey), findsNothing);
      await tester.tap(find.byIcon(BhorIcons.close));
      await tester.pumpAndSettle();
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byKey(AdaptiveScaffold.bottomNavKey), findsOneWidget);
    });

    testWidgets('pushed from a batch, the roll call stacks in the batches branch', (WidgetTester tester) async {
      final ShellHarness h = await pumpShell(tester, location: Routes.batch('b1'), size: kDesktop);
      final GoRouter router = h.container(tester).read(routerProvider);
      router.push<void>(Routes.rollCall('s.x.20261121'));
      await tester.pumpAndSettle();
      expect(find.byType(RollCallScreen), findsOneWidget);
      expect(find.byKey(AdaptiveScaffold.sidebarKey), findsOneWidget);
      expect(AdaptiveScaffold.focusRouteOnTop(router), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(BatchDetailScreen), findsOneWidget);
      expect(AdaptiveScaffold.focusRouteOnTop(router), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the roll-call routes are named focus routes', (WidgetTester tester) async {
      final GoRouter router = buildRouter(Routes.today);
      addTearDown(router.dispose);
      final List<String?> names = <String?>[];
      void walk(List<RouteBase> routes) {
        for (final RouteBase r in routes) {
          if (r is GoRoute) names.add(r.name);
          walk(r.routes);
        }
      }

      walk(router.configuration.routes);
      expect(names, containsAll(AdaptiveScaffold.focusRouteNames));
    });
  });

  group('title bar follows the app theme', () {
    testWidgets('setDark is sent on start and on every brightness change (Windows only)', (WidgetTester tester) async {
      final List<Object?> calls = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(BhorWindow.channel, (MethodCall call) async {
        calls.add('${call.method}:${call.arguments}');
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(BhorWindow.channel, null));
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        Widget root(ThemeMode mode) => MediaQuery(
              data: const MediaQueryData(size: Size(1280, 800)),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: BhorAppRoot(themeMode: mode, child: const SizedBox.shrink()),
              ),
            );
        await tester.pumpWidget(root(ThemeMode.light));
        await tester.pump();
        await tester.pumpWidget(root(ThemeMode.dark));
        await tester.pump();
        await tester.pumpWidget(root(ThemeMode.dark));
        await tester.pump();
        expect(calls, <Object?>['setDark:false', 'setDark:true']);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('no call off Windows', (WidgetTester tester) async {
      final List<Object?> calls = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(BhorWindow.channel, (MethodCall call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(BhorWindow.channel, null));
      await tester.pumpWidget(const BhorWindowChrome(brightness: Brightness.dark, child: SizedBox.shrink()));
      await tester.pump();
      expect(calls, isEmpty);
      expect(BhorWindow.supported, isFalse);
    });
  });
}
