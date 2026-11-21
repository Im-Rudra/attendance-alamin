// Fluid Bhor (docs/council/13-fluid-ui-spec.md): motion tokens, the
// reduced-motion path, every rebuilt component's animation settling, the
// motion primitives (stagger, count-up, fade-through, pane switcher,
// success) and the adaptive container (sheet on phone, side panel or dialog
// on desktop).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/widgets/effects_mode.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import 'ds_harness.dart';

const Size _desktop = Size(1280, 800);

/// A button that runs [onPressed] with a context under the navigator.
Widget _opener(String label, void Function(BuildContext context) onPressed) => Builder(
      builder: (BuildContext context) => BhorButton(label: label, onPressed: () => onPressed(context)),
    );

void main() {
  group('motion tokens', () {
    test('durations and springs follow the spec', () {
      expect(BhorMotion.instant, const Duration(milliseconds: 80));
      expect(BhorMotion.fast.inMilliseconds, inInclusiveRange(150, 200));
      expect(BhorMotion.base.inMilliseconds, inInclusiveRange(250, 300));
      expect(BhorMotion.slow.inMilliseconds, inInclusiveRange(400, 500));
      expect(BhorMotion.countUpMin, const Duration(milliseconds: 260));
      expect(BhorMotion.countUpMax, const Duration(milliseconds: 480));
      expect(BhorMotion.staggerStep, const Duration(milliseconds: 30));
      expect(BhorMotion.staggerCap, 8);
      expect(BhorMotion.springSnappy.stiffness, 420);
      expect(BhorMotion.springSnappy.damping, 26);
      expect(BhorMotion.springGentle.mass, 1);
      // The spring curve overshoots, the ease does not.
      final double peak = <double>[for (int i = 1; i < 100; i++) BhorMotion.spring.transform(i / 100)]
          .reduce((double a, double b) => a > b ? a : b);
      expect(peak, greaterThan(1));
      expect(BhorMotion.ease.transform(0.5), lessThanOrEqualTo(1));
      expect(BhorMotion.pressScale, 0.96);
    });

    testWidgets('reduced motion: EffectsMode or OS flag gives the 120 ms fade', (WidgetTester tester) async {
      late Duration reduced;
      late Duration normal;
      late Curve curve;
      await tester.pumpWidget(Column(children: <Widget>[
        EffectsMode(
          reduced: true,
          child: Builder(builder: (BuildContext c) {
            reduced = BhorMotion.of(c, BhorMotion.slow);
            curve = BhorMotion.curveOf(c, BhorMotion.spring);
            return const SizedBox();
          }),
        ),
        Builder(builder: (BuildContext c) {
          normal = BhorMotion.of(c, BhorMotion.slow);
          return const SizedBox();
        }),
      ]));
      expect(reduced, BhorMotion.reducedFade);
      expect(curve, BhorMotion.ease);
      expect(normal, BhorMotion.slow);
    });
  });

  group('tokens', () {
    test('fluid palette values', () {
      final BhorColors l = BhorColors.light;
      final BhorColors d = BhorColors.dark;
      expect(l.bg, const Color(0xFFF6F5F1));
      expect(l.soft, const Color(0xFFEFEDE8));
      expect(l.soft2, const Color(0xFFE3E0D8));
      expect(l.accent, const Color(0xFF5B4FE0));
      expect(l.surface2, l.soft);
      expect(d.bg, const Color(0xFF0F1014));
      expect(d.surface, const Color(0xFF191B21));
      expect(d.onAccentFill, const Color(0xFFFFFFFF));
      expect(BhorRadius.control, 14);
      expect(BhorRadius.sheet, 28);
      expect(BhorRadius.tag, BhorRadius.pill);
      expect(BhorSize.field, 56);
      expect(BhorSize.control, 46);
    });

    test('Phosphor icons: regular and fill differ', () {
      expect(BhorIcons.today.fontFamily, isNot(BhorIcons.todayFill.fontFamily));
      expect(BhorIcons.today.fontPackage, 'phosphor_flutter');
    });
  });

  group('components animate and settle', () {
    testWidgets('button: press scale, arrow, loading -> done', (WidgetTester tester) async {
      bool done = false;
      bool loading = false;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => Column(children: <Widget>[
            BhorButton(label: 'পরের ধাপ', arrow: true, onPressed: () {}),
            BhorButton(
              label: 'সেভ করুন',
              loading: loading,
              done: done,
              onPressed: () => set(() => loading = true),
            ),
            BhorButton(label: 'শেষ', onPressed: () => set(() {
              loading = false;
              done = true;
            })),
          ]),
        ),
      );
      expect(find.byIcon(BhorIcons.arrowRight), findsOneWidget);
      final TestGesture g = await tester.startGesture(tester.getCenter(find.text('পরের ধাপ')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      final AnimatedScale scale = tester.widget<AnimatedScale>(
          find.ancestor(of: find.text('পরের ধাপ'), matching: find.byType(AnimatedScale)).first);
      expect(scale.scale, BhorMotion.pressScale);
      await g.up();
      await tester.pumpAndSettle();

      await tester.tap(find.text('সেভ করুন'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BhorSpinner), findsOneWidget);
      await tester.tap(find.text('শেষ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(dsL10n(Lang.bn).dsDone), findsOneWidget);
      expect(find.byIcon(BhorIcons.check), findsOneWidget);
      expectClean(tester);
    });

    testWidgets('text field: the label floats on focus', (WidgetTester tester) async {
      await pumpDs(tester, const BhorTextField(label: 'নাম', hint: 'যেমন: রহিম'));
      double labelSize() => tester.widget<Text>(find.text('নাম')).style!.fontSize!;
      expect(labelSize(), 15);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(labelSize(), 12);
      expectClean(tester);
    });

    testWidgets('text field: error ring and message', (WidgetTester tester) async {
      await pumpDs(tester, const BhorTextField(label: 'ফোন', initialValue: '০১', error: 'ভুল নম্বর'));
      await tester.pumpAndSettle();
      expect(find.text('ভুল নম্বর'), findsOneWidget);
      expectClean(tester);
    });

    testWidgets('select: popover on desktop, sheet on phone', (WidgetTester tester) async {
      Widget select() => StatefulBuilder(
            builder: (BuildContext context, StateSetter set) => BhorSelect<int>(
              label: 'ব্যাচ',
              value: 1,
              options: const <BhorOption<int>>[BhorOption<int>(1, 'এক'), BhorOption<int>(2, 'দুই')],
              onChanged: (_) {},
            ),
          );
      await pumpDs(tester, select(), size: _desktop);
      await tester.tap(find.byType(BhorSelect<int>));
      await tester.pumpAndSettle();
      expect(find.text('দুই'), findsOneWidget);
      expect(find.byType(BhorSheetFrame), findsNothing);
      final AnimatedRotation chevron = tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(chevron.turns, 0.5);
      await tester.tapAt(const Offset(1200, 700));
      await tester.pumpAndSettle();

      await pumpDs(tester, select());
      await tester.tap(find.byType(BhorSelect<int>));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSheetFrame), findsOneWidget);
      expect(find.text('দুই'), findsOneWidget);
      expectClean(tester);
    });

    testWidgets('segmented thumb glides; chip check slides in; switch springs', (WidgetTester tester) async {
      int seg = 0;
      bool chip = false;
      bool sw = false;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => Column(children: <Widget>[
            BhorSegmented<int>(
              segments: const <BhorSegment<int>>[BhorSegment<int>(0, 'বকেয়া'), BhorSegment<int>(1, 'আদায়')],
              value: seg,
              onChanged: (int v) => set(() => seg = v),
            ),
            BhorChip(label: 'জরুরি', selected: chip, onSelected: (bool v) => set(() => chip = v)),
            BhorSwitch(value: sw, semanticLabel: 'রিমাইন্ডার', onChanged: (bool v) => set(() => sw = v)),
          ]),
        ),
      );
      await tester.tap(find.text('আদায়'));
      await tester.tap(find.text('জরুরি'));
      await tester.tap(find.byType(BhorSwitch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final AnimatedAlign thumb = tester.widget<AnimatedAlign>(
          find.descendant(of: find.byType(BhorSegmented<int>), matching: find.byType(AnimatedAlign)));
      expect((thumb.alignment as Alignment).x, 1);
      await tester.pumpAndSettle();
      expect(seg, 1);
      expect(chip, isTrue);
      expect(sw, isTrue);
      expect(find.descendant(of: find.byType(BhorChip), matching: find.byIcon(BhorIcons.check)), findsOneWidget);
      final Size slot = tester.getSize(find
          .ancestor(of: find.byIcon(BhorIcons.check), matching: find.byType(AnimatedContainer))
          .first);
      expect(slot.width, 20);
      expectClean(tester);
    });

    for (final bool iconOnly in <bool>[false, true]) {
      testWidgets('attendance toggle thumb glides [iconOnly $iconOnly]', (WidgetTester tester) async {
        final AppLocalizations l10n = dsL10n(Lang.bn);
        AttendanceKind value = AttendanceKind.present;
        await pumpDs(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter set) => Row(children: <Widget>[
              if (iconOnly)
                BhorAttendanceToggle(value: value, iconOnly: true, onChanged: (AttendanceKind k) => set(() => value = k))
              else
                Expanded(
                  child: BhorAttendanceToggle(value: value, onChanged: (AttendanceKind k) => set(() => value = k)),
                ),
            ]),
          ),
        );
        double thumbLeft() => tester
            .widget<AnimatedPositioned>(
                find.descendant(of: find.byType(BhorAttendanceToggle), matching: find.byType(AnimatedPositioned)))
            .left!;
        expect(thumbLeft(), 0);
        if (iconOnly) {
          expect(find.text(l10n.uiAttLate), findsNothing);
          await tester.tap(find.byIcon(BhorIcons.late));
        } else {
          await tester.tap(find.text(l10n.uiAttLate));
        }
        await tester.pumpAndSettle();
        expect(value, AttendanceKind.late);
        expect(thumbLeft(), greaterThan(0));
        expectClean(tester);
      });
    }

    testWidgets('stepper counts and clamps', (WidgetTester tester) async {
      int v = 1;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) =>
              Row(children: <Widget>[BhorStepper(value: v, min: 1, max: 3, onChanged: (int x) => set(() => v = x))]),
        ),
      );
      await tester.tap(find.byIcon(BhorIcons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(BhorIcons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(BhorIcons.add));
      await tester.pumpAndSettle();
      expect(v, 3);
      expect(find.text('৩'), findsOneWidget);
      await tester.tap(find.byIcon(BhorIcons.minus));
      await tester.pumpAndSettle();
      expect(v, 2);
      expectClean(tester);
    });

    testWidgets('bottom nav and sidebar indicators glide; icons switch to fill', (WidgetTester tester) async {
      int nav = 0;
      const List<BhorNavItem> items = <BhorNavItem>[
        BhorNavItem(icon: BhorIcons.today, activeIcon: BhorIcons.todayFill, label: 'আজ'),
        BhorNavItem(icon: BhorIcons.batches, activeIcon: BhorIcons.batchesFill, label: 'ব্যাচ'),
      ];
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => Column(children: <Widget>[
            BhorBottomNav(items: items, index: nav, onTap: (int i) => set(() => nav = i)),
            SizedBox(
              height: 300,
              child: Row(children: <Widget>[
                BhorSidebar(brand: 'হাজিরা খাতা', items: items, index: nav, onTap: (int i) => set(() => nav = i)),
              ]),
            ),
          ]),
        ),
        size: const Size(800, 800),
      );
      expect(find.byIcon(BhorIcons.todayFill), findsNWidgets(2));
      await tester.tap(find.descendant(of: find.byType(BhorBottomNav), matching: find.text('ব্যাচ')));
      await tester.pumpAndSettle();
      expect(nav, 1);
      expect(find.byIcon(BhorIcons.batchesFill), findsNWidgets(2));
      final AnimatedPositioned side = tester.widget<AnimatedPositioned>(
          find.descendant(of: find.byType(BhorSidebar), matching: find.byType(AnimatedPositioned)));
      expect(side.top, BhorSidebar.itemHeight + BhorSidebar.itemGap);
      // Brand mark: the first grapheme of the brand.
      expect(find.text('হা'), findsOneWidget);
      expectClean(tester);
    });

    testWidgets('toast is a floating pill with a soft shadow', (WidgetTester tester) async {
      await pumpDs(
        tester,
        _opener('দেখান', (BuildContext context) => BhorToast.show(context, message: 'সেভ হয়েছে', icon: BhorIcons.check)),
      );
      await tester.tap(find.text('দেখান'));
      await tester.pumpAndSettle();
      final Container pill = tester.widget<Container>(
          find.ancestor(of: find.text('সেভ হয়েছে'), matching: find.byType(Container)).first);
      final BoxDecoration d = pill.decoration! as BoxDecoration;
      expect(d.borderRadius, BorderRadius.circular(BhorRadius.pill));
      expect(d.boxShadow, isNotEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('সেভ হয়েছে'), findsNothing);
    });

    testWidgets('progress fills from 0; skeleton is static when reduced', (WidgetTester tester) async {
      await pumpDs(
        tester,
        const Column(children: <Widget>[BhorProgress(value: 0.5), BhorSkeleton(width: 100)]),
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      final FractionallySizedBox fill = tester.widget<FractionallySizedBox>(
          find.descendant(of: find.byType(BhorProgress), matching: find.byType(FractionallySizedBox)));
      expect(fill.widthFactor, 0.5);
      final Container block = tester.widget<Container>(
          find.descendant(of: find.byType(BhorSkeleton), matching: find.byType(Container)));
      expect((block.decoration! as BoxDecoration).gradient, isNull);
    });
  });

  group('motion primitives', () {
    testWidgets('count-up starts at 0 and settles on the value (Bangla digits)', (WidgetTester tester) async {
      await pumpDs(tester, const BhorCountUp(value: 240));
      expect(find.text('২৪০'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('২৪০'), findsOneWidget);
      expectClean(tester);
    });

    testWidgets('count-up money rolls to the new amount', (WidgetTester tester) async {
      int amount = 1000;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => Column(children: <Widget>[
            BhorCountUp.money(amount: amount),
            BhorButton(label: 'আরও', onPressed: () => set(() => amount = 2500)),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('৳ ১,০০০', findRichText: true), findsOneWidget);
      await tester.tap(find.text('আরও'));
      await tester.pumpAndSettle();
      expect(find.text('৳ ২,৫০০', findRichText: true), findsOneWidget);
    });

    testWidgets('reduced motion: count-up shows the final value at once', (WidgetTester tester) async {
      await pumpDs(tester, const BhorCountUp(value: 240), disableAnimations: true);
      expect(find.text('২৪০'), findsOneWidget);
    });

    testWidgets('stagger: first paint only, capped at 8', (WidgetTester tester) async {
      bool more = false;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => BhorStaggerScope(
            child: Column(children: <Widget>[
              for (int i = 0; i < 10; i++) BhorStagger(index: i, child: Text('সারি $i')),
              if (more) const BhorStagger(index: 0, child: Text('নতুন')),
              BhorButton(label: 'যোগ', onPressed: () => set(() => more = true)),
            ]),
          ),
        ),
      );
      Finder fadeOf(String text) =>
          find.ancestor(of: find.text(text), matching: find.byType(FadeTransition));
      // Item 3 is still waiting for its slot; item 9 is past the cap.
      expect(tester.widget<FadeTransition>(fadeOf('সারি 3').first).opacity.value, lessThan(1));
      expect(fadeOf('সারি 9'), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(fadeOf('সারি 3').first).opacity.value, 1);
      // Mounted after the first paint: no entrance.
      await tester.tap(find.text('যোগ'));
      await tester.pump();
      expect(fadeOf('নতুন'), findsNothing);
      expectClean(tester);
    });

    testWidgets('stagger is off when motion is reduced', (WidgetTester tester) async {
      await pumpDs(
        tester,
        const BhorStaggerScope(child: Column(children: <Widget>[BhorStagger(index: 1, child: Text('সারি'))])),
        disableAnimations: true,
      );
      expect(find.ancestor(of: find.text('সারি'), matching: find.byType(FadeTransition)), findsNothing);
    });

    testWidgets('fade-through and pane switcher swap keyed content', (WidgetTester tester) async {
      int tab = 0;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => Column(children: <Widget>[
            BhorFadeThrough(child: KeyedSubtree(key: ValueKey<int>(tab), child: Text('ট্যাব $tab'))),
            BhorPaneSwitcher(paneKey: tab, child: Text('প্যান $tab')),
            BhorButton(label: 'বদলান', onPressed: () => set(() => tab = 1)),
          ]),
        ),
      );
      await tester.tap(find.text('বদলান'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Both are on screen mid-switch.
      expect(find.text('ট্যাব 0'), findsOneWidget);
      expect(find.text('ট্যাব 1'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('ট্যাব 0'), findsNothing);
      expect(find.text('প্যান 0'), findsNothing);
      expect(find.text('প্যান 1'), findsOneWidget);
      expectClean(tester);
    });

    testWidgets('success circle pops, draws and reports done', (WidgetTester tester) async {
      int done = 0;
      await pumpDs(tester, BhorSuccess(label: 'হয়েছে', onDone: () => done++));
      await tester.pump(const Duration(milliseconds: 200));
      expect(done, 0);
      await tester.pumpAndSettle();
      expect(done, 1);
      expect(find.text('হয়েছে'), findsOneWidget);
    });
  });

  group('adaptive container', () {
    Widget panelOpener(BhorPanelKind kind, List<String?> results) => _opener('খুলুন', (BuildContext context) async {
          results.add(await showBhorPanel<String>(
            context,
            kind: kind,
            title: 'টাকা নিন',
            builder: (BuildContext ctx) => const BhorTextField(label: 'টাকা'),
            footer: (BuildContext ctx) =>
                BhorButton(label: 'সেভ করুন', expand: true, onPressed: () => Navigator.of(ctx).pop('ok')),
          ));
        });

    testWidgets('phone: a bottom sheet', (WidgetTester tester) async {
      final List<String?> results = <String?>[];
      await pumpDs(tester, panelOpener(BhorPanelKind.form, results));
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSheetFrame), findsOneWidget);
      expect(find.byType(BhorSidePanelFrame), findsNothing);
      await tester.tap(find.text('সেভ করুন'));
      await tester.pumpAndSettle();
      expect(results, <String?>['ok']);
      expect(materialWidgetsIn(tester), isEmpty);
    });

    testWidgets('desktop form: a floating side panel; Esc closes it', (WidgetTester tester) async {
      final List<String?> results = <String?>[];
      await pumpDs(tester, panelOpener(BhorPanelKind.form, results), size: _desktop);
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSidePanelFrame), findsOneWidget);
      expect(find.byType(BhorSheetFrame), findsNothing);
      // Floating: inset 10 from the right, top and bottom edges.
      final Rect card = tester.getRect(find
          .ancestor(of: find.text('টাকা নিন'), matching: find.byType(Container))
          .first);
      expect(card.right, _desktop.width - 10);
      expect(card.top, 10);
      expect(card.bottom, _desktop.height - 10);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(BhorSidePanelFrame), findsNothing);
      expect(results, <String?>[null]);
    });

    testWidgets('desktop confirm: a centred dialog', (WidgetTester tester) async {
      final List<String?> results = <String?>[];
      await pumpDs(tester, panelOpener(BhorPanelKind.confirm, results), size: _desktop);
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorDialog), findsOneWidget);
      expect(find.byType(BhorSidePanelFrame), findsNothing);
      await tester.tap(find.text('সেভ করুন'));
      await tester.pumpAndSettle();
      expect(results, <String?>['ok']);
    });

    testWidgets('side panel leaves the sidebar undimmed', (WidgetTester tester) async {
      await pumpDs(
        tester,
        BhorChromeInset(
          start: 248,
          child: _opener('খুলুন', (BuildContext context) {
            showBhorSidePanel<void>(context, title: 'প্যানেল', builder: (_) => const SizedBox(height: 40));
          }),
        ),
        size: _desktop,
      );
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      final Rect dim = tester.getRect(find
          .descendant(of: find.byType(BhorSidePanelFrame), matching: find.byType(ColoredBox))
          .first);
      expect(dim.left, 248);
    });

    testWidgets('success in a sheet: check, close, toast', (WidgetTester tester) async {
      final List<bool?> results = <bool?>[];
      await pumpDs(
        tester,
        _opener('খুলুন', (BuildContext context) async {
          results.add(await showBhorSheet<bool>(
            context,
            title: 'টাকা নিন',
            builder: (BuildContext ctx) => BhorButton(
              label: 'সেভ করুন',
              onPressed: () => showBhorSuccess<bool>(ctx, result: true, label: 'জমা হয়েছে', toast: '৳১,০০০ জমা হয়েছে'),
            ),
          ));
        }),
      );
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('সেভ করুন'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BhorSuccess), findsOneWidget);
      await tester.pumpAndSettle();
      expect(results, <bool?>[true]);
      expect(find.byType(BhorSheetFrame), findsNothing);
      expect(find.text('৳১,০০০ জমা হয়েছে'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('expanding sheet opens at 60% and grows when dragged up', (WidgetTester tester) async {
      await pumpDs(
        tester,
        _opener('খুলুন', (BuildContext context) {
          showBhorSheet<void>(context, title: 'নতুন', expanding: true, builder: (_) => const SizedBox(height: 40));
        }),
      );
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      final double h0 = tester.getSize(find.byType(BhorSheetFrame)).height;
      final double sheet0 = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-handle'))).top;
      expect(800 - sheet0, closeTo(800 * 0.94 * BhorSheetFrame.minExtent, 4));
      await tester.drag(find.byKey(const ValueKey<String>('bhor-sheet-handle')), const Offset(0, -300));
      await tester.pumpAndSettle();
      final double sheet1 = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-handle'))).top;
      expect(sheet1, lessThan(sheet0));
      expect(h0, greaterThan(0));
      expectClean(tester);
    });

    testWidgets('reduced motion: panels still open and close', (WidgetTester tester) async {
      final List<String?> results = <String?>[];
      await pumpDs(tester, panelOpener(BhorPanelKind.form, results), size: _desktop, disableAnimations: true);
      await tester.tap(find.text('খুলুন'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(BhorSidePanelFrame), findsOneWidget);
      await tester.tap(find.text('সেভ করুন'));
      await tester.pumpAndSettle();
      expect(results, <String?>['ok']);
    });
  });
}
