// The overdue count on the বেতন item of the shell navigation (UX 1), on the
// phone bottom nav and on the desktop sidebar, and the segments that link the
// dues list and the collection summary.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/adaptive_scaffold.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/features/dues/ui/collection_screen.dart';
import 'package:attendance_alamin/features/dues/ui/fees_screen.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../app/shell/shell_harness.dart';
import '../../helpers/fixtures.dart';

/// The badge count of the nav item labelled [label] inside [navKey].
Finder _badgeIn(Key navKey, String count) =>
    find.descendant(of: find.byKey(navKey), matching: find.text(count));

void main() {
  testWidgets('phone bottom nav: the fees item shows the overdue count (Bangla digits)',
      (WidgetTester tester) async {
    await pumpShell(tester);
    final AppLocalizations l10n = l10nOf(Lang.bn);
    final Finder badge = _badgeIn(AdaptiveScaffold.bottomNavKey, '৩');
    expect(badge, findsOneWidget);
    final Finder item = find.ancestor(of: badge, matching: find.byType(BhorPressable));
    expect(find.descendant(of: item, matching: find.text(l10n.navFees)), findsOneWidget);
    // A screen reader hears the label and "overdue 3".
    final BhorPressable p = tester.widget<BhorPressable>(item.first);
    expect(p.semanticLabel, '${l10n.navFees}, ${l10n.uiOverdueCount('৩')}');
  });

  testWidgets('desktop sidebar: the count in English digits', (WidgetTester tester) async {
    await pumpShell(tester, size: kDesktop, lang: Lang.en);
    expect(_badgeIn(AdaptiveScaffold.sidebarKey, '3'), findsOneWidget);
  });

  testWidgets('collapsed sidebar: the count stays on the icon', (WidgetTester tester) async {
    await pumpShell(tester, size: const Size(1000, 800), lang: Lang.en);
    expect(tester.getSize(find.byKey(AdaptiveScaffold.sidebarKey)).width, BhorSidebar.collapsedWidth);
    expect(_badgeIn(AdaptiveScaffold.sidebarKey, '3'), findsOneWidget);
  });

  testWidgets('the badge follows the data: no overdue student, no badge', (WidgetTester tester) async {
    final ShellHarness h = await pumpShell(tester);
    expect(_badgeIn(AdaptiveScaffold.bottomNavKey, '৩'), findsOneWidget);
    // Waive the three overdue months: nobody is overdue any more.
    final payments = h.container(tester).read(paymentsRepositoryProvider);
    await payments.waive(kEnrRahimPhys, const YearMonth(2026, 11));
    await payments.waive(kEnrNilaPhys, const YearMonth(2026, 11));
    await payments.waive(kEnrSaraChem, const YearMonth(2026, 10));
    await tester.pumpAndSettle();
    expect(_badgeIn(AdaptiveScaffold.bottomNavKey, '৩'), findsNothing);
  });

  testWidgets('the আদায় segment opens the collection summary and back', (WidgetTester tester) async {
    await pumpShell(tester, location: Routes.fees);
    final AppLocalizations l10n = l10nOf(Lang.bn);
    expect(find.byType(FeesScreen), findsOneWidget);
    await tester.tap(find.text(l10n.duesSegCollection));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionScreen), findsOneWidget);
    await tester.tap(find.text(l10n.duesSegDues));
    await tester.pumpAndSettle();
    expect(find.byType(FeesScreen), findsOneWidget);
  });

  testWidgets('outstanding of a month leads to the dues list for that month', (WidgetTester tester) async {
    await pumpShell(tester, location: Routes.feesCollection);
    final AppLocalizations l10n = l10nOf(Lang.bn);
    await tester.tap(find.byKey(const ValueKey<String>('coll-outstanding')));
    await tester.pumpAndSettle();
    expect(find.byType(FeesScreen), findsOneWidget);
    expect(find.text(l10n.duesFilterMonth('নভেম্বর ২০২৬')), findsOneWidget);
  });
}
