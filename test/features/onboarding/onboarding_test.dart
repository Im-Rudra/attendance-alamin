// M8-C tests: every onboarding step in the 8-case matrix, and the whole first
// run from "choose language" to Today: a subject, a batch with a weekly slot
// and two students are created, onboardingDone is set and the coach mark shows
// once.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/onboarding/ui/onboarding_screen.dart';
import 'package:attendance_alamin/features/onboarding/widgets/coach_mark.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations bn = lookupAppLocalizations(const Locale('bn'));
const AppFormat fmtBn = AppFormat(Lang.bn);

/// Fakes with no data at all (a brand-new install).
SeededFakes emptyFakes() {
  final SeededFakes f = seedFakes(withAttendance: false, withPayments: false);
  f.store.subjects.clear();
  f.store.batches.clear();
  f.store.slots.clear();
  f.store.fees.clear();
  f.students.students.clear();
  f.enrollments.enrollments.clear();
  return f;
}

List<Override> overridesOf(SeededFakes f) => <Override>[
      ...f.overrides,
      initialPrefsProvider.overrideWithValue(const AppPrefs(
        lang: Lang.bn,
        themeMode: ThemeMode.system,
        reducedEffects: true,
        onboardingDone: false,
      )),
    ];

/// The onboarding screen on a tiny router, Today being a plain marker page.
Widget app(GoRouter router) => Router.withConfig(config: router);

GoRouter makeRouter() {
  final GoRouter router = GoRouter(
    initialLocation: Routes.onboarding,
    routes: <RouteBase>[
      GoRoute(path: Routes.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(
        path: Routes.today,
        builder: (_, __) => const BhorScaffold(
          body: Align(alignment: Alignment.topLeft, child: CoachMarkAnchor(child: Text('TODAY-PAGE'))),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

Finder key(String k) => find.byKey(Key(k));

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.ensureVisible(key(k));
  await tester.tap(key(k));
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, String k, String text) async {
  await tester.enterText(key(k), text);
  await tester.pump();
}

String textOf(WidgetTester tester, String k) =>
    tester.widget<BhorTextField>(key(k)).controller!.text;

/// Walks the screen to the 0-based [step] the way a teacher would.
Future<void> toStep(WidgetTester tester, int step) async {
  if (step >= 1) await tapKey(tester, 'onb-primary');
  if (step >= 2) {
    await typeInto(tester, 'onb-subject', 'গণিত');
    await typeInto(tester, 'onb-fee', '1000');
    await tester.pumpAndSettle();
    await tapKey(tester, 'onb-primary');
  }
  if (step >= 3) await tapKey(tester, 'onb-primary');
}

void main() {
  group('Onboarding screens', () {
    for (int step = 0; step < 4; step++) {
      testScreenMatrix(
        'Onboarding step ${step + 1}',
        () => app(makeRouter()),
        overrides: () => overridesOf(emptyFakes()),
        verify: (WidgetTester tester) async {
          await toStep(tester, step);
          expect(key('onb-primary'), findsOneWidget);
          final bool wide = tester.view.physicalSize.width >= 840;
          expect(key('onb-pane-tip'), wide ? findsOneWidget : findsNothing);
        },
      );
    }
  });

  group('Onboarding flow', () {
    testWidgets('first launch to Today: language, batch with a slot, two students',
        (WidgetTester tester) async {
      final SeededFakes f = emptyFakes();
      await pumpApp(
        tester,
        app(makeRouter()),
        overrides: overridesOf(f),
        viewport: TestViewport.desktop,
      );
      await tester.pumpAndSettle();

      // Step 1: language + center name.
      expect(find.text(bn.onbWelcomeTitle), findsOneWidget);
      await tapKey(tester, 'onb-lang-en');
      expect(containerOf(tester).read(langProvider), Lang.en);
      await typeInto(tester, 'onb-center', 'Alokito Coaching');
      await tapKey(tester, 'onb-primary');
      expect(await f.settings.get(SettingKeys.centerName), 'Alokito Coaching');

      // Step 2: subject chip + class chip compose "Math — Class 10".
      expect(find.text(bn.onbBatchTitle), findsOneWidget);
      expect(textOf(tester, 'onb-batch-name'), bn.onbBatchTimeName('সকাল ১১'));
      await tester.ensureVisible(find.widgetWithText(BhorChip, bn.batchSuggestMath));
      await tester.tap(find.widgetWithText(BhorChip, bn.batchSuggestMath));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(BhorChip, bn.onbClass10));
      await tester.tap(find.widgetWithText(BhorChip, bn.onbClass10));
      await tester.pump();
      expect(textOf(tester, 'onb-subject'), '${bn.batchSuggestMath} — ${bn.onbClass10}');
      // No fee yet: the button says why it is off.
      expect(tester.widget<BhorButton>(key('onb-primary')).onPressed, isNull);
      expect(find.text(bn.batchReasonFee), findsOneWidget);
      await typeInto(tester, 'onb-fee', '১২০০');
      await tester.pumpAndSettle();
      await tapKey(tester, 'onb-primary');

      expect(f.store.batches, hasLength(1));
      final Batch batch = f.store.batches.single;
      expect(f.store.subjectName(batch.subjectId), '${bn.batchSuggestMath} — ${bn.onbClass10}');
      expect(f.store.slots.where((s) => s.batchId == batch.id), hasLength(1));
      expect(f.store.fees[batch.id]!.single.amount, 1200);

      // Step 3: the quick-add loop keeps the cursor on the name field.
      expect(find.text(bn.onbStudentsTitle), findsOneWidget);
      expect(find.text(bn.onbStudentsIntoBatch(batch.name)), findsOneWidget);
      expect(find.text(bn.onbBillingStartNote(fmtBn.monthYear(const YearMonth(2026, 11)))), findsOneWidget);
      await typeInto(tester, 'onb-student-name', 'রহিম উদ্দিন');
      await tapKey(tester, 'onb-student-add');
      expect(tester.widget<BhorTextField>(key('onb-student-name')).focusNode!.hasFocus, isTrue);
      expect(textOf(tester, 'onb-student-name'), '');
      await typeInto(tester, 'onb-student-name', 'করিম হোসেন');
      await typeInto(tester, 'onb-student-phone', '01712345678');
      await tapKey(tester, 'onb-student-add');
      expect(find.text(bn.onbStudentsAdded('২')), findsOneWidget);
      expect(f.students.students.map((Student s) => s.name),
          <String>['রহিম উদ্দিন', 'করিম হোসেন']);
      expect(f.students.students.last.guardianPhone, '01712345678');
      // The added list echoes the phone under the student.
      expect(find.text(fmtBn.digits('01712345678')), findsOneWidget);
      expect(f.enrollments.enrollments, hasLength(2));
      expect(f.enrollments.enrollments.every((e) => e.batchId == batch.id), isTrue);
      // Existing students: billing starts this month (the 21st is past the
      // cutoff, yet the first month is November, not December).
      expect(f.enrollments.enrollments.every((e) => e.startMonth == const YearMonth(2026, 11)), isTrue);
      await tapKey(tester, 'onb-primary');

      // Step 4: "Not now" finishes; Today opens with the one-time coach mark.
      expect(find.text(bn.onbRemindTitle), findsOneWidget);
      expect(await f.settings.get(SettingKeys.onboardingDone), isFalse);
      await tapKey(tester, 'onb-secondary');
      expect(await f.settings.get(SettingKeys.onboardingDone), isTrue);
      expect(find.text('TODAY-PAGE'), findsOneWidget);
      expect(find.text(bn.onbCoachText), findsOneWidget);
      expect(f.localMeta.values[kRollCallCoachMetaKey], isNotNull);

      await tapKey(tester, 'onb-coach-ok');
      expect(find.text(bn.onbCoachText), findsNothing);
    });

    testWidgets('back and forward keep what was typed; skipping keeps the app usable',
        (WidgetTester tester) async {
      final SeededFakes f = emptyFakes();
      await pumpApp(tester, app(makeRouter()), overrides: overridesOf(f));
      await tester.pumpAndSettle();

      await tapKey(tester, 'onb-primary');
      await typeInto(tester, 'onb-subject', 'রসায়ন');
      await typeInto(tester, 'onb-fee', '800');
      await tapKey(tester, 'onb-back');
      expect(find.text(bn.onbWelcomeTitle), findsOneWidget);
      await tapKey(tester, 'onb-primary');
      expect(textOf(tester, 'onb-subject'), 'রসায়ন');
      expect(textOf(tester, 'onb-fee'), '৮০০');

      // Skip the batch: students then stay unassigned and say so.
      await tapKey(tester, 'onb-skip');
      expect(f.store.batches, isEmpty);
      expect(find.text(bn.onbStudentsNoBatch), findsOneWidget);
      await typeInto(tester, 'onb-student-name', 'নীলা বেগম');
      await typeInto(tester, 'onb-student-phone', '123');
      await tapKey(tester, 'onb-student-add');
      expect(find.text(bn.errPhoneInvalid), findsOneWidget);
      expect(f.students.students, isEmpty);
      expect(textOf(tester, 'onb-student-name'), 'নীলা বেগম');
      await typeInto(tester, 'onb-student-phone', '');
      // "Next" saves the name that is still in the field.
      await tapKey(tester, 'onb-primary');
      expect(f.students.students, hasLength(1));
      expect(f.enrollments.enrollments, isEmpty);
      expect(find.text(bn.onbRemindTitle), findsOneWidget);

      // Finishing without a batch shows no coach mark.
      await tapKey(tester, 'onb-secondary');
      expect(await f.settings.get(SettingKeys.onboardingDone), isTrue);
      expect(find.text('TODAY-PAGE'), findsOneWidget);
      expect(find.text(bn.onbCoachText), findsNothing);
    });

    testWidgets('text typed while a student is being saved is kept for the next one',
        (WidgetTester tester) async {
      final SeededFakes f = emptyFakes();
      final Completer<void> gate = Completer<void>();
      f.students.createGate = gate.future;
      await pumpApp(tester, app(makeRouter()), overrides: overridesOf(f));
      await tester.pumpAndSettle();

      await tapKey(tester, 'onb-primary');
      await tapKey(tester, 'onb-skip');
      await typeInto(tester, 'onb-student-name', 'রহিম');
      await tester.ensureVisible(key('onb-student-add'));
      await tester.tap(key('onb-student-add'));
      await tester.pump();
      // The save has not finished, yet the field is already free again.
      expect(f.students.students, isEmpty);
      expect(textOf(tester, 'onb-student-name'), '');
      await typeInto(tester, 'onb-student-name', 'করিম');

      gate.complete();
      await tester.pumpAndSettle();
      expect(f.students.students.map((Student s) => s.name), <String>['রহিম']);
      expect(textOf(tester, 'onb-student-name'), 'করিম');
    });
  });
}
