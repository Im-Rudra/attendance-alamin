// W3-Places (feedback item 3): several coaching centres. One place: nothing new
// shows anywhere. Two+: Settings › Coaching centres (add / edit / reorder /
// archive rules), the place picker of the batch / tuition and other-income
// forms, the "All places ▾" filter (remembered per device) narrowing the
// lists and totals of Today, Batches, Fees and Students, the per-place
// breakdown of Fees › Collected, and reminders speaking for the batch's place.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/providers/app_prefs_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/features/batches/ui/batch_detail_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batch_form_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batches_screen.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_card.dart';
import 'package:attendance_alamin/features/dues/controllers/reminder_actions.dart';
import 'package:attendance_alamin/features/dues/ui/collection_screen.dart';
import 'package:attendance_alamin/features/dues/ui/fees_screen.dart';
import 'package:attendance_alamin/features/extras/extras_entry.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
import 'package:attendance_alamin/features/home/ui/today_screen.dart';
import 'package:attendance_alamin/features/settings/places/place_filter.dart';
import 'package:attendance_alamin/features/settings/places/place_form.dart';
import 'package:attendance_alamin/features/settings/places/places_section.dart';
import 'package:attendance_alamin/features/settings/ui/more_screen.dart';
import 'package:attendance_alamin/features/settings/widgets/settings_groups.dart';
import 'package:attendance_alamin/features/students/ui/students_screen.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations bn = lookupAppLocalizations(const Locale('bn'));

const String _second = 'place-2';
const String _secondName = 'উত্তরা শাখা';
const String _third = 'place-3';
const String _thirdName = 'শিক্ষার্থীর বাসা';

const ValueKey<String> _chip = ValueKey<String>('place-filter');

EnrollmentTerms _at(EnrollmentTerms t, String placeId) => EnrollmentTerms(
      enrollmentId: t.enrollmentId,
      studentId: t.studentId,
      batchId: t.batchId,
      studentName: t.studentName,
      batchName: t.batchName,
      subjectName: t.subjectName,
      billing: t.billing,
      start: t.start,
      end: t.end,
      batchFees: t.batchFees,
      overrides: t.overrides,
      batchArchived: t.batchArchived,
      studentLeft: t.studentLeft,
      enrollmentEnded: t.enrollmentEnded,
      placeId: placeId,
    );

/// Physics A at the main place, Chem B at "উত্তরা শাখা"; [third] adds a place
/// with no batches. [filter] is the place saved on this device.
Future<SeededFakes> _places({bool third = false, String? filter, Map<String, Object?>? settings}) async {
  final SeededFakes f = seedFakes(encodedSettings: settings);
  f.places.places.add(const Place(id: _second, name: _secondName, sortOrder: 1));
  if (third) f.places.places.add(const Place(id: _third, name: _thirdName, sortOrder: 2));
  f.places.batchPlaces[kBatChemB] = _second;
  await f.batches.setPlace(kBatChemB, _second);
  final List<EnrollmentTerms> terms = f.enrollments.terms;
  for (var i = 0; i < terms.length; i++) {
    if (terms[i].batchId == kBatChemB) terms[i] = _at(terms[i], _second);
  }
  if (filter != null) await f.localMeta.setRaw(LocalMetaKeys.placeFilter, filter);
  return f;
}

Override _prefs(Lang lang) => initialPrefsProvider.overrideWithValue(AppPrefs(
      lang: lang,
      themeMode: ThemeMode.light,
      reducedEffects: true,
      onboardingDone: true,
    ));

List<Override> _o(SeededFakes f, {Lang lang = Lang.bn}) => <Override>[...f.overrides, _prefs(lang)];

Future<void> _settle(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pick(WidgetTester tester, String placeId) async {
  await tester.tap(find.byKey(_chip).first);
  await _settle(tester);
  await tester.tap(find.byKey(ValueKey<String>('place-filter-choice-$placeId')));
  await _settle(tester);
}

void main() {
  // ---- one place: the app looks exactly as before -----------------------------

  group('one place: no place UI', () {
    final Map<String, Widget Function()> screens = <String, Widget Function()>{
      'Today': () => const TodayScreen(),
      'Batches': () => const BatchesScreen(),
      'Fees': () => const FeesScreen(),
      'Collected': () => const CollectionScreen(),
      'Students': () => const StudentsScreen(),
      'Batch detail': () => const BatchDetailScreen(batchId: kBatChemB),
      'Batch form': () => const BatchFormScreen(batchId: kBatPhysA),
    };
    for (final MapEntry<String, Widget Function()> s in screens.entries) {
      for (final TestViewport v in TestViewport.values) {
        testWidgets('${s.key} (${v.name})', (WidgetTester tester) async {
          final SeededFakes f = seedFakes();
          await pumpApp(tester, s.value(), viewport: v, overrides: _o(f));
          await _settle(tester);
          expect(find.byKey(_chip), findsNothing);
          expect(find.byType(PlacePill), findsNothing);
          expect(find.byKey(const Key('batch-form-place')), findsNothing);
          expect(find.byKey(const ValueKey<String>('batch-detail-place')), findsNothing);
          expect(find.byKey(const ValueKey<String>('coll-places-breakdown')), findsNothing);
          expectNoException(tester, 'one place ${s.key}');
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }

    testWidgets('other income asks no place', (WidgetTester tester) async {
      await pumpApp(tester, _incomeHost(), overrides: _o(seedFakes()));
      await _openIncome(tester);
      expect(find.byKey(const ValueKey<String>('income-label')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('income-place')), findsNothing);
    });

    testWidgets('Settings keeps the centre fields, plus one "add another" row', (WidgetTester tester) async {
      await pumpApp(tester, const MoreScreen(initialGroup: SettingsGroup.center),
          viewport: TestViewport.desktop, overrides: _o(seedFakes()));
      await _settle(tester);
      expect(find.byKey(const Key('more-center-name')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('place-add')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('place-row-$kDefaultPlaceId')), findsNothing);
    });

    test('a saved filter is ignored with one place', () async {
      final SeededFakes f = seedFakes();
      await f.localMeta.setRaw(LocalMetaKeys.placeFilter, kDefaultPlaceId);
      final ProviderContainer c = makeContainer(overrides: f.overrides);
      c.listen<String?>(placeFilterProvider, (_, __) {});
      await settle();
      expect(c.read(placeFilterProvider), isNull);
    });
  });

  // ---- Settings › Coaching centres ----------------------------------------------

  group('Settings › Coaching centres', () {
    Future<void> openCentres(WidgetTester tester, SeededFakes f) async {
      tester.view.physicalSize = const Size(1280, 1200);
      await pumpApp(tester, const MoreScreen(initialGroup: SettingsGroup.center),
          viewport: TestViewport.desktop, overrides: _o(f));
      tester.view.physicalSize = const Size(1280, 1200);
      await _settle(tester);
    }

    testWidgets('add a centre: name required and unique, then the list shows both', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await openCentres(tester, f);
      await tester.tap(find.byKey(const ValueKey<String>('place-add')));
      await _settle(tester);
      final Finder save = find.byKey(const ValueKey<String>('place-form-save'));
      expect(save, findsOneWidget);
      expect(tester.widget<BhorButton>(save).onPressed, isNull);
      expect(find.text(bn.placeReasonName), findsOneWidget);

      // The main centre's name is taken (any case / spacing).
      await tester.enterText(find.byKey(const ValueKey<String>('place-form-name')), '  আলামিন   কোচিং ');
      await _settle(tester, 3);
      expect(find.text(bn.placeNameTaken), findsWidgets);
      expect(tester.widget<BhorButton>(save).onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey<String>('place-form-name')), _secondName);
      await tester.enterText(find.byKey(const ValueKey<String>('place-form-phone')), '0171');
      await _settle(tester, 3);
      expect(tester.widget<BhorButton>(save).onPressed, isNull, reason: 'a bad phone blocks Save');
      await tester.enterText(find.byKey(const ValueKey<String>('place-form-phone')), '01811223344');
      await tester.enterText(find.byKey(const ValueKey<String>('place-form-address')), 'সেক্টর ৭, উত্তরা');
      await _settle(tester, 3);
      expect(tester.widget<BhorButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await _settle(tester, 20);

      expect(f.places.places.length, 2);
      final Place added = f.places.places.last;
      expect(added.name, _secondName);
      expect(added.phone, '01811223344');
      expect(added.address, 'সেক্টর ৭, উত্তরা');
      // The list replaced the single-centre fields; the main centre is tagged.
      expect(find.byKey(const Key('more-center-name')), findsNothing);
      expect(find.byKey(const ValueKey<String>('place-row-$kDefaultPlaceId')), findsOneWidget);
      expect(find.byKey(ValueKey<String>('place-row-${added.id}')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('place-main-tag')), findsOneWidget);
      expectNoException(tester, 'after add');
    });

    testWidgets('edit a centre from its row', (WidgetTester tester) async {
      final SeededFakes f = await _places();
      await openCentres(tester, f);
      await tester.tap(find.text(_secondName));
      await _settle(tester);
      final Finder name = find.byKey(const ValueKey<String>('place-form-name'));
      expect(tester.widget<BhorTextField>(name).controller!.text, _secondName);
      expect(find.text(bn.placeReasonNoChange), findsOneWidget);
      await tester.enterText(name, 'উত্তরা শাখা ২');
      await _settle(tester, 3);
      await tester.tap(find.byKey(const ValueKey<String>('place-form-save')));
      await _settle(tester, 20);
      expect(f.places.places.firstWhere((Place p) => p.id == _second).name, 'উত্তরা শাখা ২');
    });

    testWidgets('the main centre stays first and is never archived', (WidgetTester tester) async {
      final SeededFakes f = await _places(third: true);
      await openCentres(tester, f);
      await tester.tap(find.byKey(const ValueKey<String>('place-menu-$kDefaultPlaceId')));
      await _settle(tester);
      expect(find.byKey(const ValueKey<String>('place-edit-$kDefaultPlaceId')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('place-archive-$kDefaultPlaceId')), findsNothing);
      expect(find.byKey(const ValueKey<String>('place-up-$kDefaultPlaceId')), findsNothing);
      expect(find.byKey(const ValueKey<String>('place-down-$kDefaultPlaceId')), findsNothing);
    });

    testWidgets('reorder: move a centre up', (WidgetTester tester) async {
      final SeededFakes f = await _places(third: true);
      await openCentres(tester, f);
      await tester.tap(find.byKey(const ValueKey<String>('place-menu-$_second')));
      await _settle(tester);
      // The first non-main place can't go above the main one.
      expect(find.byKey(const ValueKey<String>('place-up-$_second')), findsNothing);
      await tester.tapAt(const Offset(4, 4));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey<String>('place-menu-$_third')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('place-up-$_third')));
      await _settle(tester);
      int order(String id) => f.places.places.firstWhere((Place p) => p.id == id).sortOrder;
      expect(order(kDefaultPlaceId), lessThan(order(_third)));
      expect(order(_third), lessThan(order(_second)));
      final double y3 = tester.getTopLeft(find.byKey(const ValueKey<String>('place-row-$_third'))).dy;
      final double y2 = tester.getTopLeft(find.byKey(const ValueKey<String>('place-row-$_second'))).dy;
      expect(y3, lessThan(y2));
    });

    testWidgets('archive: blocked with open batches, confirmed without, then restored', (WidgetTester tester) async {
      final SeededFakes f = await _places(third: true);
      await openCentres(tester, f);
      bool archived(String id) => f.places.places.firstWhere((Place p) => p.id == id).archived;

      // Chem B still meets at the second centre.
      await tester.tap(find.byKey(const ValueKey<String>('place-menu-$_second')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('place-archive-$_second')));
      await _settle(tester);
      expect(find.text(bn.placeArchiveBlocked(_secondName)), findsOneWidget);
      expect(archived(_second), isFalse);

      // The third has no batches: asks first, then archives.
      await tester.tap(find.byKey(const ValueKey<String>('place-menu-$_third')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('place-archive-$_third')));
      await _settle(tester);
      expect(find.text(bn.placeArchiveTitle(_thirdName)), findsOneWidget);
      await tester.tap(find.widgetWithText(BhorButton, bn.placeArchive));
      await _settle(tester);
      expect(archived(_third), isTrue);
      expect(find.byKey(const ValueKey<String>('place-archived-$_third')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('place-row-$_third')), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('place-restore-$_third')));
      await _settle(tester);
      expect(archived(_third), isFalse);
      expect(find.byKey(const ValueKey<String>('place-row-$_third')), findsOneWidget);
    });

    test('archive rules', () {
      const Place main = Place(id: kDefaultPlaceId, name: 'a', sortOrder: 0);
      const Place other = Place(id: _second, name: 'b', sortOrder: 1);
      expect(placeArchiveBlock(main, activeCount: 3, openBatches: 0), PlaceArchiveBlock.mainPlace);
      expect(placeArchiveBlock(other, activeCount: 1, openBatches: 0), PlaceArchiveBlock.lastPlace);
      expect(placeArchiveBlock(other, activeCount: 2, openBatches: 1), PlaceArchiveBlock.openBatches);
      expect(placeArchiveBlock(other, activeCount: 2, openBatches: 0), isNull);
      expect(isPlaceNameTaken(<Place>[main, other], ' B ', excludeId: kDefaultPlaceId), isTrue);
      expect(isPlaceNameTaken(<Place>[main, other], 'b', excludeId: _second), isFalse);
    });
  });

  // ---- pickers --------------------------------------------------------------------

  group('place pickers', () {
    testWidgets('batch form: change the place of a batch', (WidgetTester tester) async {
      final SeededFakes f = await _places();
      await pumpApp(tester, const BatchFormScreen(batchId: kBatPhysA), overrides: _o(f));
      await _settle(tester);
      final Finder select = find.byKey(const Key('batch-form-place'));
      expect(select, findsOneWidget);
      final BhorSelect<String> s = tester.widget<BhorSelect<String>>(select);
      expect(s.value, kDefaultPlaceId);
      expect(s.searchable, isTrue);
      expect(s.options.map((BhorOption<String> o) => o.value), <String>[kDefaultPlaceId, _second]);
      s.onChanged!(_second);
      await _settle(tester, 3);
      await tester.tap(find.widgetWithText(BhorButton, bn.commonSave));
      await _settle(tester, 12);
      expect(f.store.batches.firstWhere((Batch b) => b.id == kBatPhysA).placeId, _second);
    });

    testWidgets('a new batch starts at the filtered place', (WidgetTester tester) async {
      final SeededFakes f = await _places(filter: _second);
      await pumpApp(tester, const BatchFormScreen(), overrides: _o(f));
      await _settle(tester);
      expect(tester.widget<BhorSelect<String>>(find.byKey(const Key('batch-form-place'))).value, _second);
    });

    testWidgets('batch detail names its place', (WidgetTester tester) async {
      final SeededFakes f = await _places();
      await pumpApp(tester, const BatchDetailScreen(batchId: kBatChemB), overrides: _o(f));
      await _settle(tester);
      expect(find.byKey(const ValueKey<String>('batch-detail-place')), findsOneWidget);
      expect(find.text(_secondName), findsOneWidget);
    });

    testWidgets('other income: General by default, or a place', (WidgetTester tester) async {
      final SeededFakes f = await _places();
      await pumpApp(tester, _incomeHost(), overrides: _o(f));
      await _openIncome(tester);
      final Finder select = find.byKey(const ValueKey<String>('income-place'));
      expect(select, findsOneWidget);
      expect(tester.widget<BhorSelect<String>>(select).value, '');
      tester.widget<BhorSelect<String>>(select).onChanged!(_second);
      await tester.enterText(find.byKey(const ValueKey<String>('income-label')), 'পরীক্ষার ফি');
      await tester.enterText(find.byKey(const ValueKey<String>('income-amount')), '৩০০');
      await _settle(tester, 3);
      await tester.ensureVisible(find.byKey(const ValueKey<String>('income-save')));
      await tester.tap(find.byKey(const ValueKey<String>('income-save')));
      await _settle(tester, 20);
      expect(f.otherIncome.items.single.placeId, _second);
    });
  });

  // ---- filter + totals -------------------------------------------------------------

  group('"All places" filter', () {
    testWidgets('Fees: the chip narrows the dues list and is remembered on the device',
        (WidgetTester tester) async {
      final SeededFakes f = await _places();
      await pumpApp(tester, const FeesScreen(), viewport: TestViewport.desktop, overrides: _o(f));
      await _settle(tester);
      expect(find.byKey(_chip), findsOneWidget);
      expect(find.text(bn.placeFilterAll), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('dues-row-$kStuRahim')), findsOneWidget);

      await _pick(tester, _second);
      expect(f.localMeta.values[LocalMetaKeys.placeFilter], _second);
      expect(find.byKey(const ValueKey<String>('dues-row-$kStuRahim')), findsNothing);
      expect(find.byKey(const ValueKey<String>('dues-row-$kStuSara')), findsOneWidget);
      expectNoException(tester, 'filtered fees');

      // Another screen on the same device opens with the same place.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(tester, const BatchesScreen(), overrides: _o(f));
      await _settle(tester);
      expect(find.text(_secondName), findsOneWidget);
      expect(tester.widgetList<BatchCard>(find.byType(BatchCard)).map((BatchCard c) => c.data.batch.id),
          <String>[kBatChemB]);

      // Back to all places.
      await _pick(tester, '');
      expect(f.localMeta.values.containsKey(LocalMetaKeys.placeFilter), isFalse);
      expect(find.byType(BatchCard), findsNWidgets(2));
    });

    testWidgets('Students: only students of the place', (WidgetTester tester) async {
      final SeededFakes f = await _places(filter: kDefaultPlaceId);
      await pumpApp(tester, const StudentsScreen(), overrides: _o(f));
      await _settle(tester);
      expect(find.byKey(_chip), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stu-row-$kStuRahim')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stu-row-$kStuKarim')), findsNothing);
      expect(find.byKey(const ValueKey<String>('stu-row-$kStuSara')), findsOneWidget);
    });

    test('Today: the day plan, dues and collection follow the place', () async {
      final SeededFakes f = await _places(filter: _second);
      final ProviderContainer c = makeContainer(overrides: f.overrides);
      c.listen<String?>(placeFilterProvider, (_, __) {});
      await settle();
      expect(c.read(placeFilterProvider), _second);
      // Saturday: only Physics A meets, at the main place.
      final DayPlan plan = await readData(c, todayDayPlanProvider(kToday));
      expect(plan.classes, isEmpty);
      final DuesReport report = await readData(c, placeDuesReportProvider);
      for (final StudentDues s in <StudentDues>[...report.active, ...report.inactive]) {
        for (final EnrollmentDues e in s.enrollments) {
          expect(e.terms.batchId, kBatChemB);
        }
      }

      await f.localMeta.setRaw(LocalMetaKeys.placeFilter, kDefaultPlaceId);
      await settle();
      final DayPlan home = await readData(c, todayDayPlanProvider(kToday));
      expect(home.classes.map((DayClass x) => x.batch.id), contains(kBatPhysA));
    });

    testWidgets('Collected: per-place totals with "All places"; a tap narrows to one',
        (WidgetTester tester) async {
      final SeededFakes f = await _places();
      tester.view.physicalSize = const Size(1280, 1100);
      await pumpApp(tester, const CollectionScreen(), viewport: TestViewport.desktop, overrides: _o(f));
      tester.view.physicalSize = const Size(1280, 1100);
      await _settle(tester);
      expect(find.byKey(const ValueKey<String>('coll-places-breakdown')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('coll-place-$kDefaultPlaceId')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('coll-place-$_second')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('coll-place-$_second')));
      await _settle(tester);
      expect(f.localMeta.values[LocalMetaKeys.placeFilter], _second);
      expect(find.byKey(const ValueKey<String>('coll-places-breakdown')), findsNothing);
      expectNoException(tester, 'collected filtered');
    });
  });

  // ---- reminders ----------------------------------------------------------------

  group('reminders use the place', () {
    test('a due at another centre carries that centre\'s name', () async {
      final SeededFakes f = await _places(settings: <String, Object?>{'center_name': 'আলো কোচিং'});
      final ProviderContainer c = makeContainer(overrides: f.overrides);
      final String? sara = await composeReminder(c, lang: Lang.bn, studentId: kStuSara, centerFallback: 'x');
      expect(sara, contains(_secondName));
      expect(sara, isNot(contains('আলো কোচিং')));
      final String? rahim = await composeReminder(c, lang: Lang.bn, studentId: kStuRahim, centerFallback: 'x');
      expect(rahim, contains('আলো কোচিং'));
    });

    test('the place filter keeps only that place\'s dues', () async {
      final SeededFakes f = await _places();
      final ProviderContainer c = makeContainer(overrides: f.overrides);
      expect(
        await composeReminder(c, lang: Lang.bn, studentId: kStuSara, centerFallback: 'x', placeId: kDefaultPlaceId),
        isNull,
      );
      expect(
        await composeReminder(c, lang: Lang.bn, studentId: kStuSara, centerFallback: 'x', placeId: _second),
        isNotNull,
      );
    });
  });

  // ---- no clipping ----------------------------------------------------------------

  group('two places at 1214 and 910, bn and en', () {
    for (final double w in <double>[1214, 910]) {
      for (final Lang lang in Lang.values) {
        for (final MapEntry<String, Widget Function()> s in <String, Widget Function()>{
          'Today': () => const TodayScreen(),
          'Batches': () => const BatchesScreen(),
          'Fees': () => const FeesScreen(),
          'Collected': () => const CollectionScreen(),
          'Students': () => const StudentsScreen(),
          'Centres': () => const MoreScreen(initialGroup: SettingsGroup.center),
        }.entries) {
          testWidgets('${s.key} ${w.toInt()} ${lang.code}', (WidgetTester tester) async {
            final SeededFakes f = await _places(third: true, filter: lang == Lang.en ? _second : null);
            await pumpApp(tester, s.value(), lang: lang, viewport: TestViewport.desktop, overrides: _o(f, lang: lang));
            tester.view.physicalSize = Size(w, 800);
            await _settle(tester);
            expectNoException(tester, '${s.key} at $w ${lang.code}');
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }
  });
}

// ---- other income host ---------------------------------------------------------

Widget _incomeHost() => BhorScaffold(
      body: Center(
        child: Builder(
          builder: (BuildContext context) => BhorButton(
            key: const ValueKey<String>('open-income'),
            onPressed: () => showOtherIncomeSheet(context),
            label: 'open',
          ),
        ),
      ),
    );

Future<void> _openIncome(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('open-income')));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
