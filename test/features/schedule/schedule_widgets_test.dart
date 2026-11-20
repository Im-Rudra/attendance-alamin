import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/widgets/conflict_card.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/schedule/schedule_entry.dart';
import 'package:attendance_alamin/features/schedule/ui/slot_editor_screen.dart';
import 'package:attendance_alamin/features/schedule/widgets/effective_from_sheet.dart';
import 'package:attendance_alamin/features/schedule/widgets/reminder_lead_sheet.dart';
import 'package:attendance_alamin/features/schedule/widgets/time_picker_sheet.dart';

import '../../helpers/fakes/fake_structure_repos.dart';
import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

/// A slot starting 10:30 clashes with Chem B's class (10:00-11:00) on its own
/// weekday; the nearest free times are 9:00 and 11:00.
SlotCheckResult clashOn(int weekday) => SlotCheckResult(
      groups: <ClashGroup>[
        ClashGroup(
          batchId: kBatChemB,
          startMin: 600,
          endMin: 660,
          everyWeek: true,
          weekday: weekday,
          existingKind: OccurrenceKind.regular,
          count: 1,
        ),
      ],
      suggestion: const FreeSuggestion(
        durationMin: 60,
        earlierStartMin: 540,
        laterStartMin: 660,
        preferredStartMin: 630,
      ),
    );

class _ClashRepo extends FakeScheduleRepository {
  _ClashRepo(FakeStructureStore store) : super(store);

  @override
  Future<SlotCheckResult> checkSlots(String? batchId, List<SlotDraft> slots,
      {required LocalDate from}) async {
    for (final SlotDraft s in slots) {
      if (s.startMin == 630) return clashOn(s.weekday);
    }
    return const SlotCheckResult();
  }
}

List<Override> _overrides(SeededFakes f) => <Override>[
      ...f.overrides,
      scheduleRepositoryProvider.overrideWithValue(_ClashRepo(f.store)),
    ];

FilledButton _saveButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'সংরক্ষণ').first);

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens [open] from a button and records what it returns.
class _Launcher extends StatefulWidget {
  const _Launcher(this.open, this.onResult);

  final Future<Object?> Function(BuildContext) open;
  final ValueChanged<Object?> onResult;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton(
          onPressed: () async => widget.onResult(await widget.open(context)),
          child: const Text('open'),
        ),
      );
}

void main() {
  group('clash card (scenarios 17, 18, 20)', () {
    testWidgets('names the clashing class and one tap on a suggestion fixes it',
        (WidgetTester tester) async {
      final f = seedFakes();
      List<SlotDraft>? last;
      SlotCheckResult? lastCheck;
      await pumpApp(
        tester,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SlotEditorField(
            initial: const <SlotDraft>[
              SlotDraft(weekday: 7, startMin: 630, endMin: 690),
            ],
            onChanged: (List<SlotDraft> v) => last = v,
            onCheck: (SlotCheckResult r) => lastCheck = r,
          ),
        ),
        overrides: _overrides(f),
      );
      await tester.pumpAndSettle();

      expect(find.text('সময় মিলছে না'), findsOneWidget);
      expect(
        find.text('রসায়ন · কেমিস্ট্রি বি · প্রতি রবিবার · সকাল ১০:০০–১১:০০'),
        findsOneWidget,
      );
      expect(find.text('সকাল ১১:০০–দুপুর ১২:০০ নিন'), findsOneWidget);
      expect(find.text('আগে: সকাল ৯:০০–১০:০০'), findsOneWidget);
      expect(lastCheck!.ok, isFalse);

      await _tapText(tester, 'সকাল ১১:০০–দুপুর ১২:০০ নিন');

      expect(find.text('সময় মিলছে না'), findsNothing);
      expect(last!.single.startMin, 660);
      expect(last!.single.endMin, 720);
      expect(lastCheck!.ok, isTrue);
    });

    testWidgets('the earlier suggestion is the secondary fix',
        (WidgetTester tester) async {
      final f = seedFakes();
      List<SlotDraft>? last;
      await pumpApp(
        tester,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SlotEditorField(
            initial: const <SlotDraft>[
              SlotDraft(weekday: 7, startMin: 630, endMin: 690),
            ],
            onChanged: (List<SlotDraft> v) => last = v,
          ),
        ),
        overrides: _overrides(f),
        lang: Lang.en,
      );
      await tester.pumpAndSettle();
      expect(find.text('Earlier: 9:00–10:00 AM'), findsOneWidget);
      await _tapText(tester, 'Earlier: 9:00–10:00 AM');
      expect(last!.single.startMin, 540);
      expect(find.text('9:00–10:00 AM'), findsNothing);
    });

    testWidgets('screen: save is disabled with the reason until the clash is fixed',
        (WidgetTester tester) async {
      final f = seedFakes();
      await pumpApp(tester, const SlotEditorScreen(batchId: kBatPhysA),
          overrides: _overrides(f));
      await tester.pumpAndSettle();

      // Nothing edited yet.
      expect(_saveButton(tester).onPressed, isNull);
      expect(find.text('কিছু বদলানো হয়নি'), findsOneWidget);

      // Move the shared start time to 10:30 through the picker.
      await _tapText(tester, 'শুরু');
      await _tapText(tester, 'সকাল');
      await _tapText(tester, '১০');
      await _tapText(tester, ':৩০');
      await _tapText(tester, 'ঠিক আছে');

      expect(find.text('সময় মিলছে না'), findsOneWidget);
      expect(find.text('আগে সময়ের মিল ঠিক করুন'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);

      await _tapText(tester, 'সকাল ১১:০০–দুপুর ১২:০০ নিন');

      expect(find.text('সময় মিলছে না'), findsNothing);
      expect(find.text('আগে সময়ের মিল ঠিক করুন'), findsNothing);
      expect(_saveButton(tester).onPressed, isNotNull);

      // Save asks "কবে থেকে নতুন সময়?" and then writes the new schedule.
      await _tapText(tester, 'সংরক্ষণ');
      expect(find.text('কবে থেকে নতুন সময়?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'সংরক্ষণ').last);
      await tester.pumpAndSettle();
      final physSlots =
          f.store.slots.where((s) => s.batchId == kBatPhysA).toList();
      expect(physSlots, hasLength(3));
      expect(physSlots.every((s) => s.startMin == 660 && s.endMin == 720), isTrue);
      expect(physSlots.every((s) => s.validFrom == kToday), isTrue);
    });
  });

  group('time picker', () {
    testWidgets('phone: period first, then hour and minute, readout names the period',
        (WidgetTester tester) async {
      Object? result;
      await pumpApp(
        tester,
        _Launcher(
          (BuildContext c) => showTimePickerSheet(c, initialMin: 960),
          (Object? v) => result = v,
        ),
      );
      await _tapText(tester, 'open');
      expect(find.byType(TimePickerPanel), findsOneWidget);
      expect(find.text('বিকাল ৪:০০'), findsOneWidget);
      // No typed field on a phone.
      expect(find.byType(TextField), findsNothing);

      await _tapText(tester, 'সন্ধ্যা');
      expect(find.text('সন্ধ্যা ৬:০০'), findsOneWidget);
      await _tapText(tester, '৭');
      await _tapText(tester, ':৩০');
      expect(find.text('সন্ধ্যা ৭:৩০'), findsOneWidget);
      await _tapText(tester, 'ঠিক আছে');
      expect(result, 19 * 60 + 30);
    });

    testWidgets('"other minute" reaches every 5 minutes', (WidgetTester tester) async {
      Object? result;
      await pumpApp(
        tester,
        _Launcher(
          (BuildContext c) => showTimePickerSheet(c, initialMin: 480),
          (Object? v) => result = v,
        ),
      );
      await _tapText(tester, 'open');
      await _tapText(tester, 'অন্য মিনিট');
      await _tapText(tester, ':৩৫');
      await _tapText(tester, 'ঠিক আছে');
      expect(result, 8 * 60 + 35);
    });

    testWidgets('English uses AM / PM', (WidgetTester tester) async {
      Object? result;
      await pumpApp(
        tester,
        _Launcher(
          (BuildContext c) => showTimePickerSheet(c, initialMin: 540),
          (Object? v) => result = v,
        ),
        lang: Lang.en,
      );
      await _tapText(tester, 'open');
      expect(find.text('9:00 AM'), findsOneWidget);
      await _tapText(tester, 'PM');
      expect(find.text('9:00 PM'), findsOneWidget);
      await _tapText(tester, 'OK');
      expect(result, 21 * 60);
    });

    testWidgets('desktop: typed "7:30 pm" and "৭:৩০ সন্ধ্যা" are parsed and echoed',
        (WidgetTester tester) async {
      Object? result;
      await pumpApp(
        tester,
        _Launcher(
          (BuildContext c) => showTimePickerSheet(c, initialMin: 600),
          (Object? v) => result = v,
        ),
        viewport: TestViewport.desktop,
      );
      await _tapText(tester, 'open');
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '7:30 pm');
      await tester.pump();
      expect(find.text('বুঝেছি: সন্ধ্যা ৭:৩০'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '৭:৩০ সন্ধ্যা');
      await tester.pump();
      expect(find.text('বুঝেছি: সন্ধ্যা ৭:৩০'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'blah');
      await tester.pump();
      expect(find.text('সময়টা বুঝতে পারিনি'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '19:30');
      await tester.pump();
      await _tapText(tester, 'ঠিক আছে');
      expect(result, 19 * 60 + 30);
    });

    testScreenMatrix(
      'time picker open',
      () => _Launcher(
        (BuildContext c) => showTimePickerSheet(c, initialMin: 1110),
        (Object? _) {},
      ),
      verify: (WidgetTester tester) async {
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerPanel), findsOneWidget);
        final bool desktop = tester.view.physicalSize.width >= 840;
        expect(find.byType(TextField), desktop ? findsOneWidget : findsNothing);
      },
    );
  });

  group('reminder lead sheet (scenario 22 UI path)', () {
    Future<Object?> run(
      WidgetTester tester, {
      required int? current,
      required List<String> taps,
      String? typed,
    }) async {
      Object? result = 'unset';
      await pumpApp(
        tester,
        _Launcher(
          (BuildContext c) =>
              showReminderLeadSheet(c, current: current, defaultLead: 15),
          (Object? v) => result = v,
        ),
      );
      await _tapText(tester, 'open');
      for (final t in taps) {
        await _tapText(tester, t);
      }
      if (typed != null) {
        await tester.enterText(find.byType(TextField), typed);
        await tester.pump();
      }
      await _tapText(tester, 'ঠিক আছে');
      return result;
    }

    testWidgets('a preset returns its minutes', (WidgetTester tester) async {
      expect(await run(tester, current: null, taps: <String>['২০ মিনিট আগে']), 20);
    });

    testWidgets('default returns the use-default marker, stored as null',
        (WidgetTester tester) async {
      final r = await run(tester, current: 30, taps: <String>['ডিফল্ট ব্যবহার করুন (১৫ মিনিট)']);
      expect(r, kReminderLeadUseDefault);
      expect(storedLeadOf(r as int?), isNull);
    });

    testWidgets('off returns 0', (WidgetTester tester) async {
      expect(
          await run(tester, current: null, taps: <String>['এই ব্যাচের জন্য বন্ধ']), 0);
    });

    testWidgets('custom accepts Bangla digits within 1..180',
        (WidgetTester tester) async {
      expect(
        await run(tester, current: null, taps: <String>['অন্য…'], typed: '৪৫'),
        45,
      );
    });

    testWidgets('custom out of range keeps OK disabled', (WidgetTester tester) async {
      await pumpApp(
        tester,
        _Launcher(
          (BuildContext c) =>
              showReminderLeadSheet(c, current: 45, defaultLead: 15),
          (Object? _) {},
        ),
      );
      await _tapText(tester, 'open');
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '181');
      await tester.pump();
      expect(find.text('১ থেকে ১৮০ এর মধ্যে একটি সংখ্যা দিন'), findsOneWidget);
      final ok = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ঠিক আছে'));
      expect(ok.onPressed, isNull);
    });

    testScreenMatrix(
      'reminder lead sheet open',
      () => _Launcher(
        (BuildContext c) => showReminderLeadSheet(c, current: 20, defaultLead: 15),
        (Object? _) {},
      ),
      verify: (WidgetTester tester) async {
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(ReminderLeadPanel), findsOneWidget);
      },
    );
  });

  group('batch schedule tab', () {
    testWidgets('shows the week, the default reminder row and stores a choice',
        (WidgetTester tester) async {
      final f = seedFakes();
      await pumpApp(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: BatchScheduleTab(batchId: kBatPhysA),
        ),
        overrides: f.overrides,
      );
      await tester.pumpAndSettle();
      expect(find.text('ক্লাস রিমাইন্ডার: ডিফল্ট (১৫ মিনিট আগে)'), findsOneWidget);
      expect(find.text('সপ্তাহের চিত্র'), findsOneWidget);
      expect(find.text('প্রতি সপ্তাহের সময় বদলান'), findsOneWidget);

      await _tapText(tester, 'ক্লাস রিমাইন্ডার: ডিফল্ট (১৫ মিনিট আগে)');
      await _tapText(tester, '১০ মিনিট আগে');
      await _tapText(tester, 'ঠিক আছে');
      expect(
        f.store.batches.firstWhere((b) => b.id == kBatPhysA).reminderLeadMin,
        10,
      );
      expect(find.text('ক্লাস রিমাইন্ডার: ১০ মিনিট আগে'), findsOneWidget);

      await _tapText(tester, 'ডিফল্টে ফেরান');
      expect(
        f.store.batches.firstWhere((b) => b.id == kBatPhysA).reminderLeadMin,
        isNull,
      );
    });

    testWidgets('Chem B keeps its own lead of 30 minutes',
        (WidgetTester tester) async {
      final f = seedFakes();
      await pumpApp(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: BatchScheduleTab(batchId: kBatChemB),
        ),
        overrides: f.overrides,
        lang: Lang.en,
      );
      await tester.pumpAndSettle();
      expect(find.text('Class reminder: 30 min before'), findsOneWidget);
      expect(find.text('Reset to default'), findsOneWidget);
    });

    testScreenMatrix(
      'BatchScheduleTab',
      () => const Padding(
        padding: EdgeInsets.all(16),
        child: BatchScheduleTab(batchId: kBatPhysA),
      ),
      overrides: () => seedFakes().overrides,
    );

    testScreenMatrix(
      'BatchScheduleTab empty',
      () => const Padding(
        padding: EdgeInsets.all(16),
        child: BatchScheduleTab(batchId: kBatPhysA),
      ),
      overrides: () {
        final f = seedFakes();
        f.store.slots.clear();
        return f.overrides;
      },
    );
  });

  group('slot editor', () {
    testScreenMatrix(
      'SlotEditorScreen',
      () => const SlotEditorScreen(batchId: kBatPhysA),
      overrides: () => seedFakes().overrides,
    );

    testScreenMatrix(
      'SlotEditorScreen with a clash',
      () => const SlotEditorScreen(batchId: kBatPhysA),
      overrides: () {
        final f = seedFakes();
        f.store.slots
          ..clear()
          ..add(const Slot(
              id: 's-x', batchId: kBatPhysA, weekday: 7, startMin: 630, endMin: 690));
        return _overrides(f);
      },
      verify: (WidgetTester tester) async {
        await tester.pumpAndSettle();
        expect(find.byType(ConflictCard), findsOneWidget);
      },
    );

    testScreenMatrix(
      'SlotEditorScreen per-day times',
      () => const SlotEditorScreen(batchId: kBatPhysA),
      overrides: () {
        final f = seedFakes();
        f.store.slots
          ..clear()
          ..addAll(const <Slot>[
            Slot(id: 'a', batchId: kBatPhysA, weekday: 5, startMin: 480, endMin: 540),
            Slot(id: 'b', batchId: kBatPhysA, weekday: 5, startMin: 1020, endMin: 1080),
            Slot(id: 'c', batchId: kBatPhysA, weekday: 6, startMin: 480, endMin: 540),
          ]);
        return f.overrides;
      },
    );

    testScreenMatrix(
      'SlotEditorField',
      () => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SlotEditorField(
          initial: const <SlotDraft>[],
          onChanged: (_) {},
        ),
      ),
      overrides: () => seedFakes().overrides,
    );

    testScreenMatrix(
      'EffectiveFromPanel',
      () => EffectiveFromPanel(today: kToday, onDone: (_) {}, onCancel: () {}),
    );

    testWidgets('same-time mode: weekday chips add and remove days',
        (WidgetTester tester) async {
      final f = seedFakes();
      List<SlotDraft>? last;
      await pumpApp(
        tester,
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SlotEditorField(
            initial: const <SlotDraft>[],
            onChanged: (List<SlotDraft> v) => last = v,
          ),
        ),
        overrides: f.overrides,
      );
      await tester.pumpAndSettle();
      expect(find.text('এখনো কোনো দিন বাছা হয়নি'), findsOneWidget);
      await _tapText(tester, 'শনি');
      await _tapText(tester, 'সোম');
      expect(last!.map((s) => s.weekday), <int>[6, 1]);
      expect(find.text('শনি, সোম — বিকাল ৪:০০–৫:০০'), findsOneWidget);
      await _tapText(tester, 'শনি');
      expect(last!.map((s) => s.weekday), <int>[1]);
    });
  });
}
