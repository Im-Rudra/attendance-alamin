// M4-D: every Aurora widget in light + dark x bn + en. A pump that throws
// (including RenderFlex overflow) fails the test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import 'harness.dart';

MonthDue month(
  int m, {
  MonthState state = MonthState.unpaid,
  DueLevel? level,
  int remaining = 1200,
  bool isDue = true,
}) {
  return MonthDue(
    month: YearMonth(2026, m),
    fee: 1200,
    feeMissing: false,
    paid: state == MonthState.paid ? 1200 : 0,
    remaining: remaining,
    state: state,
    dueDate: LocalDate(2026, m, 1),
    isDue: isDue,
    level: level,
    dayInDue: level == null || level == DueLevel.upcoming || level == DueLevel.overdue ? null : level.rank * 2 - 1,
  );
}

void matrixTest(
  String name,
  Widget Function() build,
  Future<void> Function(WidgetTester tester, AppLocalizations l10n)? verify, {
  Size size = const Size(800, 900),
  bool reduced = true,
}) {
  for (final (Brightness, Lang) m in kMatrix) {
    testWidgets('$name [${matrixName(m)}]', (WidgetTester tester) async {
      await pumpAurora(tester, build(), brightness: m.$1, lang: m.$2, size: size, reduced: reduced);
      expect(tester.takeException(), isNull);
      if (verify != null) await verify(tester, l10nFor(m.$2));
    });
  }
}

void main() {
  group('MeshBackground', () {
    matrixTest(
      'paints behind its child (reduced)',
      () => const MeshBackground(child: Center(child: Text('hello'))),
      (WidgetTester tester, AppLocalizations l10n) async {
        expect(find.text('hello'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
      },
    );
    matrixTest(
      'paints behind its child (full effects)',
      () => const MeshBackground(child: Center(child: Text('hello'))),
      (WidgetTester tester, AppLocalizations l10n) async {
        expect(find.text('hello'), findsOneWidget);
      },
      reduced: false,
    );
  });

  group('GlassCard', () {
    matrixTest(
      'plain, dense and tappable',
      () => Column(
        children: <Widget>[
          const GlassCard(child: Text('plain')),
          const GlassCard(dense: true, child: Text('dense')),
          GlassCard(onTap: () {}, child: const Text('tap')),
        ],
      ),
      (WidgetTester tester, AppLocalizations l10n) async {
        expect(find.text('plain'), findsOneWidget);
        expect(find.text('dense'), findsOneWidget);
        expect(tester.getSize(find.byType(GlassCard).last).height, greaterThanOrEqualTo(48));
      },
    );
  });

  group('HeroCard', () {
    for (final (Brightness, Lang) m in kMatrix) {
      testWidgets('hero with CTA [${matrixName(m)}]', (WidgetTester tester) async {
        int taps = 0;
        await pumpAurora(
          tester,
          Padding(
            padding: const EdgeInsets.all(16),
            child: HeroCard(
              cta: HeroPillButton(label: 'Go', onPressed: () => taps++),
              child: const Text('Next class'),
            ),
          ),
          brightness: m.$1,
          lang: m.$2,
        );
        expect(find.text('Next class'), findsOneWidget);
        expect(tester.getSize(find.byType(HeroPillButton)).height, greaterThanOrEqualTo(48));
        await tester.tap(find.byType(HeroPillButton));
        expect(taps, 1);
      });
    }
  });

  group('SeverityBadge', () {
    matrixTest(
      'every DueLevel shows its word',
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final DueLevel l in DueLevel.values)
            SeverityBadge(
              level: l,
              dayInDue: (l == DueLevel.upcoming || l == DueLevel.overdue) ? null : l.rank * 2 - 1,
              monthCount: l == DueLevel.urgent ? 3 : 1,
              partialRemaining: l == DueLevel.followUp ? 300 : null,
            ),
          const SeverityBadge(level: DueLevel.overdue, compact: true),
        ],
      ),
      (WidgetTester tester, AppLocalizations l10n) async {
        for (final DueLevel l in DueLevel.values) {
          expect(find.textContaining(l.label(l10n)), findsWidgets, reason: l.name);
        }
      },
    );

    testWidgets('semantics carry the full text', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAurora(
        tester,
        const SeverityBadge(level: DueLevel.urgent, dayInDue: 7, monthCount: 2),
        lang: Lang.en,
      );
      final SemanticsData data = tester.getSemantics(find.byType(SeverityBadge)).getSemanticsData();
      expect(data.label, contains('Urgent'));
      expect(data.label, contains('day 7'));
      expect(data.label, contains('2 months due'));
      handle.dispose();
    });

    test('overdue is solid in both themes; level 5 has the strong border', () {
      final SeverityColors light = const SeverityColors.light();
      final SeverityColors dusk = const SeverityColors.dusk();
      const SeverityLevel od = SeverityLevel.overdue;
      expect(light.badgeFill(od), dusk.badgeFill(od));
      expect(light.badgeFill(od).a, 1.0);
      expect(light.badgeBorderWidth(SeverityLevel.finalDays), 1.5);
      expect(light.badgeBorder(SeverityLevel.finalDays), isNotNull);
    });
  });

  group('Escalation', () {
    matrixTest(
      'bar with today ringed, beyond window and overdue badge',
      () => const Column(
        children: <Widget>[
          EscalationBar(todayDay: 5, overdueCount: 3),
          SizedBox(height: 12),
          EscalationBar(todayDay: null, overdueCount: 2),
          SizedBox(height: 12),
          EscalationBar(todayDay: 1),
          SizedBox(height: 12),
          EscalationBar(todayDay: 10),
          Row(children: <Widget>[SizedBox(height: 40, child: LevelEdgeBar(level: DueLevel.urgent))]),
        ],
      ),
      (WidgetTester tester, AppLocalizations l10n) async {
        expect(find.byKey(const ValueKey<String>('escalation-segment-10')), findsNWidgets(4));
      },
    );

    testWidgets('semantics announce the day', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAurora(tester, const EscalationBar(todayDay: 5), lang: Lang.en);
      expect(find.bySemanticsLabel('Day 5 of 10 since due'), findsOneWidget);
      handle.dispose();
    });
  });

  group('Month chips', () {
    matrixTest(
      'every month state',
      () => MonthStrip(
        months: <MonthDue>[
          month(1, state: MonthState.paid, isDue: true),
          month(2, state: MonthState.paid, isDue: false),
          month(3, state: MonthState.waived),
          month(4, state: MonthState.free),
          month(5, state: MonthState.unpaid),
          month(6, state: MonthState.unpaid, level: DueLevel.justDue),
          month(7, state: MonthState.partial, level: DueLevel.urgent, remaining: 300),
          month(8, state: MonthState.unpaid, level: DueLevel.overdue),
        ],
        onTap: (YearMonth _) {},
      ),
      (WidgetTester tester, AppLocalizations l10n) async {
        expect(find.byType(MonthStateChip), findsWidgets);
        expect(find.textContaining(l10n.uiStatePaid), findsWidgets);
      },
    );

    testWidgets('tap reports the month', (WidgetTester tester) async {
      YearMonth? tapped;
      await pumpAurora(
        tester,
        MonthStrip(
          months: <MonthDue>[month(5, state: MonthState.paid)],
          onTap: (YearMonth m) => tapped = m,
        ),
      );
      await tester.tap(find.byType(MonthStateChip));
      expect(tapped, const YearMonth(2026, 5));
    });
  });

  group('Attendance', () {
    matrixTest(
      'status chips (full and short)',
      () => Wrap(
        children: <Widget>[
          for (final AttendanceStatus s in AttendanceStatus.values) AttendanceStatusChip(status: s),
          for (final AttendanceStatus s in AttendanceStatus.values)
            AttendanceStatusChip(status: s, short: true),
        ],
      ),
      (WidgetTester tester, AppLocalizations l10n) async {
        for (final AttendanceStatus s in AttendanceStatus.values) {
          expect(find.text(s.label(l10n)), findsOneWidget);
          expect(find.text(s.shortLabel(l10n)), findsOneWidget);
        }
      },
    );

    for (final (Brightness, Lang) m in kMatrix) {
      testWidgets('toggle row [${matrixName(m)}]', (WidgetTester tester) async {
        int toggled = 0;
        int lateCount = 0;
        await pumpAurora(
          tester,
          Column(
            children: <Widget>[
              for (final AttendanceStatus? s in <AttendanceStatus?>[null, ...AttendanceStatus.values])
                AttendanceToggleRow(
                  name: 'রাকিব হাসান',
                  roll: 3,
                  status: s,
                  onToggle: () => toggled++,
                  onLateToggle: () => lateCount++,
                ),
            ],
          ),
          brightness: m.$1,
          lang: m.$2,
          size: const Size(800, 1000),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('রাকিব হাসান').first);
        expect(toggled, 1);
        final Finder lateButtons = find.byWidgetPredicate(
          (Widget w) => w is InkWell && w.customBorder is StadiumBorder,
        );
        expect(tester.getSize(lateButtons.first).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(lateButtons.first).height, greaterThanOrEqualTo(48));
        await tester.tap(lateButtons.first);
        expect(lateCount, 1);
      });
    }
  });

  group('StatePill', () {
    matrixTest(
      'every class state',
      () => Wrap(children: <Widget>[for (final ClassState s in ClassState.values) StatePill(state: s)]),
      (WidgetTester tester, AppLocalizations l10n) async {
        expect(find.text(l10n.uiClassNow), findsOneWidget);
        expect(find.text(l10n.uiClassMoved), findsOneWidget);
        expect(find.text(l10n.uiClassCancelled), findsOneWidget);
        expect(find.text(l10n.uiClassExtra), findsOneWidget);
      },
    );
  });

  group('StatTile', () {
    matrixTest(
      'label, number and caption',
      () => const SizedBox(
        width: 240,
        child: StatTile(label: 'Dues', value: '৳12,400', caption: '7 unpaid', footer: Text('footer')),
      ),
      (WidgetTester tester, AppLocalizations l10n) async {
        expect(find.text('৳12,400'), findsOneWidget);
        expect(find.text('footer'), findsOneWidget);
      },
    );
  });

  group('EmptyState', () {
    matrixTest(
      'fills its tile',
      () => const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 400, height: 300, child: EmptyState(icon: Icons.check_circle, message: 'All paid')),
      ),
      (WidgetTester tester, AppLocalizations l10n) async {
        expect(tester.getSize(find.byType(EmptyState)), const Size(400, 300));
        final Offset c = tester.getCenter(find.text('All paid'));
        expect(c.dx, closeTo(200, 1));
      },
    );

    testWidgets('button fires and fill:false wraps content', (WidgetTester tester) async {
      int n = 0;
      await pumpAurora(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 600,
            child: Align(
              alignment: Alignment.topLeft,
              child: EmptyState(
                icon: Icons.group,
                message: 'No students',
                actionLabel: 'Add',
                onAction: () => n++,
                fill: false,
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(EmptyState)).height, lessThan(600));
      await tester.tap(find.text('Add'));
      expect(n, 1);
    });
  });

  group('StickyActionBar', () {
    for (final (Brightness, Lang) m in kMatrix) {
      testWidgets('enabled and disabled [${matrixName(m)}]', (WidgetTester tester) async {
        int n = 0;
        await pumpAurora(
          tester,
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              StickyActionBar(label: 'Save', summary: '28 present', onPressed: () => n++),
              const StickyActionBar(label: 'Save too', disabledReason: 'Pick a batch first'),
            ],
          ),
          brightness: m.$1,
          lang: m.$2,
        );
        expect(find.text('Pick a batch first'), findsOneWidget);
        expect(tester.getSize(find.widgetWithText(FilledButton, 'Save')).height, greaterThanOrEqualTo(56));
        await tester.tap(find.text('Save'));
        expect(n, 1);
      });
    }
  });

  group('InitialsAvatar', () {
    test('grapheme-safe initials', () {
      expect(initialsOf('রাকিব হাসান'), 'রাহা');
      expect(initialsOf('Rakib Hasan Khan'), 'RH');
      expect(initialsOf('  sara '), 'S');
      expect(initialsOf('   '), '?');
    });

    matrixTest(
      'renders initials',
      () => const Row(children: <Widget>[InitialsAvatar(name: 'রাকিব হাসান'), InitialsAvatar(name: 'Sara', size: 56)]),
      (WidgetTester tester, AppLocalizations l10n) async {
        expect(find.text('রাহা'), findsOneWidget);
        expect(find.text('S'), findsOneWidget);
      },
    );
  });

  group('ConflictCard', () {
    for (final (Brightness, Lang) m in kMatrix) {
      testWidgets('lines, more and fixes [${matrixName(m)}]', (WidgetTester tester) async {
        int fixed = 0;
        await pumpAurora(
          tester,
          ConflictCard(
            lines: const <String>['Math 10 A, 10:00-11:00'],
            moreCount: 2,
            fixes: <ConflictFix>[
              ConflictFix(label: 'Move', onTap: () => fixed++, primary: true),
              ConflictFix(label: 'Keep', onTap: () {}),
            ],
          ),
          brightness: m.$1,
          lang: m.$2,
        );
        expect(find.textContaining(l10nFor(m.$2).uiConflictTitle), findsOneWidget);
        await tester.tap(find.text('Move'));
        expect(fixed, 1);
      });
    }
  });

  group('SectionHeader and SegmentedChoice', () {
    matrixTest(
      'header with trailing',
      () => const SectionHeader(title: 'Today', trailing: Icon(Icons.chevron_right)),
      (WidgetTester tester, AppLocalizations l10n) async {
        expect(find.text('Today'), findsOneWidget);
      },
    );

    for (final (Brightness, Lang) m in kMatrix) {
      testWidgets('segmented choice [${matrixName(m)}]', (WidgetTester tester) async {
        String value = 'cash';
        await pumpAurora(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter set) => SegmentedChoice<String>(
              options: const <String>['cash', 'bkash', 'nagad'],
              selected: value,
              onChanged: (String v) => set(() => value = v),
              labelOf: (String s) => s,
            ),
          ),
          brightness: m.$1,
          lang: m.$2,
        );
        expect(find.byIcon(Icons.check), findsOneWidget);
        for (final Element e in find.byType(InkWell).evaluate()) {
          expect(e.size!.height, greaterThanOrEqualTo(48));
        }
        await tester.tap(find.text('nagad'));
        await tester.pump();
        expect(value, 'nagad');
      });
    }
  });

  group('DenseTable', () {
    for (final (Brightness, Lang) m in kMatrix) {
      testWidgets('header, rows, selection and tap [${matrixName(m)}]', (WidgetTester tester) async {
        String? tapped;
        await pumpAurora(
          tester,
          SizedBox(
            height: 400,
            child: DenseTable<String>(
              columns: <DenseColumn<String>>[
                DenseColumn<String>(label: 'Name', flex: 3, cell: (String r) => Text(r)),
                DenseColumn<String>(label: 'Due', numeric: true, cell: (String r) => Text('৳${r.length}')),
              ],
              rows: <String>[for (int i = 0; i < 30; i++) 'Student $i'],
              selected: 'Student 1',
              onRowTap: (String r) => tapped = r,
            ),
          ),
          brightness: m.$1,
          lang: m.$2,
        );
        expect(find.text('Name'), findsOneWidget);
        expect(tester.getSize(find.text('Student 0').first).height, lessThanOrEqualTo(48));
        await tester.tap(find.text('Student 2'));
        expect(tapped, 'Student 2');
        // Sticky header: still there after scrolling the rows.
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pump();
        expect(find.text('Name'), findsOneWidget);
      });
    }
  });

  group('Dialogs', () {
    for (final (Brightness, Lang) m in kMatrix) {
      testWidgets('confirm dialog and undo snackbar [${matrixName(m)}]', (WidgetTester tester) async {
        final AppLocalizations l10n = l10nFor(m.$2);
        bool? result;
        int undone = 0;
        await pumpAurora(
          tester,
          Builder(
            builder: (BuildContext context) => Column(
              children: <Widget>[
                TextButton(
                  onPressed: () async => result = await showConfirmDialog(
                    context,
                    title: 'Delete 3 payments?',
                    body: 'This cannot be undone.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  ),
                  child: const Text('open'),
                ),
                TextButton(
                  onPressed: () => showUndoSnackBar(context, message: 'Saved', onUndo: () => undone++),
                  child: const Text('snack'),
                ),
              ],
            ),
          ),
          brightness: m.$1,
          lang: m.$2,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Delete 3 payments?'), findsOneWidget);
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();
        expect(result, isFalse);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(result, isTrue);

        await tester.tap(find.text('snack'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Saved'), findsOneWidget);
        await tester.tap(find.text(l10n.commonUndo));
        await tester.pumpAndSettle();
        expect(undone, 1);
      });
    }
  });

  group('theme mapping', () {
    test('enum bridges keep the declaration order', () {
      for (final DueLevel l in DueLevel.values) {
        expect(l.severityLevel.index, l.index);
      }
      for (final AttendanceStatus s in AttendanceStatus.values) {
        expect(s.kind.index, s.index);
      }
    });
  });
}
