// Product 3.11 notification texts in both languages (+ suffixes).

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/reminders/reminder_texts.dart';

void main() {
  final ReminderTexts bn = ReminderTexts(Lang.bn);
  final ReminderTexts en = ReminderTexts(Lang.en);

  test('title is "{subject} · {batch}" (Product example)', () {
    expect(bn.title(subject: 'পদার্থবিজ্ঞান', batch: 'ব্যাচ A'), 'পদার্থবিজ্ঞান · ব্যাচ A');
    expect(en.title(subject: 'Physics', batch: 'Physics A'), 'Physics · Physics A');
    // A subject without a name (deleted) leaves only the batch.
    expect(en.title(subject: ' ', batch: 'Physics A'), 'Physics A');
  });

  test('Bangla body with Bangla digits and the period prefix (Product example)', () {
    expect(bn.body(kind: OccurrenceKind.regular, startMin: 960, endMin: 1020, leadMin: 15),
        'বিকাল ৪:০০–৫:০০ ক্লাস — ১৫ মিনিট পর');
    expect(bn.body(kind: OccurrenceKind.extra, startMin: 960, endMin: 1020, leadMin: 15),
        'বিকাল ৪:০০–৫:০০ ক্লাস — ১৫ মিনিট পর (অতিরিক্ত ক্লাস)');
    expect(bn.body(kind: OccurrenceKind.rescheduled, startMin: 960, endMin: 1020, leadMin: 15),
        'বিকাল ৪:০০–৫:০০ ক্লাস — ১৫ মিনিট পর (সময় বদলানো)');
  });

  test('English body with Latin digits', () {
    expect(en.body(kind: OccurrenceKind.regular, startMin: 600, endMin: 660, leadMin: 30),
        'Class 10:00–11:00 AM — in 30 min');
    expect(en.body(kind: OccurrenceKind.extra, startMin: 960, endMin: 1020, leadMin: 10),
        'Class 4:00–5:00 PM — in 10 min (extra class)');
    expect(en.body(kind: OccurrenceKind.rescheduled, startMin: 960, endMin: 1020, leadMin: 10),
        'Class 4:00–5:00 PM — in 10 min (rescheduled)');
  });

  test('notice carries id, fire time, payload and the roll-call action', () {
    final PlannedReminder r = PlannedReminder(
      id: 42,
      fireAtUtc: DateTime.utc(2026, 11, 21, 9, 45),
      occ: 's.slot.20261121',
      batchId: 'b',
      date: const LocalDate(2026, 11, 21),
      startMin: 960,
      endMin: 1020,
      kind: OccurrenceKind.regular,
      leadMin: 15,
      payload: 'rollcall|s.slot.20261121',
    );
    final n = bn.notice(r, subject: 'পদার্থবিজ্ঞান', batch: 'ব্যাচ A');
    expect(n.id, 42);
    expect(n.fireAtUtc, DateTime.utc(2026, 11, 21, 9, 45));
    expect(n.payload, 'rollcall|s.slot.20261121');
    expect(n.actionLabel, 'হাজিরা নিন');
    expect(en.notice(r, subject: 'Physics', batch: 'A').actionLabel, 'Take attendance');
  });
}
