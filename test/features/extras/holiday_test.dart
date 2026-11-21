// Holiday closure (F28): the preview numbers, cancelRange / undoCancelRange
// counts, and the HolidayScreen in the 8-case matrix plus the declare ->
// confirm -> undo flow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/time/date_range.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/extras/controllers/holiday_logic.dart';
import 'package:attendance_alamin/features/extras/ui/holiday_screen.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

// Sat 21 Nov (Physics) .. Wed 25 Nov: Sat, Sun (Chem), Mon, Tue (Chem), Wed.
const DateRange _week = DateRange(LocalDate(2026, 11, 21), LocalDate(2026, 11, 25));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final AppLocalizations bn = lookupAppLocalizations(const Locale('bn'));

  group('holiday logic', () {
    test('preview counts classes and batches; restore mirrors cancel', () async {
      final SeededFakes f = seedFakes();
      List<BatchSchedule> schedules = await f.schedule.watchAllSchedules().first;

      final HolidayPreview cancel = previewCancel(schedules, _week);
      expect(cancel.classes, 5);
      expect(cancel.batches, 2);
      expect(previewRestore(schedules, _week).classes, 0);

      final int cancelled = await f.schedule.cancelRange(_week, note: 'ঈদের ছুটি');
      expect(cancelled, cancel.classes, reason: 'the preview is the number the action returns');
      expect(f.store.exceptions.where((e) => e.kind == ExceptionKind.cancel), hasLength(5));

      schedules = await f.schedule.watchAllSchedules().first;
      expect(previewCancel(schedules, _week).classes, 0, reason: 'already cancelled');
      expect(previewRestore(schedules, _week).classes, 5);
      expect(previewRestore(schedules, _week).batches, 2);

      final int restored = await f.schedule.undoCancelRange(_week);
      expect(restored, 5);
      expect(f.store.exceptions.where((e) => e.kind == ExceptionKind.cancel), isEmpty);
      schedules = await f.schedule.watchAllSchedules().first;
      expect(previewCancel(schedules, _week).classes, 5);
    });

    test('an empty or inverted range previews nothing', () async {
      final SeededFakes f = seedFakes();
      final List<BatchSchedule> schedules = await f.schedule.watchAllSchedules().first;
      const DateRange inverted = DateRange(LocalDate(2026, 11, 25), LocalDate(2026, 11, 21));
      expect(previewCancel(schedules, inverted).isEmpty, isTrue);
      expect(previewRestore(schedules, inverted).isEmpty, isTrue);
    });
  });

  group('holiday screen', () {
    testScreenMatrix(
      'holiday: preview of today',
      () => const HolidayScreen(),
      overrides: () => seedFakes().overrides,
      verify: (WidgetTester tester) async {
        // Today is Saturday: only Physics A meets.
        expect(find.byKey(const ValueKey<String>('holiday-preview')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('holiday-from')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('holiday-to')), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('holiday-reason')), findsOneWidget);
      },
    );

    testWidgets('declare, confirm, then undo from the snackbar', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await pumpApp(tester, const HolidayScreen(), overrides: f.overrides);

      final Text preview = tester.widget<Text>(find.byKey(const ValueKey<String>('holiday-preview')));
      expect(preview.data, bn.extraHolidayPreview('১', '১'));

      await tester.enterText(find.byKey(const ValueKey<String>('holiday-reason')), 'ঈদের ছুটি');
      await tester.tap(find.byKey(const ValueKey<String>('holiday-run')));
      await _settle(tester);

      // The confirm dialog repeats the number.
      expect(find.text(bn.extraHolidayConfirmTitle('১', '১')), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(BhorDialog),
        matching: find.byWidgetPredicate((Widget w) => w is BhorButton && w.variant != BhorButtonVariant.secondary),
      ));
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 400));

      final cancels = f.store.exceptions.where((e) => e.kind == ExceptionKind.cancel).toList();
      expect(cancels, hasLength(1));
      expect(cancels.single.note, 'ঈদের ছুটি');
      expect(find.text(bn.extraHolidayDone('১')), findsOneWidget);
      // Nothing left to cancel that day.
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('holiday-preview'))).data,
          bn.extraHolidayPreviewNone);

      await tester.tap(find.text(bn.commonUndo));
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(f.store.exceptions.where((e) => e.kind == ExceptionKind.cancel), isEmpty);
      expect(find.text(bn.extraHolidayRestored('১')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('holiday-preview'))).data,
          bn.extraHolidayPreview('১', '১'));
    });

    testWidgets('undo mode brings a cancelled day back', (WidgetTester tester) async {
      final SeededFakes f = seedFakes();
      await f.schedule.cancelRange(const DateRange(LocalDate(2026, 11, 21), LocalDate(2026, 11, 21)));
      await pumpApp(tester, const HolidayScreen(), overrides: f.overrides);

      await tester.tap(find.text(bn.extraHolidayModeRestore));
      await _settle(tester);
      expect(tester.widget<Text>(find.byKey(const ValueKey<String>('holiday-preview'))).data,
          bn.extraHolidayRestorePreview('১'));

      await tester.tap(find.byKey(const ValueKey<String>('holiday-run')));
      await _settle(tester);
      expect(f.store.exceptions.where((e) => e.kind == ExceptionKind.cancel), isEmpty);
      expect(find.text(bn.extraHolidayRestored('১')), findsOneWidget);
    });
  });
}
