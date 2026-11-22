// W1-A (docs/council/16-windows-rebuild-plan.md): popover placement (G7),
// the container rule (G1), one menu component (G8), Esc closes only the
// top-most layer (G2) and the unsaved-changes guard (G3).

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_keys.dart';
import 'package:attendance_alamin/features/students/widgets/student_keys.dart';

import 'ds_harness.dart';

const Size _desktop = Size(1366, 860);
const Size _phone = Size(375, 812);

Widget _opener(String label, void Function(BuildContext context) onPressed) => Builder(
      builder: (BuildContext context) => BhorButton(label: label, onPressed: () => onPressed(context)),
    );

Widget _rows(BuildContext ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final String s in <String>['১৫ মিনিট', '৩০ মিনিট'])
          BhorButton(label: s, variant: BhorButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop(s)),
      ],
    );

Finder get _popover => find.byKey(const ValueKey<String>('bhor-popover'));

Finder get _closeButtons =>
    find.byWidgetPredicate((Widget w) => w is BhorIconButton && w.icon == BhorIcons.close);

void main() {
  setUp(BhorTapTracker.reset);

  group('BhorPopoverPlacement.of', () {
    const Size area = Size(1000, 700);
    const double gap = BhorPopoverPlacement.gap;
    const double margin = BhorPopoverPlacement.margin;

    test('below: drops from the anchor, start-aligned', () {
      final BhorPopoverPlacement p = BhorPopoverPlacement.of(
          anchor: const Rect.fromLTWH(100, 100, 120, 40), area: area, padding: EdgeInsets.zero, width: 300);
      expect(p.below, isTrue);
      expect(p.alignStart, isTrue);
      expect(p.rect.left, 100);
      expect(p.rect.top, 140 + gap);
      expect(p.rect.bottom, area.height - margin);
      expect(p.positionFor(120), const Offset(100, 140 + gap));
    });

    test('above: the card is bottom-aligned to the anchor, never pinned to the window top', () {
      const Rect anchor = Rect.fromLTWH(100, 600, 120, 40);
      final BhorPopoverPlacement p =
          BhorPopoverPlacement.of(anchor: anchor, area: area, padding: EdgeInsets.zero, width: 300);
      expect(p.below, isFalse);
      expect(p.origin, Alignment.bottomLeft);
      expect(p.rect.bottom, anchor.top - gap);
      // A short card (120) sits right above the anchor, not at y = margin.
      final Offset at = p.positionFor(120);
      expect(at.dy + 120, anchor.top - gap);
      expect(at.dy, greaterThan(400));
      // A card taller than the room is capped (it scrolls inside).
      expect(p.positionFor(5000).dy, p.rect.top);
      expect(p.rect.top, greaterThanOrEqualTo(margin));
    });

    test('a short window: never past the window, no full-height mode', () {
      const Size short = Size(1000, 300);
      for (final double y in <double>[10, 130, 250]) {
        final Rect anchor = Rect.fromLTWH(100, y, 120, 40);
        final BhorPopoverPlacement p =
            BhorPopoverPlacement.of(anchor: anchor, area: short, padding: EdgeInsets.zero, width: 300);
        expect(p.rect.top, greaterThanOrEqualTo(margin), reason: 'anchor at $y');
        expect(p.rect.bottom, lessThanOrEqualTo(short.height - margin), reason: 'anchor at $y');
        expect(p.rect.height, greaterThanOrEqualTo(BhorPopoverPlacement.minHeight - 0.01), reason: 'anchor at $y');
        // A short card still hugs the anchor side it opens on.
        final double top = p.positionFor(60).dy;
        if (p.below) {
          expect(top, greaterThanOrEqualTo(math.min(anchor.bottom + gap, short.height - margin - p.rect.height)));
        } else {
          expect(top + 60, closeTo(p.rect.bottom, 0.01));
        }
      }
    });

    test('right edge: end-aligned and clamped inside the window', () {
      final BhorPopoverPlacement p = BhorPopoverPlacement.of(
          anchor: const Rect.fromLTWH(950, 100, 40, 40), area: area, padding: EdgeInsets.zero, width: 300);
      expect(p.alignStart, isFalse);
      expect(p.rect.right, lessThanOrEqualTo(area.width - margin));
      expect(p.rect.right, closeTo(990, 0.01));
      final BhorPopoverPlacement wide = BhorPopoverPlacement.of(
          anchor: const Rect.fromLTWH(10, 100, 40, 40), area: const Size(250, 700), padding: EdgeInsets.zero, width: 300);
      expect(wide.rect.left, greaterThanOrEqualTo(margin));
      expect(wide.rect.right, lessThanOrEqualTo(250 - margin));
    });

    test('padding (status bar, keyboard) is respected', () {
      final BhorPopoverPlacement p = BhorPopoverPlacement.of(
          anchor: const Rect.fromLTWH(100, 300, 120, 40),
          area: area,
          padding: const EdgeInsets.only(top: 40, bottom: 300),
          width: 300);
      expect(p.rect.top, greaterThanOrEqualTo(40 + margin));
      expect(p.rect.bottom, lessThanOrEqualTo(area.height - 300 - margin));
    });
  });

  group('anchoring', () {
    testWidgets('a ⋮ inside a card: the menu hangs from the ⋮, not from the card', (WidgetTester tester) async {
      final GlobalKey card = GlobalKey();
      await pumpDs(
        tester,
        Stack(children: <Widget>[
          Positioned(
            left: 300,
            top: 400,
            width: 500,
            height: 300,
            child: SizedBox(
              key: card,
              child: Align(
                alignment: Alignment.topRight,
                child: BhorIconButton(
                  icon: BhorIcons.overflowVertical,
                  semanticLabel: 'আরও',
                  onPressed: () => showBhorMenu(card.currentContext!, items: <BhorMenuItem>[
                    BhorMenuItem(icon: BhorIcons.edit, label: 'সম্পাদনা', onTap: () {}),
                  ]),
                ),
              ),
            ),
          ),
        ]),
        size: _desktop,
        scroll: false,
      );
      final Rect button = tester.getRect(find.byType(BhorIconButton));
      await tester.tap(find.byType(BhorIconButton));
      await tester.pumpAndSettle();
      final Rect pop = tester.getRect(_popover);
      expect(pop.top, closeTo(button.bottom + BhorPopoverPlacement.gap, 1));
      expect(pop.left, closeTo(button.left, 1), reason: 'aligned to the ⋮, not to the card');
      expect(pop.bottom, lessThanOrEqualTo(_desktop.height));
      expectClean(tester);
    });

    testWidgets('a tall popover near the bottom is bottom-aligned above its anchor and fits', (WidgetTester tester) async {
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 120),
            child: _opener('সাহায্য', (BuildContext c) {
              showBhorPanel<void>(
                c,
                kind: BhorPanelKind.list,
                title: 'সাহায্য',
                width: 560,
                builder: (BuildContext _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[for (int i = 0; i < 40; i++) SizedBox(height: 40, child: Text('প্রশ্ন $i'))],
                ),
              );
            }),
          ),
        ),
        size: _desktop,
        scroll: false,
      );
      final Rect button = tester.getRect(find.byType(BhorButton));
      await tester.tap(find.text('সাহায্য'));
      await tester.pumpAndSettle();
      final Rect pop = tester.getRect(_popover);
      expect(pop.top, greaterThanOrEqualTo(BhorPopoverPlacement.margin));
      expect(pop.bottom, closeTo(button.top - BhorPopoverPlacement.gap, 1));
      expect(pop.bottom, lessThanOrEqualTo(_desktop.height));
      expectClean(tester);
    });
  });

  group('container rule', () {
    testWidgets('showBhorSheet on desktop: a popover for a choice, a side panel with a footer', (WidgetTester tester) async {
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            _opener('বেছে নিন', (BuildContext c) {
              showBhorSheet<String>(c, title: 'কত মিনিট আগে', builder: _rows);
            }),
            _opener('ফর্ম', (BuildContext c) {
              showBhorSheet<void>(c,
                  title: 'ফর্ম', builder: (_) => const Text('ঘর'), footer: (_) => const Text('সেভ'));
            }),
          ]),
        ),
        size: _desktop,
        scroll: false,
      );
      await tester.tap(find.text('বেছে নিন'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSheetFrame), findsNothing);
      expect(find.byType(BhorPopoverFrame), findsOneWidget);
      await tester.tap(find.text('৩০ মিনিট'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ফর্ম'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSheetFrame), findsNothing);
      expect(find.byType(BhorSidePanelFrame), findsOneWidget);
      expectClean(tester);
    });

    testWidgets('showBhorSheet on a phone is still a sheet', (WidgetTester tester) async {
      await pumpDs(
        tester,
        _opener('বেছে নিন', (BuildContext c) {
          showBhorSheet<String>(c, title: 'কত মিনিট আগে', builder: _rows);
        }),
        size: _phone,
      );
      await tester.tap(find.text('বেছে নিন'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSheetFrame), findsOneWidget);
    });

    testWidgets('choice: an anchored popover, or a small dialog without an anchor', (WidgetTester tester) async {
      final GlobalKey screen = GlobalKey();
      await pumpDs(
        tester,
        SizedBox.expand(
          key: screen,
          child: Align(
            alignment: Alignment.topLeft,
            child: _opener('মিনিট', (BuildContext c) {
              showBhorPanel<String>(c, kind: BhorPanelKind.choice, title: 'মিনিট', builder: _rows);
            }),
          ),
        ),
        size: _desktop,
        scroll: false,
      );
      final Rect button = tester.getRect(find.byType(BhorButton));
      await tester.tap(find.text('মিনিট'));
      await tester.pumpAndSettle();
      final Rect pop = tester.getRect(_popover);
      expect(pop.top, closeTo(button.bottom + BhorPopoverPlacement.gap, 1));
      expect(pop.width, 320);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(BhorPopoverFrame), findsNothing);

      BhorTapTracker.reset();
      showBhorPanel<String>(screen.currentContext!, kind: BhorPanelKind.choice, title: 'মিনিট', builder: _rows);
      await tester.pumpAndSettle();
      expect(find.byType(BhorDialog), findsOneWidget);
      expect(find.byType(BhorSheetFrame), findsNothing);
    });
  });

  group('showBhorMenu', () {
    testWidgets('icons, no header, destructive last after a divider, onTap after close', (WidgetTester tester) async {
      final List<String> ran = <String>[];
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: _opener('মেনু', (BuildContext c) {
            showBhorMenu(c, items: <BhorMenuItem>[
              BhorMenuItem(icon: BhorIcons.delete, label: 'মুছুন', destructive: true, onTap: () => ran.add('delete')),
              BhorMenuItem(icon: BhorIcons.edit, label: 'সম্পাদনা', onTap: () => ran.add('edit')),
              BhorMenuItem(icon: BhorIcons.archive, label: 'আর্কাইভ', onTap: () => ran.add('archive')),
            ]);
          }),
        ),
        size: _desktop,
        scroll: false,
      );
      await tester.tap(find.text('মেনু'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorPopoverFrame), findsOneWidget);
      expect(_closeButtons, findsNothing, reason: 'no ✕');
      expect(find.descendant(of: find.byType(BhorMenu), matching: find.byType(Icon)), findsNWidgets(3));
      final double edit = tester.getCenter(find.text('সম্পাদনা')).dy;
      final double archive = tester.getCenter(find.text('আর্কাইভ')).dy;
      final double delete = tester.getCenter(find.text('মুছুন')).dy;
      final double divider = tester.getCenter(find.byKey(const ValueKey<String>('bhor-menu-divider'))).dy;
      expect(edit, lessThan(archive));
      expect(archive, lessThan(divider));
      expect(divider, lessThan(delete));
      final BhorThemeData theme = BhorThemeData.of(Brightness.light);
      expect(tester.widget<Text>(find.text('মুছুন')).style?.color, theme.colors.danger);
      await tester.tap(find.text('আর্কাইভ'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorPopoverFrame), findsNothing);
      expect(ran, <String>['archive']);
      expectClean(tester);
    });

    testWidgets('keyboard: ↓ ↓ Enter picks the second row; Esc closes without picking', (WidgetTester tester) async {
      final List<String> ran = <String>[];
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: _opener('মেনু', (BuildContext c) {
            showBhorMenu(c, items: <BhorMenuItem>[
              BhorMenuItem(icon: BhorIcons.edit, label: 'সম্পাদনা', onTap: () => ran.add('edit')),
              BhorMenuItem(icon: BhorIcons.copy, label: 'কপি', onTap: () => ran.add('copy')),
            ]);
          }),
        ),
        size: _desktop,
        scroll: false,
      );
      await tester.tap(find.text('মেনু'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(BhorPopoverFrame), findsNothing);
      expect(ran, isEmpty);

      await tester.tap(find.text('মেনু'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(BhorPopoverFrame), findsNothing);
      expect(ran, <String>['copy']);
    });

    testWidgets('no anchor: a small card without a title or ✕', (WidgetTester tester) async {
      final GlobalKey screen = GlobalKey();
      await pumpDs(tester, SizedBox.expand(key: screen), size: _desktop, scroll: false);
      BhorTapTracker.reset();
      showBhorMenu(screen.currentContext!, items: <BhorMenuItem>[
        BhorMenuItem(icon: BhorIcons.edit, label: 'সম্পাদনা', onTap: () {}),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(BhorMenu), findsOneWidget);
      expect(find.byType(BhorPopoverFrame), findsNothing);
      expect(_closeButtons, findsNothing);
    });
  });

  group('Esc closes only the top-most layer', () {
    for (final String which in <String>['students', 'dues']) {
      testWidgets('$which: Esc on a menu over a nested page closes the menu, not the selection', (WidgetTester tester) async {
        int cleared = 0;
        Widget page(BuildContext _) {
          final Widget body = Align(
            alignment: Alignment.topLeft,
            child: _opener('মেনু', (BuildContext c) {
              showBhorMenu(c, items: <BhorMenuItem>[BhorMenuItem(icon: BhorIcons.edit, label: 'সম্পাদনা', onTap: () {})]);
            }),
          );
          return which == 'students'
              ? StudentKeys(onEscape: () => cleared++, child: body)
              : DuesKeys(onEscape: () => cleared++, child: body);
        }

        await pumpDs(
          tester,
          // A shell-like nested navigator: its page stays "current" while a
          // popup sits on the root navigator.
          Navigator(
            onGenerateRoute: (RouteSettings s) => PageRouteBuilder<void>(
              settings: s,
              pageBuilder: (BuildContext c, Animation<double> a, Animation<double> b) => page(c),
            ),
          ),
          size: _desktop,
          scroll: false,
        );
        await tester.tap(find.text('মেনু'));
        await tester.pumpAndSettle();
        expect(find.byType(BhorPopoverFrame), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(BhorPopoverFrame), findsNothing);
        expect(cleared, 0, reason: 'Esc belonged to the menu');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(cleared, 1, reason: 'with nothing on top, Esc reaches the page');
      });
    }
  });

  group('unsaved-changes guard', () {
    testWidgets('dirty panel: Esc asks; Keep editing stays; Discard closes; Save is never blocked', (WidgetTester tester) async {
      final ValueNotifier<bool> dirty = ValueNotifier<bool>(true);
      addTearDown(dirty.dispose);
      final List<String?> results = <String?>[];
      final l10n = dsL10n(Lang.bn);
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: _opener('খুলুন', (BuildContext c) async {
            results.add(await showBhorPanel<String>(
              c,
              title: 'ফর্ম',
              dirty: dirty,
              builder: (BuildContext ctx) =>
                  BhorButton(label: 'সেভ', onPressed: () => Navigator.of(ctx).pop('saved')),
            ));
          }),
        ),
        size: _desktop,
        scroll: false,
      );
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSidePanelFrame), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonDiscardTitle), findsOneWidget);
      await tester.tap(find.text(l10n.commonDiscardKeep));
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonDiscardTitle), findsNothing);
      expect(find.byType(BhorSidePanelFrame), findsOneWidget);
      expect(results, isEmpty);

      // A click on the dim asks too.
      await tester.tapAt(const Offset(200, 600));
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonDiscardTitle), findsOneWidget);
      await tester.tap(find.text(l10n.commonDiscardConfirm));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSidePanelFrame), findsNothing);
      expect(results, <String?>[null]);

      // Saving pops straight through.
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('সেভ'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonDiscardTitle), findsNothing);
      expect(results, <String?>[null, 'saved']);

      // Clean: Esc closes at once.
      dirty.value = false;
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonDiscardTitle), findsNothing);
      expect(find.byType(BhorSidePanelFrame), findsNothing);
      expect(results, <String?>[null, 'saved', null]);
      expectClean(tester);
    });

    testWidgets('phone sheet: a dismiss drag asks and springs back on Keep editing', (WidgetTester tester) async {
      final ValueNotifier<bool> dirty = ValueNotifier<bool>(true);
      addTearDown(dirty.dispose);
      final l10n = dsL10n(Lang.bn);
      await pumpDs(
        tester,
        _opener('খুলুন', (BuildContext c) {
          showBhorPanel<void>(c, title: 'ফর্ম', dirty: dirty, builder: (_) => const SizedBox(height: 120));
        }),
        size: _phone,
      );
      await tester.tap(find.text('খুলুন'));
      await tester.pumpAndSettle();
      final double top0 = tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-handle'))).top;
      await tester.drag(find.byKey(const ValueKey<String>('bhor-sheet-handle')), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonDiscardTitle), findsOneWidget);
      await tester.tap(find.text(l10n.commonDiscardKeep));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSheetFrame), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey<String>('bhor-sheet-handle'))).top, closeTo(top0, 1));
    });

    testWidgets('BhorDirtyScope: Esc leaves a full page through the guard', (WidgetTester tester) async {
      final ValueNotifier<bool> dirty = ValueNotifier<bool>(true);
      addTearDown(dirty.dispose);
      final l10n = dsL10n(Lang.bn);
      await pumpDs(
        tester,
        _opener('পাতা খুলুন', (BuildContext c) {
          Navigator.of(c).push(PageRouteBuilder<void>(
            pageBuilder: (BuildContext c, Animation<double> a, Animation<double> b) => BhorDirtyScope(
              dirty: dirty,
              closeOnEscape: true,
              child: const ColoredBox(color: Color(0xFFFFFFFF), child: Center(child: Text('পাতা'))),
            ),
          ));
        }),
        size: _desktop,
      );
      await tester.tap(find.text('পাতা খুলুন'));
      await tester.pumpAndSettle();
      expect(find.text('পাতা'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonDiscardTitle), findsOneWidget);
      // Esc on the dialog belongs to the dialog (Keep editing).
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(l10n.commonDiscardTitle), findsNothing);
      expect(find.text('পাতা'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDiscardConfirm));
      await tester.pumpAndSettle();
      expect(find.text('পাতা'), findsNothing);
    });
  });
}
