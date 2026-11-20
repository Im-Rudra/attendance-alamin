import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/schedule/controllers/slot_editor_controller.dart';

SlotDraft slot(int weekday, int start, int end, {String? id}) =>
    SlotDraft(id: id, weekday: weekday, startMin: start, endMin: end);

Future<SlotCheckResult> clear(List<SlotDraft> _) async => const SlotCheckResult();

const int sat = 6, sun = 7, mon = 1, wed = 3, fri = 5;

void main() {
  group('scheduleSentence', () {
    test('joins days that share a time, in week order (bn)', () {
      final s = scheduleSentence(
        const AppFormat(Lang.bn),
        [
          slot(mon, 960, 1020),
          slot(sat, 960, 1020),
          slot(wed, 960, 1020),
          slot(sun, 600, 660),
        ],
        weekStart: 6,
        andWord: 'ও',
      );
      expect(s, 'শনি, সোম, বুধ — বিকাল ৪:০০–৫:০০; রবি — সকাল ১০:০০–১১:০০');
    });

    test('two classes on one day (en)', () {
      final s = scheduleSentence(
        const AppFormat(Lang.en),
        [slot(fri, 1020, 1080), slot(fri, 480, 540)],
        weekStart: 6,
        andWord: 'and',
      );
      expect(s, 'Fri — 8:00–9:00 AM and 5:00–6:00 PM');
    });
  });

  group('SlotEditorController', () {
    test('starts in same-time mode when every day shares one time', () {
      final c = SlotEditorController(
          initial: [slot(sat, 960, 1020), slot(mon, 960, 1020)], checker: clear);
      expect(c.sameAll, isTrue);
      expect(c.days, {sat, mon});
      expect(c.commonStart, 960);
      expect(c.changed, isFalse);
      c.dispose();
    });

    test('starts per-day when times differ or a day has two classes', () {
      final a = SlotEditorController(
          initial: [slot(sat, 960, 1020), slot(mon, 600, 660)], checker: clear);
      expect(a.sameAll, isFalse);
      final b = SlotEditorController(
          initial: [slot(fri, 480, 540), slot(fri, 1020, 1080)], checker: clear);
      expect(b.sameAll, isFalse);
      a.dispose();
      b.dispose();
    });

    test('toggling days and the shared time keeps ids and the length', () {
      final c = SlotEditorController(
          initial: [slot(sat, 960, 1020, id: 's1')], checker: clear);
      c.toggleDay(mon);
      expect(c.slots.map((s) => s.weekday), [sat, mon]);
      c.setCommonStart(1080); // 6 pm, length 60 kept
      expect(c.slots.map((s) => (s.startMin, s.endMin)),
          [(1080, 1140), (1080, 1140)]);
      expect(c.slots.first.id, 's1');
      c.toggleDay(sat);
      expect(c.days, {mon});
      expect(c.changed, isTrue);
      c.dispose();
    });

    test('per-day: add a second time after the last one, remove it again', () {
      final c = SlotEditorController(
          initial: [slot(sat, 480, 540), slot(mon, 600, 660)], checker: clear);
      expect(c.sameAll, isFalse);
      c.addTime(sat);
      final rows = c.rowsOf(sat);
      expect(rows, hasLength(2));
      expect((rows.last.draft.startMin, rows.last.draft.endMin), (540, 600));
      c.removeAt(rows.last.index);
      expect(c.rowsOf(sat), hasLength(1));
      expect(c.changed, isFalse);
      c.dispose();
    });

    test('turning same-time on collapses to one time per day', () {
      final c = SlotEditorController(
          initial: [slot(sat, 480, 540), slot(sat, 1020, 1080), slot(mon, 600, 660)],
          checker: clear);
      c.setSameAll(true);
      expect(c.slots, hasLength(2));
      expect(c.slots.every((s) => s.startMin == 480 && s.endMin == 540), isTrue);
      c.dispose();
    });

    test('blocker: no days, bad time, then clear', () async {
      final c = SlotEditorController(initial: const [], checker: clear);
      expect(c.blocker(), SlotBlocker.noDays);
      c.toggleDay(sat);
      expect(c.blocker(), SlotBlocker.checking);
      await Future<void>.delayed(Duration.zero);
      expect(c.blocker(), SlotBlocker.none);
      expect(c.blocker(requireChange: true), SlotBlocker.none);
      c.setCommonEnd(c.commonStart - 5);
      expect(c.hasBadTime, isTrue);
      expect(c.blocker(), SlotBlocker.badTime);
      c.dispose();
    });

    test('a clash blocks and a suggestion fixes the right class', () async {
      const clash = SlotCheckResult(
        groups: [
          ClashGroup(
            batchId: 'other',
            startMin: 600,
            endMin: 660,
            everyWeek: true,
            weekday: sun,
            existingKind: OccurrenceKind.regular,
            count: 1,
          ),
        ],
        suggestion: FreeSuggestion(
            durationMin: 60,
            earlierStartMin: 540,
            laterStartMin: 660,
            preferredStartMin: 630),
      );
      final c = SlotEditorController(
        initial: [slot(sat, 960, 1020), slot(sun, 630, 690)],
        checker: (slots) async =>
            slots.any((s) => s.startMin == 630) ? clash : const SlotCheckResult(),
      );
      c.start();
      await Future<void>.delayed(Duration.zero);
      expect(c.blocker(), SlotBlocker.clash);
      expect(c.check!.suggestion!.laterStartMin, 660);

      c.applyFix(c.check!.suggestion!, 660, {sun});
      await Future<void>.delayed(Duration.zero);
      expect(c.blocker(), SlotBlocker.none);
      expect(c.slots.firstWhere((s) => s.weekday == sun).startMin, 660);
      expect(c.slots.firstWhere((s) => s.weekday == sat).startMin, 960);
      c.dispose();
    });

    test('a stale check result never overwrites a newer one', () async {
      var calls = 0;
      final c = SlotEditorController(
        initial: [slot(sat, 960, 1020)],
        checker: (slots) async {
          final n = ++calls;
          // The first call answers late with a clash; the second is clear.
          if (n == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return const SlotCheckResult(groups: [
              ClashGroup(
                batchId: 'x',
                startMin: 960,
                endMin: 1020,
                everyWeek: true,
                weekday: sat,
                existingKind: OccurrenceKind.regular,
                count: 1,
              ),
            ]);
          }
          return const SlotCheckResult();
        },
      );
      c.start();
      c.toggleDay(mon);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.check!.ok, isTrue);
      c.dispose();
    });
  });
}
