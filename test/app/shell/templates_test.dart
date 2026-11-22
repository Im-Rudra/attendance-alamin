// W1-B page templates (docs/council/16-windows-rebuild-plan.md W1-B 5):
// layout smoke tests at phone / desktop / wide widths, both themes.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/shell/templates/templates.dart';

import '../ds/ds_harness.dart';

const List<Size> _sizes = <Size>[Size(390, 844), Size(1280, 800), Size(1700, 1000)];

String _label(Size s) => '${s.width.toInt()}';

void main() {
  group('BhorDashboardPage', () {
    for (final Size size in _sizes) {
      for (final Brightness br in Brightness.values) {
        testWidgets('header, hero and masonry cards [${_label(size)} ${br.name}]', (WidgetTester tester) async {
          await pumpDs(
            tester,
            BhorDashboardPage(
              overline: 'শনিবার, ২১ নভেম্বর',
              title: 'শুভ সকাল',
              actions: <Widget>[BhorButton(label: 'নতুন', onPressed: () {})],
              hero: const SizedBox(key: Key('hero'), height: 120),
              children: const <Widget>[
                SizedBox(key: Key('c1'), height: 200),
                SizedBox(key: Key('c2'), height: 90),
                SizedBox(key: Key('c3'), height: 140),
              ],
            ),
            size: size,
            brightness: br,
            scroll: false,
          );
          expect(find.text('শুভ সকাল'), findsOneWidget);
          expect(find.text('শনিবার, ২১ নভেম্বর'), findsOneWidget);
          final Rect hero = tester.getRect(find.byKey(const Key('hero')));
          // Centred and never wider than 1320.
          expect(hero.width, lessThanOrEqualTo(BhorDashboardPage.defaultMaxWidth));
          expect((hero.center.dx - size.width / 2).abs(), lessThan(1));
          final Rect c1 = tester.getRect(find.byKey(const Key('c1')));
          final Rect c2 = tester.getRect(find.byKey(const Key('c2')));
          // Content-sized: each card keeps its own height.
          expect(c1.height, 200);
          expect(c2.height, 90);
          if (size.width < 700) {
            expect(c2.top, greaterThan(c1.bottom), reason: 'one column on phones');
          } else {
            expect(c2.top, c1.top, reason: 'side by side on desktop');
          }
          expectClean(tester);
        });
      }
    }
  });

  group('BhorMasterDetailPage', () {
    Widget page() => BhorMasterDetailPage(
          master: const SizedBox.expand(key: Key('list')),
          detail: Builder(
            builder: (BuildContext context) => Column(
              children: <Widget>[
                const Text('বিস্তারিত'),
                ?BhorMasterDetailPage.foldedRailOf(context),
              ],
            ),
          ),
          rail: const Text('রুটিন', key: Key('rail')),
        );

    testWidgets('phone: the detail alone, the rail folded into it', (WidgetTester tester) async {
      await pumpDs(tester, page(), size: const Size(390, 844), scroll: false);
      expect(find.byKey(const Key('list')), findsNothing);
      expect(find.text('বিস্তারিত'), findsOneWidget);
      expect(find.byKey(const Key('rail')), findsOneWidget);
      expect(find.byKey(BhorMasterDetailPage.railKey), findsNothing);
      expectClean(tester);
    });

    testWidgets('1280: list 360 | detail, rail folded (no 4th column)', (WidgetTester tester) async {
      await pumpDs(tester, page(), size: const Size(1280, 800), scroll: false);
      expect(tester.getSize(find.byKey(BhorMasterDetailPage.masterKey)).width, 360);
      expect(find.byKey(BhorMasterDetailPage.railKey), findsNothing);
      expect(
        find.descendant(of: find.byKey(BhorMasterDetailPage.detailKey), matching: find.byKey(const Key('rail'))),
        findsOneWidget,
      );
      expectClean(tester);
    });

    testWidgets('1700: the rail gets its own column', (WidgetTester tester) async {
      await pumpDs(tester, page(), size: const Size(1700, 1000), scroll: false);
      expect(tester.getSize(find.byKey(BhorMasterDetailPage.railKey)).width, BhorMasterDetailPage.defaultRailWidth);
      expect(
        find.descendant(of: find.byKey(BhorMasterDetailPage.detailKey), matching: find.byKey(const Key('rail'))),
        findsNothing,
      );
      expectClean(tester);
    });

    testWidgets('wide with nothing selected shows the empty detail', (WidgetTester tester) async {
      await pumpDs(
        tester,
        const BhorMasterDetailPage(
          master: SizedBox.expand(),
          emptyDetail: BhorEmptyState(icon: BhorIcons.batches, title: 'একটি ব্যাচ বেছে নিন'),
        ),
        size: const Size(1280, 800),
        scroll: false,
      );
      expect(find.text('একটি ব্যাচ বেছে নিন'), findsOneWidget);
      expectClean(tester);
    });
  });

  group('BhorSettingsPage', () {
    Widget page(ValueChanged<String> onSelect, {String? crumb, VoidCallback? onCrumb}) => BhorSettingsPage(
          sections: const <BhorSettingsSection>[
            BhorSettingsSection(id: 'look', label: 'চেহারা', icon: BhorIcons.light),
            BhorSettingsSection(id: 'holidays', label: 'ছুটি', icon: BhorIcons.holiday),
          ],
          selected: 'look',
          onSelect: onSelect,
          title: 'রসিদের টেমপ্লেট',
          crumb: crumb,
          onCrumb: onCrumb,
          child: const SizedBox(key: Key('body'), height: 300),
        );

    testWidgets('desktop: nav 240 + a top-aligned 720 column; nav taps select', (WidgetTester tester) async {
      String? picked;
      bool crumbed = false;
      await pumpDs(
        tester,
        page((String id) => picked = id, crumb: 'বেতন ও পেমেন্ট', onCrumb: () => crumbed = true),
        size: const Size(1280, 800),
        scroll: false,
      );
      expect(tester.getSize(find.byKey(BhorSettingsPage.navKey)).width, BhorSettingsPage.navWidth);
      final Rect body = tester.getRect(find.byKey(const Key('body')));
      expect(body.width, BhorSettingsPage.contentMaxWidth);
      final Rect title = tester.getRect(find.text('রসিদের টেমপ্লেট'));
      expect(title.top, lessThan(160), reason: 'top-aligned, not centred vertically');
      await tester.tap(find.text('ছুটি'));
      await tester.pump();
      expect(picked, 'holidays');
      await tester.tap(find.byKey(BhorSettingsPage.crumbKey));
      await tester.pump();
      expect(crumbed, isTrue);
      expectClean(tester);
    });

    testWidgets('phone: content only', (WidgetTester tester) async {
      await pumpDs(tester, page((_) {}), size: const Size(390, 844), scroll: false);
      expect(find.byKey(BhorSettingsPage.navKey), findsNothing);
      expect(find.byKey(const Key('body')), findsOneWidget);
      expectClean(tester);
    });
  });

  group('BhorFocusPage', () {
    for (final Size size in _sizes) {
      testWidgets('slim bar, centred 880 body, sticky bar [${_label(size)}]', (WidgetTester tester) async {
        int backs = 0;
        await pumpDs(
          tester,
          BhorFocusPage(
            title: 'হাজিরা',
            subtitle: 'নবম গণিত',
            onBack: () => backs++,
            summary: const Text('২৮ উপস্থিত'),
            primary: BhorButton(label: 'সংরক্ষণ', onPressed: () {}),
            body: const SizedBox(key: Key('roster'), height: 2000),
          ),
          size: size,
          scroll: false,
        );
        final Rect roster = tester.getRect(find.byKey(const Key('roster')));
        expect(roster.width, lessThanOrEqualTo(BhorFocusPage.defaultMaxWidth));
        expect((roster.center.dx - size.width / 2).abs(), lessThan(1));
        // The bar sits at the bottom of the window, above the scrolling body.
        final Rect bar = tester.getRect(find.byKey(BhorFocusPage.barKey));
        expect(bar.bottom, size.height);
        expect(find.text('২৮ উপস্থিত'), findsOneWidget);
        expect(find.text('সংরক্ষণ'), findsOneWidget);

        // Esc = back while the page is on top.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(backs, 1);
        expectClean(tester);
      });
    }

    testWidgets('Esc does nothing while a dialog is above the page', (WidgetTester tester) async {
      int backs = 0;
      await pumpDs(
        tester,
        Builder(
          builder: (BuildContext context) => BhorFocusPage(
            title: 'হাজিরা',
            onBack: () => backs++,
            actions: <Widget>[
              BhorButton(
                label: 'খুলুন',
                onPressed: () => Navigator.of(context).push<void>(
                  PageRouteBuilder<void>(
                    opaque: false,
                    pageBuilder: (BuildContext _, Animation<double> a, Animation<double> s) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            body: const SizedBox(height: 100),
          ),
        ),
        size: const Size(1280, 800),
        scroll: false,
      );
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(backs, 0);
    });
  });
}
