// Visual QA fixes owned by the design system (docs/council/14-visual-qa.md):
// anchored popovers on desktop (sheets on phones), pickers never a sheet on
// desktop, fade-through transitions that never show two contents at once
// (golden-free frame checks), content-height sheets with a pinned footer,
// button states, the one tinted severity tag, toasts above pinned chrome.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/lang.dart';

import 'ds_harness.dart';

const Size _desktop = Size(1366, 860);
const Size _phone = Size(375, 812);

/// A small button whose own context opens [onPressed].
Widget _opener(String label, void Function(BuildContext context) onPressed) => Builder(
      builder: (BuildContext context) => BhorButton(label: label, onPressed: () => onPressed(context)),
    );

Widget _menuRows(BuildContext ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final String s in <String>['সম্পাদনা', 'আর্কাইভ', 'মুছুন'])
          BhorButton(label: s, variant: BhorButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop(s)),
      ],
    );

void main() {
  group('anchored popover', () {
    for (final BhorPanelKind kind in <BhorPanelKind>[BhorPanelKind.list, BhorPanelKind.menu, BhorPanelKind.picker]) {
      testWidgets('desktop ${kind.name}: a popover under the invoking button; phone: a sheet', (WidgetTester tester) async {
        final List<String?> results = <String?>[];
        Widget opener() => Align(
              alignment: Alignment.topLeft,
              child: _opener('মেনু', (BuildContext context) async {
                results.add(await showBhorPanel<String>(context, kind: kind, title: 'কাজ', builder: _menuRows));
              }),
            );

        await pumpDs(tester, opener(), size: _desktop);
        final Rect button = tester.getRect(find.byType(BhorButton));
        await tester.tap(find.text('মেনু'));
        await tester.pumpAndSettle();
        expect(find.byType(BhorPopoverFrame), findsOneWidget);
        expect(find.byType(BhorSheetFrame), findsNothing);
        expect(find.byType(BhorDialog), findsNothing);
        final Rect pop = tester.getRect(find.byKey(const ValueKey<String>('bhor-popover')));
        expect(pop.top, closeTo(button.bottom + BhorPopoverPlacement.gap, 1), reason: 'drops from the anchor');
        expect(pop.left, closeTo(button.left, 1), reason: 'aligned to the anchor start');
        expect(pop.bottom, lessThanOrEqualTo(_desktop.height), reason: 'nothing clipped');
        await tester.tap(find.text('আর্কাইভ'));
        await tester.pumpAndSettle();
        expect(results, <String?>['আর্কাইভ']);
        expect(find.byType(BhorPopoverFrame), findsNothing);

        await pumpDs(tester, opener(), size: _phone);
        await tester.tap(find.text('মেনু'));
        await tester.pumpAndSettle();
        expect(find.byType(BhorSheetFrame), findsOneWidget);
        expect(find.byType(BhorPopoverFrame), findsNothing);
        expect(materialWidgetsIn(tester), isEmpty);
        expectClean(tester);
      });
    }

    testWidgets('Esc and an outside click close it', (WidgetTester tester) async {
      final List<String?> results = <String?>[];
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: _opener('মেনু', (BuildContext context) async {
            results.add(await showBhorPanel<String>(context, kind: BhorPanelKind.menu, builder: _menuRows));
          }),
        ),
        size: _desktop,
      );
      await tester.tap(find.text('মেনু'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(BhorPopoverFrame), findsNothing);
      await tester.tap(find.text('মেনু'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorPopoverFrame), findsOneWidget);
      await tester.tapAt(const Offset(1300, 800));
      await tester.pumpAndSettle();
      expect(find.byType(BhorPopoverFrame), findsNothing);
      expect(results, <String?>[null, null]);
    });

    testWidgets('a whole-screen context anchors to the control just tapped', (WidgetTester tester) async {
      final GlobalKey screen = GlobalKey();
      await pumpDs(
        tester,
        SizedBox.expand(
          key: screen,
          child: Align(
            alignment: Alignment.topRight,
            child: BhorIconButton(
              icon: BhorIcons.overflowVertical,
              semanticLabel: 'আরও',
              onPressed: () => showBhorPanel<void>(screen.currentContext!, kind: BhorPanelKind.menu, builder: _menuRows),
            ),
          ),
        ),
        size: _desktop,
        scroll: false,
      );
      final Rect button = tester.getRect(find.byType(BhorIconButton));
      await tester.tap(find.byType(BhorIconButton));
      await tester.pumpAndSettle();
      expect(find.byType(BhorPopoverFrame), findsOneWidget);
      final Rect pop = tester.getRect(find.byKey(const ValueKey<String>('bhor-popover')));
      // Near the right edge it aligns its right edge to the anchor's instead.
      expect(pop.right, lessThanOrEqualTo(_desktop.width));
      expect(pop.top, greaterThanOrEqualTo(button.top));
      expect(pop.top, lessThan(button.bottom + 40));
    });

    testWidgets('it flips above an anchor near the bottom edge', (WidgetTester tester) async {
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.bottomLeft,
          child: _opener('মেনু', (BuildContext context) {
            showBhorPanel<void>(context, kind: BhorPanelKind.menu, builder: _menuRows);
          }),
        ),
        size: _desktop,
        scroll: false,
      );
      final Rect button = tester.getRect(find.byType(BhorButton));
      await tester.tap(find.text('মেনু'));
      await tester.pumpAndSettle();
      final Rect pop = tester.getRect(find.byKey(const ValueKey<String>('bhor-popover')));
      expect(pop.bottom, closeTo(button.top - BhorPopoverPlacement.gap, 1));
      expect(pop.top, greaterThanOrEqualTo(0));
    });

    testWidgets('no anchor: a centred dialog', (WidgetTester tester) async {
      final GlobalKey screen = GlobalKey();
      await pumpDs(tester, SizedBox.expand(key: screen), size: _desktop, scroll: false);
      BhorTapTracker.position = null;
      showBhorPanel<void>(screen.currentContext!, kind: BhorPanelKind.list, title: 'বেছে নিন', builder: _menuRows);
      await tester.pumpAndSettle();
      expect(find.byType(BhorDialog), findsOneWidget);
      expect(find.byType(BhorPopoverFrame), findsNothing);
    });

    test('placement flips and clamps inside the window', () {
      const Size area = Size(1000, 700);
      final BhorPopoverPlacement below = BhorPopoverPlacement.of(
          anchor: const Rect.fromLTWH(100, 100, 120, 40), area: area, padding: EdgeInsets.zero, width: 300);
      expect(below.below, isTrue);
      expect(below.alignStart, isTrue);
      expect(below.origin, Alignment.topLeft);
      final BhorPopoverPlacement corner = BhorPopoverPlacement.of(
          anchor: const Rect.fromLTWH(940, 640, 40, 40), area: area, padding: EdgeInsets.zero, width: 300);
      expect(corner.below, isFalse);
      expect(corner.alignStart, isFalse);
      expect(corner.origin, Alignment.bottomRight);
      expect(corner.rect.right, lessThanOrEqualTo(area.width - BhorPopoverPlacement.margin));
    });
  });

  group('pickers on desktop are popovers, never sheets', () {
    testWidgets('date picker: an anchored calendar with 40 px cells, fully visible', (WidgetTester tester) async {
      DateTime? result;
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.bottomRight,
          child: _opener('তারিখ', (BuildContext context) async {
            result = await showBhorDatePicker(
              context,
              initialDate: DateTime(2026, 11, 21),
              firstDate: DateTime(2026),
              lastDate: DateTime(2026, 12, 31),
            );
          }),
        ),
        size: _desktop,
        scroll: false,
      );
      await tester.tap(find.text('তারিখ'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSheetFrame), findsNothing);
      expect(find.byType(BhorPopoverFrame), findsOneWidget);
      final Rect pop = tester.getRect(find.byKey(const ValueKey<String>('bhor-popover')));
      expect(pop.top, greaterThanOrEqualTo(0));
      expect(pop.bottom, lessThanOrEqualTo(_desktop.height));
      expect(pop.right, lessThanOrEqualTo(_desktop.width));
      // Every week row is on screen (the last one was clipped in the sheet).
      final Rect day30 = tester.getRect(find.text('৩০'));
      expect(day30.bottom, lessThanOrEqualTo(pop.bottom));
      expect(tester.getSize(find.ancestor(of: find.text('১৮'), matching: find.byType(AnimatedContainer)).first).height, 40);
      await tester.tap(find.text('১৮'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 11, 18));
      expectClean(tester);
    });

    testWidgets('time picker: a 3-column popover with Done', (WidgetTester tester) async {
      int? result;
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: _opener('সময়', (BuildContext context) async {
            result = await showBhorTimePicker(context, initial: 10 * 60);
          }),
        ),
        size: _desktop,
      );
      await tester.tap(find.text('সময়'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSheetFrame), findsNothing);
      expect(find.byType(BhorPopoverFrame), findsOneWidget);
      // Period, hour and minute side by side.
      final double periodX = tester.getCenter(find.byKey(const ValueKey<String>('bhor-period-1'))).dx;
      final double hourX = tester.getCenter(find.byKey(const ValueKey<String>('bhor-hour-10'))).dx;
      final double minuteX = tester.getCenter(find.byKey(const ValueKey<String>('bhor-minute-15'))).dx;
      expect(periodX, lessThan(hourX));
      expect(hourX, lessThan(minuteX));
      await tester.tap(find.byKey(const ValueKey<String>('bhor-minute-15')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(dsL10n(Lang.bn).commonDone));
      await tester.pumpAndSettle();
      expect(result, 10 * 60 + 15);
      expectClean(tester);
    });
  });

  group('transitions never show two contents at once', () {
    testWidgets('page push and pop (phone and desktop): fade-through on an opaque cover', (WidgetTester tester) async {
      for (final Size size in <Size>[_phone, _desktop]) {
        await pumpDs(
          tester,
          Column(children: <Widget>[
            const Text('পাতা ক'),
            _opener('খুলুন', (BuildContext context) {
              Navigator.of(context).push(BhorPageRoute<void>(builder: (_) => const BhorScaffold(body: Text('পাতা খ'))));
            }),
          ]),
          size: size,
        );
        await tester.tap(find.text('খুলুন'));
        await tester.pump();
        Future<void> checkFrames(String phase) async {
          for (int f = 0; f < 24; f++) {
            if (find.text('পাতা খ', skipOffstage: false).evaluate().isEmpty) break;
            final double cover = tester
                .widget<FadeTransition>(find.byKey(const ValueKey<String>('bhor-page-cover'), skipOffstage: false))
                .opacity
                .value;
            final double oldText = visibleOpacity(tester, find.text('পাতা ক', skipOffstage: false)) * (1 - cover);
            final double newText = visibleOpacity(tester, find.text('পাতা খ', skipOffstage: false));
            expect(oldText > 0.02 && newText > 0.02, isFalse,
                reason: '$phase ${size.width} frame $f: old $oldText new $newText (cover $cover)');
            await tester.pump(const Duration(milliseconds: 16));
          }
        }

        await checkFrames('push');
        await tester.pumpAndSettle();
        expect(find.text('পাতা খ'), findsOneWidget);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump();
        await checkFrames('pop');
        await tester.pumpAndSettle();
        expect(find.text('পাতা খ'), findsNothing);
        expectClean(tester);
      }
    });

    testWidgets('full-screen close drops and fades before uncovering', (WidgetTester tester) async {
      await pumpDs(
        tester,
        Column(children: <Widget>[
          const Text('আজ'),
          _opener('হাজিরা', (BuildContext context) {
            Navigator.of(context).push(PageRouteBuilder<void>(
              transitionDuration: const Duration(milliseconds: 320),
              reverseTransitionDuration: BhorMotion.exit,
              pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) =>
                  const BhorScaffold(body: Text('রোল কল')),
              transitionsBuilder: bhorFullscreenTransition,
            ));
          }),
        ]),
      );
      await tester.tap(find.text('হাজিরা'));
      await tester.pumpAndSettle();
      final double top0 = tester.getTopLeft(find.text('রোল কল')).dy;
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Mid-close: the roll call has dropped and faded, its cover still hides Today.
      expect(tester.getTopLeft(find.text('রোল কল')).dy, greaterThan(top0));
      final double cover = tester.widget<FadeTransition>(find.byKey(const ValueKey<String>('bhor-page-cover'))).opacity.value;
      expect(cover, 1);
      await tester.pumpAndSettle();
      expect(find.text('রোল কল'), findsNothing);
    });

    testWidgets('step transition: out first, then in; footer in step', (WidgetTester tester) async {
      int step = 0;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => Column(children: <Widget>[
            BhorStepTransition(step: step, child: Text('ধাপ $step')),
            BhorStepTransition(step: step, child: Text('নিচে $step')),
            BhorButton(label: 'পরের', onPressed: () => set(() => step++)),
          ]),
        ),
      );
      await tester.tap(find.text('পরের'));
      await tester.pump();
      double oldX = double.infinity;
      for (int f = 0; f < 22; f++) {
        if (find.text('ধাপ 0').evaluate().isEmpty) break;
        final double a = visibleOpacity(tester, find.text('ধাপ 0'));
        final double b = visibleOpacity(tester, find.text('ধাপ 1'));
        expect(a > 0.02 && b > 0.02, isFalse, reason: 'frame $f: old $a new $b');
        // Body and footer move together.
        expect(visibleOpacity(tester, find.text('নিচে 1')), closeTo(b, 0.001));
        final double x = tester.getTopLeft(find.text('ধাপ 0')).dx;
        expect(x, lessThanOrEqualTo(oldX + 0.01), reason: 'the old step leaves towards the start');
        oldX = x;
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(find.text('ধাপ 0'), findsNothing);
      expect(find.text('ধাপ 1'), findsOneWidget);
    });

    testWidgets('branch stack: old tab fades out completely before the new one shows', (WidgetTester tester) async {
      int index = 0;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => Column(children: <Widget>[
            SizedBox(
              height: 100,
              child: BhorBranchFadeThrough(index: index, children: const <Widget>[Text('আজ ট্যাব'), Text('ব্যাচ ট্যাব')]),
            ),
            BhorButton(label: 'বদলান', onPressed: () => set(() => index = 1)),
          ]),
        ),
      );
      expect(visibleOpacity(tester, find.text('ব্যাচ ট্যাব', skipOffstage: false)), 0);
      await tester.tap(find.text('বদলান'));
      await tester.pump();
      for (int f = 0; f < 22; f++) {
        final double a = visibleOpacity(tester, find.text('আজ ট্যাব', skipOffstage: false));
        final double b = visibleOpacity(tester, find.text('ব্যাচ ট্যাব', skipOffstage: false));
        expect(a > 0.02 && b > 0.02, isFalse, reason: 'frame $f: old $a new $b');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(visibleOpacity(tester, find.text('আজ ট্যাব', skipOffstage: false)), 0);
      expect(visibleOpacity(tester, find.text('ব্যাচ ট্যাব', skipOffstage: false)), 1);
    });

    testWidgets('sheet success: the form is gone before the check shows', (WidgetTester tester) async {
      await pumpDs(
        tester,
        _opener('খুলুন', (BuildContext context) {
          showBhorSheet<bool>(
            context,
            title: 'টাকা নিন',
            builder: (BuildContext ctx) => Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              const Text('ফর্মের ঘর'),
              BhorButton(label: 'সেভ', onPressed: () => showBhorSuccess<bool>(ctx, result: true, label: 'জমা হয়েছে')),
            ]),
          );
        }),
      );
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('সেভ'));
      await tester.pump();
      for (int f = 0; f < 18; f++) {
        if (find.byType(BhorSuccess).evaluate().isEmpty || find.text('ফর্মের ঘর').evaluate().isEmpty) break;
        final double form = visibleOpacity(tester, find.text('ফর্মের ঘর'));
        final double check = visibleOpacity(tester, find.byType(BhorSuccess));
        expect(form > 0.02 && check > 0.02, isFalse, reason: 'frame $f: form $form check $check');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
    });
  });

  group('sheets', () {
    Widget formOpener(double contentHeight) => _opener('খুলুন', (BuildContext context) {
          showBhorPanel<void>(
            context,
            title: 'নতুন ব্যাচ',
            builder: (BuildContext ctx) => SizedBox(height: contentHeight, child: const Text('ঘর')),
            footer: (BuildContext ctx) => BhorButton(label: 'সেভ করুন', expand: true, onPressed: () {}),
          );
        });

    testWidgets('a short form opens at its content height with the footer pinned', (WidgetTester tester) async {
      await pumpDs(tester, formOpener(120), size: _phone);
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      final Rect sheet = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-handle')));
      final Rect footer = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-footer')));
      expect(_phone.height - sheet.top, lessThan(_phone.height * 0.6), reason: 'hugs a short form');
      expect(footer.bottom, closeTo(_phone.height, 1));
      expect(tester.getRect(find.text('ঘর')).top, lessThan(footer.top));
      expectClean(tester);
    });

    testWidgets('a long form opens at up to 92%, scrolls, and keeps the footer visible', (WidgetTester tester) async {
      await pumpDs(tester, formOpener(2000), size: _phone);
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      final Rect sheet = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-handle')));
      expect(_phone.height - sheet.top, closeTo(_phone.height * BhorSheetFrame.maxFraction, 2));
      final Rect footer = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-footer')));
      expect(footer.bottom, lessThanOrEqualTo(_phone.height));
      expect(find.text('সেভ করুন').hitTestable(), findsOneWidget);
      expectClean(tester);
    });

    testWidgets('the footer stays above the keyboard', (WidgetTester tester) async {
      await pumpDs(tester, formOpener(600), size: _phone);
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final Rect footer = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-footer')));
      expect(footer.bottom, lessThanOrEqualTo(_phone.height - 320 + 1));
      final Rect sheet = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-handle')));
      expect(sheet.top, greaterThanOrEqualTo(0));
      expectClean(tester);
    });

    testWidgets('a form sheet drags up to full height', (WidgetTester tester) async {
      await pumpDs(tester, formOpener(120), size: _phone);
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      final double top0 = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-handle'))).top;
      await tester.drag(find.byKey(const ValueKey<String>('bhor-sheet-handle')), const Offset(0, -500));
      await tester.pumpAndSettle();
      final double top1 = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-handle'))).top;
      expect(top1, lessThan(top0));
      expect(_phone.height - top1, closeTo(_phone.height * BhorSheetFrame.maxFraction, 4));
      // Dragging back down returns to the content height (it does not close).
      await tester.drag(find.byKey(const ValueKey<String>('bhor-sheet-handle')), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSheetFrame), findsOneWidget);
      expectClean(tester);
    });
  });

  group('button states', () {
    testWidgets('label fades out before the spinner, then a check', (WidgetTester tester) async {
      BhorButtonState state = BhorButtonState.idle;
      await pumpDs(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => Column(children: <Widget>[
            BhorButton(label: 'হাজিরা সেভ করুন', state: state, expand: true, onPressed: () {}),
            BhorButton(label: 'লোড', variant: BhorButtonVariant.secondary, onPressed: () => set(() => state = BhorButtonState.loading)),
            BhorButton(label: 'সফল', variant: BhorButtonVariant.secondary, onPressed: () => set(() => state = BhorButtonState.success)),
          ]),
        ),
      );
      await tester.tap(find.text('লোড'));
      await tester.pump();
      for (int f = 0; f < 18; f++) {
        if (find.text('হাজিরা সেভ করুন').evaluate().isEmpty) break;
        final double label = visibleOpacity(tester, find.text('হাজিরা সেভ করুন'));
        final double spin = visibleOpacity(tester, find.byType(BhorSpinner));
        expect(label > 0.02 && spin > 0.02, isFalse, reason: 'frame $f: label $label spinner $spin');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(visibleOpacity(tester, find.text('হাজিরা সেভ করুন')), 0, reason: 'the spinner stands alone');
      expect(find.byType(BhorSpinner), findsOneWidget);
      await tester.tap(find.text('সফল'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(BhorSpinner), findsNothing);
      expect(find.byIcon(BhorIcons.check), findsOneWidget);
      expect(find.text(dsL10n(Lang.bn).dsDone), findsOneWidget);
      expectClean(tester);
    });

    testWidgets('BhorAsyncButton: idle -> loading -> success -> done', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpDs(
        tester,
        BhorAsyncButton(
          label: 'সেভ করুন',
          onPressed: () {
            log.add('start');
            return Future<bool?>(() async {
              await Future<void>.delayed(const Duration(milliseconds: 200));
              return true;
            });
          },
          onDone: () => log.add('done'),
        ),
      );
      await tester.tap(find.text('সেভ করুন'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(log, <String>['start']);
      expect(find.byType(BhorSpinner), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(BhorIcons.check), findsOneWidget);
      await tester.pumpAndSettle();
      expect(log, <String>['start', 'done']);
      expect(find.text('সেভ করুন'), findsOneWidget);
    });
  });

  group('one severity tag style', () {
    testWidgets('overdue is the tinted pill; solid only for a count badge', (WidgetTester tester) async {
      await pumpDs(
        tester,
        const Column(children: <Widget>[
          BhorTag.severity(level: SeverityLevel.overdue, label: 'মেয়াদোত্তীর্ণ'),
          BhorTag(label: 'বকেয়া', tone: BhorTone.overdue),
          BhorTag.severity(level: SeverityLevel.overdue, label: '৩', solid: true),
        ]),
      );
      final BhorColors c = BhorThemeData.light().colors;
      Color fill(String label) =>
          (tester.widget<AnimatedContainer>(find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)).first).decoration!
                  as BoxDecoration)
              .color!;
      expect(fill('মেয়াদোত্তীর্ণ'), c.overdueBg);
      expect(fill('বকেয়া'), c.overdueBg);
      expect(fill('৩'), c.sevFill[SeverityLevel.overdue.index]);
    });
  });

  group('toasts clear pinned chrome', () {
    testWidgets('above a pinned action bar and the nav pill, whatever context shows them', (WidgetTester tester) async {
      await pumpDs(
        tester,
        Column(children: <Widget>[
          Expanded(child: _opener('দেখান', (BuildContext context) => BhorToast.show(context, message: 'সেভ হয়েছে'))),
          BhorActionBar(label: 'হাজিরা সেভ করুন', onPressed: () {}),
        ]),
        size: _phone,
        scroll: false,
      );
      await tester.tap(find.text('দেখান'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final Rect bar = tester.getRect(find.byType(BhorActionBar));
      final Rect toast = tester.getRect(find.text('সেভ হয়েছে'));
      expect(toast.bottom, lessThan(bar.top), reason: 'never on the save button');
      // Every toast has a leading status icon.
      expect(find.byIcon(BhorIcons.infoFill), findsOneWidget);
      expect(BhorToast.occupied.value, greaterThan(0));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(BhorToast.occupied.value, 0);
    });

    testWidgets('a replacing toast waits for the old one to leave', (WidgetTester tester) async {
      await pumpDs(
        tester,
        Column(children: <Widget>[
          _opener('এক', (BuildContext context) => BhorToast.show(context, message: 'প্রথম')),
          _opener('দুই', (BuildContext context) => BhorToast.show(context, message: 'দ্বিতীয়')),
        ]),
      );
      await tester.tap(find.text('এক'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('দুই'));
      await tester.pump();
      for (int f = 0; f < 16; f++) {
        if (find.text('প্রথম').evaluate().isEmpty) break;
        final double a = visibleOpacity(tester, find.text('প্রথম'));
        final double b = visibleOpacity(tester, find.text('দ্বিতীয়'));
        expect(a > 0.05 && b > 0.05, isFalse, reason: 'frame $f: old $a new $b');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
