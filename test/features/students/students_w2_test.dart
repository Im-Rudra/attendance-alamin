// Wave 2 students rebuild (docs/council/15 S1-S5, G1, G2, G3, G8, G9): the
// master/detail layout, the filter row, the table, the empty states, the
// panels and the menus.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/shell/templates/templates.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_table.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';
import 'package:attendance_alamin/features/students/ui/student_profile_screen.dart';
import 'package:attendance_alamin/features/students/ui/students_screen.dart';
import 'package:attendance_alamin/features/students/widgets/student_keys.dart';
import 'package:attendance_alamin/features/students/widgets/student_row_tile.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

class _Launcher extends StatelessWidget {
  const _Launcher(this.onTap);

  final Future<void> Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) => Center(
        child: BhorButton(label: 'open', onPressed: () => onTap(context)),
      );
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

void main() {
  group('S1: master / detail', () {
    for (final Size size in const <Size>[Size(1536, 900), Size(1214, 800), Size(910, 800)]) {
      testWidgets('the profile column is at least 440 wide and nothing overflows [${size.width.toInt()}]',
          (WidgetTester tester) async {
        await pumpApp(
          tester,
          const StudentsScreen(selectedId: kStuSara),
          viewport: TestViewport.desktop,
          overrides: seedFakes().overrides,
        );
        await _resize(tester, size);
        final Finder detail = find.byKey(BhorMasterDetailPage.detailKey);
        expect(detail, findsOneWidget);
        expect(tester.getSize(detail).width, greaterThanOrEqualTo(StudentsScreen.profileMinWidth));
        expect(find.text('সারা আক্তার'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('with room for a table the table takes everything the profile leaves',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        const StudentsScreen(selectedId: kStuSara),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await _resize(tester, const Size(1536, 900));
      expect(find.byType(BatchTable<StudentRow>), findsOneWidget);
      final double master = tester.getSize(find.byKey(BhorMasterDetailPage.masterKey)).width;
      final double detail = tester.getSize(find.byKey(BhorMasterDetailPage.detailKey)).width;
      expect(detail, StudentsScreen.profileMinWidth);
      expect(master, greaterThan(detail));
    });

    testWidgets('nothing selected: the overview fills the detail column', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const StudentsScreen(),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      expect(find.byKey(BhorMasterDetailPage.detailKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('S2: filter row', () {
    for (final double width in const <double>[1280, 910, 420]) {
      testWidgets('three pills of one height, no overflow [${width.toInt()}]', (WidgetTester tester) async {
        await pumpApp(
          tester,
          const StudentsScreen(),
          viewport: TestViewport.desktop,
          overrides: seedFakes().overrides,
        );
        await _resize(tester, Size(width, 800));
        final double a = tester.getSize(find.byKey(const ValueKey<String>('stu-filter-batch'))).height;
        final double b = tester.getSize(find.byKey(const ValueKey<String>('stu-filter-dues'))).height;
        final double c = tester.getSize(find.byKey(const ValueKey<String>('stu-filter-left'))).height;
        expect(b, a);
        expect(c, a);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the batch chip opens a choice list and filters', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const StudentsScreen(),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await tester.tap(find.byKey(const ValueKey<String>('stu-filter-batch')));
      await tester.pumpAndSettle();
      expect(find.byType(BhorPopoverFrame), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('stu-batch-choice-$kBatChemB')));
      await tester.pumpAndSettle();
      // Only Karim and Sara are in Chem B.
      final Finder inTable = find.byType(BatchTable<StudentRow>);
      expect(find.descendant(of: inTable, matching: find.text('করিম হোসেন')), findsOneWidget);
      expect(find.descendant(of: inTable, matching: find.text('রহিম উদ্দিন')), findsNothing);
      // The chip now carries the batch name.
      expect(
        find.descendant(
            of: find.byKey(const ValueKey<String>('stu-filter-batch')), matching: find.text('কেমিস্ট্রি বি')),
        findsOneWidget,
      );
    });
  });

  group('S3: table', () {
    testWidgets('headers are not truncated in English and the card hugs its rows', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const StudentsScreen(),
        viewport: TestViewport.desktop,
        lang: Lang.en,
        overrides: seedFakes().overrides,
      );
      await _resize(tester, const Size(1536, 900));
      final Finder table = find.byType(BatchTable<StudentRow>);
      expect(table, findsOneWidget);
      final Finder header = find.text('Attendance %');
      expect(header, findsOneWidget);
      expect(tester.renderObject<RenderParagraph>(header).didExceedMaxLines, isFalse);
      expect(
        tester.getSize(table).height,
        lessThan(BatchTable.rowHeight * kStudents.length + 80),
        reason: 'no tall empty card',
      );
    });
  });

  group('S4: empty filter result', () {
    testWidgets('offers Clear filters, which restores the list', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const StudentsScreen(),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await tester.enterText(find.byKey(const ValueKey<String>('stu-search')), 'zzzzzz');
      await tester.pumpAndSettle();
      expect(find.byType(BhorEmptyState), findsOneWidget);
      final Finder clear = find.byKey(const ValueKey<String>('stu-clear-filters'));
      expect(clear, findsOneWidget);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(find.byType(BhorEmptyState), findsNothing);
      expect(find.text('রহিম উদ্দিন'), findsWidgets);
      final BhorTextField search = tester.widget<BhorTextField>(find.byKey(const ValueKey<String>('stu-search')));
      expect(search.controller?.text, isEmpty);
    });
  });

  group('S5: enrol in another batch', () {
    testWidgets('a student in every batch gets an empty state with a New batch action',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          await showEnrollSheet(c, studentId: kStuSara);
        }),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('stu-enroll-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stu-enroll-new-batch')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stu-enroll-confirm')), findsNothing);
      expect(find.text('এই ব্যাচে আছে'), findsNothing);
    });
  });

  group('G1 / G3: Add student is a panel with an unsaved-changes guard', () {
    testWidgets('openAddStudent opens a side panel; Esc with input asks, without input closes',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          await openAddStudent(c, batchId: kBatChemB);
        }),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorSidePanelFrame), findsOneWidget);

      // Untouched form: Esc closes straight away.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(BhorSidePanelFrame), findsNothing);

      // With a name typed: Esc asks first.
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('stu-field-name')), 'নতুন নাম');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('বাতিল করবেন?'), findsOneWidget);
      expect(find.byType(BhorSidePanelFrame), findsOneWidget);
    });
  });

  group('G2 / G8: menus', () {
    testWidgets('profile ⋮ is a menu with Delete last; Esc closes only the menu', (WidgetTester tester) async {
      int cleared = 0;
      await pumpApp(
        tester,
        StudentKeys(
          onEscape: () => cleared++,
          child: const StudentProfileScreen(studentId: kStuSara),
        ),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await tester.pumpAndSettle();
      final Finder more = find.byWidgetPredicate((Widget w) => w is BhorIconButton && w.icon == BhorIcons.overflowVertical);
      expect(more, findsWidgets);
      await tester.tap(more.first);
      await tester.pumpAndSettle();
      expect(find.byType(BhorMenu), findsOneWidget);
      final double enrol = tester.getTopLeft(find.descendant(of: find.byType(BhorMenu), matching: find.text('অন্য ব্যাচে ভর্তি'))).dy;
      final double delete = tester.getTopLeft(find.descendant(of: find.byType(BhorMenu), matching: find.text('মুছুন'))).dy;
      expect(delete, greaterThan(enrol), reason: 'Delete is the last item');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(BhorMenu), findsNothing);
      expect(cleared, 0, reason: 'Esc belonged to the menu, the selection stays');
    });

    testWidgets('the right-click menu is the same component', (WidgetTester tester) async {
      await pumpApp(
        tester,
        _Launcher((BuildContext c) => showStudentContextMenu(
              c,
              Offset.zero,
              StudentRow(student: kStudents.first, batches: const []),
            )),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BhorMenu), findsOneWidget);
    });
  });

  group('G9: digits', () {
    testWidgets('roll, phone and fee fields show local digits', (WidgetTester tester) async {
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          await openAddStudent(c, batchId: kBatChemB);
        }),
        viewport: TestViewport.desktop,
        overrides: seedFakes().overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('stu-more-info')));
      await tester.pumpAndSettle();
      for (final String key in <String>[
        'stu-field-roll',
        'stu-field-phone',
        'stu-field-guardian-phone',
        'stu-field-fee-override',
      ]) {
        final BhorTextField f = tester.widget<BhorTextField>(find.byKey(ValueKey<String>(key)));
        expect(f.localDigits, isTrue, reason: key);
      }
    });
  });
}
