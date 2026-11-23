// W3-Tuition (item 1): a private tuition is made with a unique name / ID, an
// optional subject, weekly slots and students added right in the form; the
// Batches page groups tuitions after the subjects with a "Private" tag; the
// student forms offer "Enrol in: Not yet · Batch · Private tuition"; and
// every label of a subject-less tuition reads as its name alone.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_editor.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/ui/batch_form_screen.dart';
import 'package:attendance_alamin/features/batches/ui/batches_screen.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/students/ui/student_form_screen.dart';
import 'package:attendance_alamin/features/students/widgets/enroll_sheet.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations bn = lookupAppLocalizations(const Locale('bn'));
final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

const String kBatRafi = 'bat-tuition-rafi';
const String kRafiName = 'রাফি (বাসা)';

/// Stand-in for the slot editor: one tap reports a Thursday 18:00 slot.
Widget _slotStub(
  BuildContext context, {
  required List<SlotDraft> initial,
  required ValueChanged<List<SlotDraft>> onChanged,
  String? batchId,
  ValueChanged<SlotCheckResult>? onCheck,
}) =>
    BhorButton(
      key: const Key('slot-stub'),
      label: 'slot',
      onPressed: () {
        onChanged(const <SlotDraft>[SlotDraft(weekday: 4, startMin: 1080, endMin: 1140)]);
        onCheck?.call(const SlotCheckResult());
      },
    );

List<Override> _withStub(SeededFakes f) => <Override>[
      ...f.overrides,
      batchSlotEditorBuilderProvider.overrideWithValue(_slotStub),
    ];

/// The fakes plus a subject-less tuition with a Saturday 19:00 class.
SeededFakes _withTuition({String id = kBatRafi, String name = kRafiName, int weekday = 6}) {
  final SeededFakes f = seedFakes();
  _addTuition(f, id: id, name: name, weekday: weekday);
  return f;
}

void _addTuition(SeededFakes f, {required String id, required String name, int weekday = 6}) {
  f.store.batches.add(Batch(
    id: id,
    subjectId: kNoSubjectId,
    name: name,
    billingType: BillingType.prepaid,
    createdOn: const LocalDate(2026, 1, 1),
    sortOrder: f.store.batches.length,
    kind: BatchKind.tuition,
  ));
  f.store.slots.add(Slot(id: 'slot-$id', batchId: id, weekday: weekday, startMin: 19 * 60, endMin: 20 * 60));
  f.store.fees[id] = <FeePeriod>[const FeePeriod(effective: YearMonth(2026, 1), amount: 600)];
}

Future<void> _tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 1800);
  await tester.pump();
}

Future<void> _settle(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _save(WidgetTester tester) async {
  final Finder save = find.widgetWithText(BhorButton, bn.commonSave);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await _settle(tester, 10);
}

List<Enrollment> _open(SeededFakes f, String studentId, String batchId) => <Enrollment>[
      for (final Enrollment e in f.enrollments.enrollments)
        if (e.studentId == studentId && e.batchId == batchId && e.endDate == null) e,
    ];

class _Launcher extends StatelessWidget {
  const _Launcher(this.onTap);

  final Future<void> Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) =>
      Center(child: BhorButton(label: 'open', onPressed: () => onTap(context)));
}

void main() {
  group('create a private tuition', () {
    testWidgets('without a subject: hidden subject row, tuition kind, name required', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(tester, const BatchFormScreen(kind: BatchKind.tuition), overrides: _withStub(f));
      await _tall(tester);
      await _settle(tester);
      final int subjectsBefore = f.store.subjects.length;

      // No default name: the teacher gives it one.
      expect(find.text(bn.batchTuitionNameLabel), findsOneWidget);
      expect(find.text(bn.batchSubjectOptional), findsOneWidget);
      expect(find.text(bn.batchReasonTuitionName), findsOneWidget);

      await tester.enterText(find.byKey(const Key('batch-form-name')), kRafiName);
      await tester.pump();
      expect(find.text(bn.batchReasonSubject), findsNothing, reason: 'the subject is optional');
      expect(find.text(bn.batchReasonSlots), findsOneWidget, reason: 'weekly days are required');
      await tester.tap(find.byKey(const Key('slot-stub')));
      await tester.pump();
      await _save(tester);

      final Batch created = f.store.batches.last;
      expect(created.name, kRafiName);
      expect(created.kind, BatchKind.tuition);
      expect(created.isTuition, isTrue);
      expect(created.subjectId, kNoSubjectId);
      expect(created.hasSubject, isFalse);
      expect(f.store.subjects.length, subjectsBefore, reason: 'no visible subject is made');
      expect(f.store.fees[created.id]!.single.amount, 0, reason: 'a blank fee is "no fee yet"');
      expect(f.store.slots.where((Slot s) => s.batchId == created.id).single.weekday, 4);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('with a subject: the subject is made and used', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(tester, const BatchFormScreen(kind: BatchKind.tuition), overrides: _withStub(f));
      await _tall(tester);
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('batch-form-name')), 'মিতু');
      await tester.enterText(find.byKey(const Key('batch-form-subject')), 'গণিত');
      await tester.enterText(find.byKey(const Key('batch-form-fee')), '১২০০');
      await tester.tap(find.byKey(const Key('slot-stub')));
      await tester.pump();
      await _save(tester);

      final Batch created = f.store.batches.last;
      expect(created.kind, BatchKind.tuition);
      expect(f.store.subjects.last.name, 'গণিত');
      expect(created.subjectId, f.store.subjects.last.id);
      expect(f.store.fees[created.id]!.single.amount, 1200);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a name another tuition has is an inline error and blocks Save', (WidgetTester tester) async {
      final SeededFakes f = _withTuition();
      await pumpApp(tester, const BatchFormScreen(kind: BatchKind.tuition), overrides: _withStub(f));
      await _tall(tester);
      await _settle(tester);
      final int before = f.store.batches.length;

      // Case and spaces do not make a name different.
      await tester.enterText(find.byKey(const Key('batch-form-name')), '  রাফি   (বাসা) ');
      await tester.tap(find.byKey(const Key('slot-stub')));
      await tester.pump();
      expect(find.text(bn.batchTuitionNameTaken), findsOneWidget);
      expect(find.text(bn.batchReasonNameTaken), findsOneWidget);
      await _save(tester);
      expect(f.store.batches.length, before);

      // A batch's name is a different kind: no clash.
      await tester.enterText(find.byKey(const Key('batch-form-name')), kBatches[0].name);
      await tester.pump();
      expect(find.text(bn.batchTuitionNameTaken), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('students are picked from a searchable list and added by name + guardian phone',
        (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(tester, const BatchFormScreen(kind: BatchKind.tuition), overrides: _withStub(f));
      await _tall(tester);
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('batch-form-name')), 'দুই ভাইবোন');
      await tester.tap(find.byKey(const Key('slot-stub')));
      await tester.pump();

      // An existing student, found by typing.
      final Finder pick = find.byKey(const ValueKey<String>('tuition-pick-student'));
      await tester.ensureVisible(pick);
      await tester.tap(pick);
      await _settle(tester);
      final Finder search = find.byKey(const ValueKey<String>('bhor-select-search'));
      expect(search, findsOneWidget);
      await tester.enterText(search, 'করিম');
      await _settle(tester);
      expect(find.textContaining('রহিম উদ্দিন'), findsNothing);
      await tester.tap(find.textContaining('করিম হোসেন').last);
      await _settle(tester);
      expect(find.byKey(const ValueKey<String>('tuition-picked-$kStuKarim')), findsOneWidget);

      // A new student.
      final Finder add = find.byKey(const ValueKey<String>('tuition-add-new-student'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await _settle(tester);
      expect(find.text(bn.batchReasonStudentName), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey<String>('tuition-new-name-0')), 'তানিয়া');
      await tester.enterText(find.byKey(const ValueKey<String>('tuition-new-phone-0')), '0171');
      await tester.pump();
      expect(find.text(bn.batchReasonStudentPhone), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey<String>('tuition-new-phone-0')), '01712345678');
      await tester.pump();
      expect(find.text(bn.batchReasonStudentPhone), findsNothing);
      await _save(tester);

      final Batch created = f.store.batches.last;
      expect(created.isTuition, isTrue);
      expect(_open(f, kStuKarim, created.id).single.joinDate, kToday);
      final Student tania = f.students.students.firstWhere((Student s) => s.name == 'তানিয়া');
      expect(tania.guardianPhone, '01712345678');
      expect(_open(f, tania.id, created.id), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('editing a tuition: "Edit private tuition", no blank subject field', (WidgetTester tester) async {
      final SeededFakes f = _withTuition();
      await pumpApp(tester, const BatchFormScreen(batchId: kBatRafi), overrides: _withStub(f));
      await _tall(tester);
      await _settle(tester);
      expect(find.text(bn.batchEditTuitionTitle), findsOneWidget);
      expect(find.byKey(const Key('batch-form-subject')), findsNothing);
      expect(find.text(bn.batchTuitionNameLabel), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Batches page', () {
    testWidgets('a "Private tuitions" group after the subjects, cards tagged Private', (WidgetTester tester) async {
      final SeededFakes f = _withTuition();
      await pumpApp(tester, const BatchesScreen(), overrides: f.overrides);
      await _settle(tester);
      expect(find.text(bn.batchGroupTuitions), findsOneWidget);
      // Name only: no " · " in front of a subject-less tuition.
      expect(find.text(kRafiName), findsWidgets);
      expect(find.byType(PrivateTag), findsOneWidget);
      final double physics = tester.getTopLeft(find.text(kSubjects[0].name)).dy;
      final double tuitions = tester.getTopLeft(find.text(bn.batchGroupTuitions)).dy;
      expect(tuitions, greaterThan(physics));
    });

    testWidgets('a tuition with a subject still sits in the tuitions group', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      f.store.batches.add(Batch(
        id: 'bat-t2',
        subjectId: kSubPhysics,
        name: 'নিলয়',
        billingType: BillingType.prepaid,
        createdOn: const LocalDate(2026, 1, 1),
        sortOrder: 5,
        kind: BatchKind.tuition,
      ));
      await pumpApp(tester, const BatchesScreen(), overrides: f.overrides);
      await _settle(tester);
      expect(find.text(bn.batchGroupTuitions), findsOneWidget);
      expect(find.text('${kSubjects[0].name} · নিলয়'), findsOneWidget);
    });

    testWidgets('desktop header: New… offers New batch and New private tuition', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(tester, const BatchesScreen(), viewport: TestViewport.desktop, overrides: _withStub(f));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('batches-new-menu')));
      await _settle(tester);
      expect(find.text(bn.batchNew), findsWidgets);
      await tester.tap(find.text(bn.batchNewTuition));
      await _settle(tester, 10);
      expect(find.text(bn.batchNewTuition), findsWidgets);
      expect(find.text(bn.batchTuitionNameLabel), findsOneWidget);
    });

    testWidgets('finishing a tuition says "Finish tuition"', (WidgetTester tester) async {
      final SeededFakes f = _withTuition();
      await pumpApp(tester, const BatchesScreen(), viewport: TestViewport.desktop, overrides: f.overrides);
      await _settle(tester);
      final Finder card = find.ancestor(of: find.byType(PrivateTag), matching: find.byType(GestureDetector)).first;
      await tester.tapAt(tester.getCenter(card), buttons: kSecondaryButton);
      await _settle(tester);
      expect(find.text(bn.batchMenuArchiveTuition), findsOneWidget);
      expect(find.text(bn.batchMenuArchive), findsNothing);
    });
  });

  group('enrol in: Not yet · Batch · Private tuition', () {
    testWidgets('add-student form: the tuition choice lists tuitions and enrols in one', (WidgetTester tester) async {
      final SeededFakes f = _withTuition();
      await pumpApp(tester, const StudentFormScreen(), overrides: f.overrides);
      tester.view.physicalSize = const Size(360, 1800);
      await _settle(tester);

      expect(find.text(bn.stuEnrollIn), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stu-form-batch')), findsNothing, reason: 'Not yet by default');

      await tester.tap(find.byKey(const ValueKey<String>('stu-enroll-kind-tuition')));
      await _settle(tester);
      final Finder select = find.byKey(const ValueKey<String>('stu-form-batch'));
      expect(select, findsOneWidget);
      expect(tester.widget<BhorSelect<String>>(select).options.map((BhorOption<String> o) => o.label),
          <String>[kRafiName]);

      await tester.tap(find.byKey(const ValueKey<String>('stu-enroll-kind-batch')));
      await _settle(tester);
      expect(tester.widget<BhorSelect<String>>(select).options.map((BhorOption<String> o) => o.value),
          <String>[kBatPhysA, kBatChemB]);

      await tester.tap(find.byKey(const ValueKey<String>('stu-enroll-kind-tuition')));
      await _settle(tester);
      tester.widget<BhorSelect<String>>(select).onChanged!(kBatRafi);
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey<String>('stu-field-name')), 'তানিয়া');
      await tester.pump();
      final Finder save = find.widgetWithText(BhorButton, bn.stuSave);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await _settle(tester, 10);
      final Student tania = f.students.students.firstWhere((Student s) => s.name == 'তানিয়া');
      expect(_open(f, tania.id, kBatRafi), hasLength(1));
    });

    testWidgets('no tuitions yet: says so', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(tester, const StudentFormScreen(), overrides: f.overrides);
      tester.view.physicalSize = const Size(360, 1800);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey<String>('stu-enroll-kind-tuition')));
      await _settle(tester);
      expect(find.text(bn.stuNoTuitionsYet), findsOneWidget);
    });

    testWidgets('enrol panel: Batch · Private tuition chips, then the tuition list', (WidgetTester tester) async {
      final SeededFakes f = _withTuition();
      bool? done;
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          done = await openEnrollSheet(c, kStuRahim);
        }),
        overrides: f.overrides,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(kRafiName), findsNothing, reason: 'batches first');
      expect(find.text('কেমিস্ট্রি বি'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('stu-enroll-kind-tuition')));
      await tester.pumpAndSettle();
      expect(find.text('কেমিস্ট্রি বি'), findsNothing);
      await tester.tap(find.text(kRafiName));
      await tester.pumpAndSettle();
      final Finder confirm = find.byKey(const ValueKey<String>('stu-enroll-confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(_open(f, kStuRahim, kBatRafi), hasLength(1));
    });

    testWidgets('enrol panel: a long list gets a filter field', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      for (int i = 1; i <= 7; i++) {
        _addTuition(f, id: 'bat-t$i', name: 'Tuition $i', weekday: 5);
      }
      _addTuition(f, id: 'bat-mitu', name: 'Mitu home', weekday: 5);
      await pumpApp(
        tester,
        _Launcher((BuildContext c) async {
          await openEnrollSheet(c, kStuRahim);
        }),
        overrides: f.overrides,
      );
      tester.view.physicalSize = const Size(360, 2400);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('stu-enroll-kind-tuition')));
      await tester.pumpAndSettle();
      final Finder search = find.byKey(const ValueKey<String>('stu-enroll-search'));
      expect(search, findsOneWidget);
      await tester.enterText(search, 'mitu');
      await tester.pumpAndSettle();
      expect(find.text('Mitu home'), findsOneWidget);
      expect(find.text('Tuition 3'), findsNothing);
    });
  });

  group('labels of a subject-less tuition', () {
    test('batch label, roll call title: the name alone', () {
      expect(batchLabel(bn, '', kRafiName), kRafiName);
      expect(batchLabel(bn, '  ', kRafiName), kRafiName);
      expect(batchLabel(en, 'Maths', 'Rafi'), en.clsClassLabel('Maths', 'Rafi'));
      final Batch tuition = _withTuition().store.batches.last;
      final RollTarget t = RollTarget(
        batch: tuition,
        subjectName: '',
        date: kToday,
        startMin: 19 * 60,
        endMin: 20 * 60,
      );
      expect(rollTitleOf(bn, t), kRafiName);
      expect(rollTitleOf(en, t), kRafiName);
    });

    test('the batch form title follows the kind', () {
      expect(batchFormTitle(bn, editing: false, kind: BatchKind.tuition), bn.batchNewTuition);
      expect(batchFormTitle(bn, editing: true, kind: BatchKind.tuition), bn.batchEditTuitionTitle);
      expect(batchFormTitle(bn, editing: false, kind: BatchKind.batch), bn.shellTitleBatchNew);
    });

    test('no-subject strings never start with a separator', () {
      for (final AppLocalizations l in <AppLocalizations>[bn, en]) {
        const AppFormat fmt = AppFormat(Lang.bn);
        expect(l.clsBlockLabelNoSubject(kRafiName, fmt.timeRange(1140, 1200)).startsWith(kRafiName), isTrue);
        expect(l.schedClashLineNoSubject(kRafiName, 'x', 'y').startsWith(kRafiName), isTrue);
        expect(l.clsClashLineNoSubject(kRafiName, 'x', 'y').startsWith(kRafiName), isTrue);
        expect(l.batchClashLineNoSubject(kRafiName, 'x', 'y').startsWith(kRafiName), isTrue);
        expect(l.clsCancelMessageNoSubject('w', kRafiName, 't', '').contains(kRafiName), isTrue);
      }
    });
  });
}
