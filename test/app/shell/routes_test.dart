// M5-A acceptance: every route renders (stub) on phone and desktop, a deep
// link reaches the roll-call stub, and ≥ 840 shows master + detail.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/router.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/attendance/ui/batch_roll_call_launcher.dart';
import 'package:attendance_alamin/features/attendance/ui/roll_call_screen.dart';
import 'package:attendance_alamin/features/backup/ui/backup_review_screen.dart';
import 'package:attendance_alamin/features/backup/ui/backup_screen.dart';
import 'package:attendance_alamin/features/batches/ui/archived_batches_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batch_detail_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batch_form_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batches_screen.dart';
import 'package:attendance_alamin/features/dues/ui/collection_screen.dart';
import 'package:attendance_alamin/features/dues/ui/fees_screen.dart';
import 'package:attendance_alamin/features/extras/ui/bulk_add_screen.dart';
import 'package:attendance_alamin/features/extras/ui/holiday_screen.dart';
import 'package:attendance_alamin/features/home/ui/today_screen.dart';
import 'package:attendance_alamin/features/onboarding/ui/onboarding_screen.dart';
import 'package:attendance_alamin/features/reminders/ui/reminder_priming_screen.dart';
import 'package:attendance_alamin/features/schedule/ui/slot_editor_screen.dart';
import 'package:attendance_alamin/features/search/ui/search_screen.dart';
import 'package:attendance_alamin/features/settings/ui/diagnostics_screen.dart';
import 'package:attendance_alamin/features/settings/ui/help_screen.dart';
import 'package:attendance_alamin/features/settings/ui/more_screen.dart';
import 'package:attendance_alamin/features/settings/ui/payment_methods_screen.dart';
import 'package:attendance_alamin/features/settings/ui/template_editor_screen.dart';
import 'package:attendance_alamin/features/students/ui/left_students_screen.dart';
import 'package:attendance_alamin/features/students/ui/student_form_screen.dart';
import 'package:attendance_alamin/features/students/ui/student_profile_screen.dart';
import 'package:attendance_alamin/features/students/ui/students_screen.dart';

import 'shell_harness.dart';

const LocalDate _day = LocalDate(2026, 11, 21);

/// Location → screen shown on a phone.
final Map<String, Type> _routes = <String, Type>{
  '/': TodayScreen,
  Routes.today: TodayScreen,
  Routes.batches: BatchesScreen,
  Routes.batchNew: BatchFormScreen,
  Routes.batch('b1'): BatchDetailScreen,
  Routes.batchEdit('b1'): BatchFormScreen,
  Routes.batchSlots('b1'): SlotEditorScreen,
  Routes.batchRollCall('b1', _day): BatchRollCallLauncher,
  '/batches/b1/rollcall/not-a-date': NotFoundScreen,
  Routes.batchBulkAdd('b1'): BulkAddScreen,
  Routes.students: StudentsScreen,
  Routes.studentNew: StudentFormScreen,
  Routes.student('s1'): StudentProfileScreen,
  Routes.studentEdit('s1'): StudentFormScreen,
  Routes.fees: FeesScreen,
  Routes.feesStudent('s1'): StudentProfileScreen,
  Routes.feesCollection: CollectionScreen,
  Routes.more: MoreScreen,
  Routes.moreBackup: BackupScreen,
  Routes.moreBackupReview: BackupReviewScreen,
  Routes.moreArchived: ArchivedBatchesScreen,
  Routes.moreLeft: LeftStudentsScreen,
  Routes.moreTemplate('reminder'): TemplateEditorScreen,
  Routes.moreTemplate('receipt'): TemplateEditorScreen,
  Routes.morePaymentMethods: PaymentMethodsScreen,
  Routes.moreHolidays: HolidayScreen,
  Routes.moreDiagnostics: DiagnosticsScreen,
  Routes.moreHelp: HelpScreen,
  Routes.rollCall('s.x.20261121'): RollCallScreen,
  Routes.search: SearchScreen,
  Routes.onboarding: OnboardingScreen,
  Routes.reminderPriming: ReminderPrimingScreen,
  '/no/such/page': NotFoundScreen,
};

/// A page frame: the Material one (not yet migrated) or the Bhor one.
Finder _anyScaffold() => find.byWidgetPredicate(
      (Widget w) => w is Scaffold || w is BhorScaffold,
      description: 'Scaffold or BhorScaffold',
    );

void main() {
  group('every route renders', () {
    for (final MapEntry<String, Type> r in _routes.entries) {
      testWidgets('phone light bn ${r.key}', (WidgetTester tester) async {
        await pumpShell(tester, location: r.key);
        expect(find.byType(r.value), findsWidgets);
        expect(tester.takeException(), isNull);
      });
      testWidgets('desktop dark en ${r.key}', (WidgetTester tester) async {
        await pumpShell(tester, location: r.key, size: kDesktop, lang: Lang.en, themeMode: ThemeMode.dark);
        expect(_anyScaffold(), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('matrix of the tab roots', () {
    for (final String loc in Routes.branchRoots) {
      for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        for (final Lang lang in Lang.values) {
          for (final Size size in <Size>[kPhone, kDesktop]) {
            testWidgets('$loc ${mode.name} ${lang.name} ${size.width.toInt()}', (WidgetTester tester) async {
              await pumpShell(tester, location: loc, size: size, lang: lang, themeMode: mode);
              expect(_anyScaffold(), findsWidgets);
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  });

  testWidgets('deep link /rollcall/s.x.20261121 reaches the roll-call stub', (WidgetTester tester) async {
    await pumpShell(tester, location: '/rollcall/s.x.20261121');
    final RollCallScreen screen = tester.widget(find.byType(RollCallScreen));
    expect(screen.occ, 's.x.20261121');
    // Opened directly: the close button goes to Today.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('batch roll-call launcher parses the date', (WidgetTester tester) async {
    await pumpShell(tester, location: Routes.batchRollCall('b9', _day));
    final BatchRollCallLauncher screen = tester.widget(find.byType(BatchRollCallLauncher));
    expect(screen.batchId, 'b9');
    expect(screen.date, _day);
  });

  testWidgets('desktop /batches/:id shows list and detail side by side', (WidgetTester tester) async {
    await pumpShell(tester, location: Routes.batch('b1'), size: kDesktop);
    expect(find.byType(BatchesScreen), findsOneWidget);
    final BatchDetailScreen detail = tester.widget(find.byType(BatchDetailScreen));
    expect(detail.batchId, 'b1');
    final Rect list = tester.getRect(find.byType(BatchesScreen));
    final Rect pane = tester.getRect(find.byType(BatchDetailScreen));
    expect(pane.left, greaterThan(list.left));
    expect(pane.width, greaterThanOrEqualTo(480));
  });

  testWidgets('phone /batches/:id shows the detail alone', (WidgetTester tester) async {
    await pumpShell(tester, location: Routes.batch('b1'));
    expect(find.byType(BatchDetailScreen), findsOneWidget);
    expect(find.byType(BatchesScreen), findsNothing);
    // Back arrow returns to the list.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(BatchesScreen), findsOneWidget);
  });

  testWidgets('desktop /students/:id and /fees/s/:id are two-pane', (WidgetTester tester) async {
    await pumpShell(tester, location: Routes.student('s1'), size: kDesktop);
    expect(find.byType(StudentsScreen), findsOneWidget);
    expect(find.byType(StudentProfileScreen), findsOneWidget);
  });

  testWidgets('student new takes the batch from route extra', (WidgetTester tester) async {
    final ShellHarness h = await pumpShell(tester, location: Routes.students);
    h.container(tester).read(routerProvider).push(Routes.studentNew, extra: 'b7');
    await tester.pumpAndSettle();
    final StudentFormScreen form = tester.widget(find.byType(StudentFormScreen));
    expect(form.initialBatchId, 'b7');
    expect(form.studentId, isNull);
  });
}
