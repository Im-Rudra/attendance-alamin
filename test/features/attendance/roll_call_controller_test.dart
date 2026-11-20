// M7-A: the roll call state (toggle / late / undo / draft / autosave) and the
// pure helpers behind the attendance screens.

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_call_controller.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';
import 'package:attendance_alamin/features/attendance/widgets/batch_attendance_tab.dart';

import '../../helpers/fixtures.dart';

void main() {
  late List<Map<String, AttendanceStatus>> saves;
  late List<String?> drafts;

  RollCallController make({
    bool saved = false,
    Map<String, AttendanceStatus> initial = const <String, AttendanceStatus>{},
    bool failSave = false,
    bool readOnly = false,
    bool restored = false,
  }) {
    saves = <Map<String, AttendanceStatus>>[];
    drafts = <String?>[];
    return RollCallController(
      students: <Student>[kStudents[0], kStudents[2], kStudents[3]],
      initial: initial,
      saved: saved,
      readOnly: readOnly,
      restoredFromDraft: restored,
      persist: (Map<String, AttendanceStatus> s, String? note) async {
        if (failSave) throw StateError('disk full');
        saves.add(Map<String, AttendanceStatus>.of(s));
      },
      writeDraft: (String? json) async {
        drafts.add(json);
      },
    );
  }

  test('everyone starts present; tap toggles present and absent', () {
    final RollCallController c = make();
    expect(c.counts.present, 3);
    expect(c.counts.absent, 0);
    c.toggle(kStuRahim);
    expect(c.statusOf(kStuRahim), AttendanceStatus.absent);
    expect(c.counts.present, 2);
    expect(c.counts.absent, 1);
    c.toggle(kStuRahim);
    expect(c.statusOf(kStuRahim), AttendanceStatus.present);
  });

  test('late toggles with present; a late student counts as attended', () {
    final RollCallController c = make();
    c.toggleLate(kStuSara);
    expect(c.statusOf(kStuSara), AttendanceStatus.late);
    expect(c.counts.late, 1);
    expect(c.counts.attended, 3);
    c.toggleLate(kStuSara);
    expect(c.statusOf(kStuSara), AttendanceStatus.present);
  });

  test('a tap on a late or excused row marks it absent', () {
    final RollCallController c = make(initial: <String, AttendanceStatus>{
      kStuSara: AttendanceStatus.late,
      kStuNila: AttendanceStatus.leave,
    });
    c.toggle(kStuSara);
    c.toggle(kStuNila);
    expect(c.statusOf(kStuSara), AttendanceStatus.absent);
    expect(c.statusOf(kStuNila), AttendanceStatus.absent);
  });

  test('mark all absent / present and undo one step at a time', () {
    final RollCallController c = make();
    c.markAll(AttendanceStatus.absent);
    expect(c.counts.absent, 3);
    c.markAll(AttendanceStatus.present);
    expect(c.counts.present, 3);
    expect(c.canUndo, isTrue);
    c.undo();
    expect(c.counts.absent, 3);
    c.undo();
    expect(c.counts.present, 3);
    expect(c.canUndo, isFalse);
  });

  test('before the first save every change is stored as a draft', () async {
    final RollCallController c = make();
    expect(c.dirty, isFalse);
    c.toggle(kStuRahim);
    expect(c.dirty, isTrue);
    expect(c.saved, isFalse);
    expect(drafts, hasLength(1));
    final RollDraft? draft = RollDraftCodec.decode(drafts.single);
    expect(draft, isNotNull);
    expect(draft!.statuses[kStuRahim], AttendanceStatus.absent);
    expect(saves, isEmpty);
  });

  test('the first save commits, clears the draft, later changes autosave', () async {
    final RollCallController c = make();
    c.toggle(kStuRahim);
    expect(await c.save(), isTrue);
    expect(c.saved, isTrue);
    expect(c.dirty, isFalse);
    expect(saves, hasLength(1));
    expect(saves.single[kStuRahim], AttendanceStatus.absent);
    expect(drafts.last, isNull);

    c.toggle(kStuSara);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(saves, hasLength(2));
    expect(saves.last[kStuSara], AttendanceStatus.absent);
    expect(c.dirty, isFalse);
  });

  test('a failed save keeps the changes dirty and reports the error', () async {
    final RollCallController c = make(failSave: true);
    c.toggle(kStuRahim);
    expect(await c.save(), isFalse);
    expect(c.error, isNotNull);
    expect(c.dirty, isTrue);
    expect(c.saved, isFalse);
  });

  test('a read-only roll call ignores every change', () {
    final RollCallController c = make(readOnly: true, saved: true);
    c.toggle(kStuRahim);
    c.markAll(AttendanceStatus.absent);
    c.setNote('x');
    expect(c.counts.present, 3);
    expect(c.dirty, isFalse);
  });

  test('a restored draft makes the roll call dirty so leaving asks', () {
    final RollCallController c = make(
      restored: true,
      initial: <String, AttendanceStatus>{kStuRahim: AttendanceStatus.absent},
    );
    expect(c.dirty, isTrue);
    expect(c.edited, isTrue);
    expect(c.counts.absent, 1);
  });

  test('the draft codec round-trips and drops garbage', () {
    final String raw = RollDraftCodec.encode(
      <String, AttendanceStatus>{kStuRahim: AttendanceStatus.late, kStuSara: AttendanceStatus.leave},
      'test day',
    );
    final RollDraft? back = RollDraftCodec.decode(raw);
    expect(back!.statuses[kStuRahim], AttendanceStatus.late);
    expect(back.statuses[kStuSara], AttendanceStatus.leave);
    expect(back.note, 'test day');
    expect(RollDraftCodec.decode('not json'), isNull);
    expect(RollDraftCodec.decode('{"s": {"a": "Z"}}'), isNull);
    expect(RollDraftCodec.decode(null), isNull);
  });

  group('helpers', () {
    test('commonSlotTimes takes the most common live slot time', () {
      const List<Slot> slots = <Slot>[
        Slot(id: 'a', batchId: 'b', weekday: 1, startMin: 480, endMin: 540),
        Slot(id: 'b', batchId: 'b', weekday: 2, startMin: 960, endMin: 1020),
        Slot(id: 'c', batchId: 'b', weekday: 3, startMin: 960, endMin: 1020),
      ];
      final ({int start, int end}) t = commonSlotTimes(slots);
      expect(t.start, 960);
      expect(t.end, 1020);
      final ({int start, int end}) none = commonSlotTimes(const <Slot>[]);
      expect(none.start, kDefaultAdHocStartMin);
    });

    test('defaultChoice prefers the first class without a roll call', () {
      const List<SessionChoice> choices = <SessionChoice>[
        SessionChoice(occ: 'a', startMin: 480, endMin: 540, taken: true),
        SessionChoice(occ: 'b', startMin: 960, endMin: 1020),
      ];
      expect(defaultChoice(choices)!.occ, 'b');
      expect(defaultChoice(const <SessionChoice>[]), isNull);
    });

    test('batchMonthStats averages the students of the month', () {
      final List<AttendanceRecord> records = seedRecords();
      final List<Enrollment> enrollments = <Enrollment>[
        for (final Enrollment e in kEnrollments)
          if (e.batchId == kBatPhysA) e,
      ];
      final List<SessionSummary> sessions = <SessionSummary>[
        for (final AttendanceSession s in seedSessions())
          SessionSummary(session: s, tally: const AttendanceTally(present: 1)),
      ];
      final ({int? percent, int held}) stats = batchMonthStats(
        month: const YearMonth(2026, 11),
        sessions: sessions,
        records: records,
        enrollments: enrollments,
      );
      expect(stats.held, 6);
      // Rahim 3/6 = 50, Sara 5/5 = 100 (one leave), Nila 3/4 = 75: mean 75.
      expect(stats.percent, 75);
      final ({int? percent, int held}) other = batchMonthStats(
        month: const YearMonth(2026, 10),
        sessions: sessions,
        records: records,
        enrollments: enrollments,
      );
      expect(other.held, 0);
      expect(other.percent, isNull);
    });
  });
}
