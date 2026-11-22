// b277 re-walk, Fix-A (docs/council/18-b277-rewalk-fixes.md): menus size to
// their longest label and never cut one (X1), a confirmation without a body
// has no empty band (X6), the absent thumb is a calm danger fill (X4).

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/theme/tokens.dart' show AttendanceKind;
import 'package:attendance_alamin/core/format/lang.dart';

import 'ds_harness.dart';

const Size _desktop = Size(1366, 860);

Widget _opener(String label, void Function(BuildContext context) onPressed) => Builder(
      builder: (BuildContext context) => BhorButton(label: label, onPressed: () => onPressed(context)),
    );

Finder get _popover => find.byKey(const ValueKey<String>('bhor-popover'));

void main() {
  setUp(BhorTapTracker.reset);

  group('X1 showBhorMenu sizes to its labels', () {
    const String long = 'Class did not happen (delete attendance)';
    const String short = 'Class note';

    testWidgets('a long label is shown whole on one line; the menu grows for it', (WidgetTester tester) async {
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: _opener('menu', (BuildContext c) {
            showBhorMenu(c, items: <BhorMenuItem>[
              BhorMenuItem(icon: BhorIcons.notes, label: short, onTap: () {}),
              BhorMenuItem(icon: BhorIcons.delete, label: long, destructive: true, onTap: () {}),
            ]);
          }),
        ),
        lang: Lang.en,
        size: _desktop,
        scroll: false,
      );
      await tester.tap(find.text('menu'));
      await tester.pumpAndSettle();
      final RenderParagraph longP = tester.renderObject<RenderParagraph>(find.text(long));
      final RenderParagraph shortP = tester.renderObject<RenderParagraph>(find.text(short));
      // Whole label: as wide as its natural one-line width, same height as a
      // one-line label, and never an ellipsis.
      expect(longP.size.width, greaterThanOrEqualTo(longP.getMaxIntrinsicWidth(double.infinity) - 0.5));
      expect(longP.size.height, closeTo(shortP.size.height, 0.5));
      expect(tester.widget<Text>(find.text(long)).overflow, isNot(TextOverflow.ellipsis));
      final double w = tester.getSize(_popover).width;
      expect(w, greaterThanOrEqualTo(bhorMenuMinWidth));
      expect(w, lessThanOrEqualTo(bhorMenuMaxWidth));
      expectClean(tester);
    });

    testWidgets('Bangla: the long delete label is not cut either', (WidgetTester tester) async {
      const String bnLong = 'ক্লাস হয়নি (হাজিরা মুছুন)';
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: _opener('মেনু', (BuildContext c) {
            showBhorMenu(c, items: <BhorMenuItem>[
              BhorMenuItem(icon: BhorIcons.notes, label: 'ক্লাসের নোট', onTap: () {}),
              BhorMenuItem(icon: BhorIcons.delete, label: bnLong, destructive: true, onTap: () {}),
            ]);
          }),
        ),
        size: _desktop,
        scroll: false,
      );
      await tester.tap(find.text('মেনু'));
      await tester.pumpAndSettle();
      final RenderParagraph p = tester.renderObject<RenderParagraph>(find.text(bnLong));
      expect(p.size.width, greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.5));
      expectClean(tester);
    });

    testWidgets('a label longer than the widest menu wraps to a second line instead of an ellipsis',
        (WidgetTester tester) async {
      const String huge = 'A very long menu label that cannot possibly fit on one line of the widest menu';
      await pumpDs(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: _opener('menu', (BuildContext c) {
            showBhorMenu(c, items: <BhorMenuItem>[
              BhorMenuItem(icon: BhorIcons.notes, label: 'Short', onTap: () {}),
              BhorMenuItem(icon: BhorIcons.edit, label: huge, onTap: () {}),
            ]);
          }),
        ),
        lang: Lang.en,
        size: _desktop,
        scroll: false,
      );
      await tester.tap(find.text('menu'));
      await tester.pumpAndSettle();
      expect(tester.getSize(_popover).width, closeTo(bhorMenuMaxWidth, 0.5));
      final RenderParagraph hugeP = tester.renderObject<RenderParagraph>(find.text(huge));
      final RenderParagraph shortP = tester.renderObject<RenderParagraph>(find.text('Short'));
      expect(hugeP.size.height, greaterThan(shortP.size.height * 1.5), reason: 'wraps');
      expect(hugeP.didExceedMaxLines, isFalse);
      expectClean(tester);
    });
  });

  group('X6 confirmations without a body', () {
    testWidgets('showBhorConfirm: the buttons sit one normal gap under the title', (WidgetTester tester) async {
      await pumpDs(
        tester,
        Center(
          child: _opener('ask', (BuildContext c) {
            showBhorConfirm(c, title: 'Attendance not saved. Save now?', confirmLabel: 'Save');
          }),
        ),
        lang: Lang.en,
        size: _desktop,
        scroll: false,
      );
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      final Rect title = tester.getRect(find.text('Attendance not saved. Save now?'));
      final Rect button = tester.getRect(find.widgetWithText(BhorButton, 'Save'));
      expect(button.top - title.bottom, lessThanOrEqualTo(BhorSpace.s24 + 1));
      expectClean(tester);
    });

    testWidgets('showBhorConfirmChoice: title, then the two answers; ✕ / Esc returns null',
        (WidgetTester tester) async {
      final List<String?> got = <String?>[];
      await pumpDs(
        tester,
        Center(
          child: _opener('ask', (BuildContext c) async {
            got.add(await showBhorConfirmChoice<String>(
              c,
              title: 'Attendance not saved. Save now?',
              primaryLabel: 'Save',
              primaryValue: 'save',
              secondaryLabel: 'Discard',
              secondaryValue: 'discard',
            ));
          }),
        ),
        lang: Lang.en,
        size: _desktop,
        scroll: false,
      );
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      final Rect title = tester.getRect(find.text('Attendance not saved. Save now?'));
      final Finder close =
          find.byWidgetPredicate((Widget w) => w is BhorIconButton && w.icon == BhorIcons.close);
      final double headerBottom = close.evaluate().isEmpty ? title.bottom : tester.getRect(close).bottom;
      final double top = tester.getRect(find.widgetWithText(BhorButton, 'Save')).top;
      expect(top - (headerBottom > title.bottom ? headerBottom : title.bottom), lessThanOrEqualTo(BhorSpace.s24 + 1));
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(got, <String?>['discard']);

      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(got, <String?>['discard', null]);
      expectClean(tester);
    });
  });

  group('X4 absent thumb', () {
    for (final Brightness br in Brightness.values) {
      testWidgets('${br.name}: the absent thumb is the danger colour, not a pale slate', (WidgetTester tester) async {
        await pumpDs(
          tester,
          Center(
            child: SizedBox(
              width: 300,
              child: BhorAttendanceToggle(value: AttendanceKind.absent, onChanged: (AttendanceKind _) {}),
            ),
          ),
          brightness: br,
          size: _desktop,
          scroll: false,
        );
        await tester.pumpAndSettle();
        final BhorColors c = BhorThemeData.of(br).colors;
        final AnimatedContainer thumb = tester.widget<AnimatedContainer>(
          find.descendant(of: find.byType(BhorAttendanceToggle), matching: find.byType(AnimatedContainer)).first,
        );
        expect((thumb.decoration! as BoxDecoration).color, c.danger);
        expectClean(tester);
      });
    }
  });
}
