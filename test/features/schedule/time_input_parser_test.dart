import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/features/schedule/controllers/time_input_parser.dart';

int m(int h, int min) => h * 60 + min;

void main() {
  group('parseTimeInput', () {
    test('12-hour with am / pm', () {
      expect(parseTimeInput('7:30 pm'), m(19, 30));
      expect(parseTimeInput('7:30 PM'), m(19, 30));
      expect(parseTimeInput('7:30pm'), m(19, 30));
      expect(parseTimeInput('7 p.m.'), m(19, 0));
      expect(parseTimeInput('7pm'), m(19, 0));
      expect(parseTimeInput('7:30 am'), m(7, 30));
      expect(parseTimeInput('12:00 am'), 0);
      expect(parseTimeInput('12:30 pm'), m(12, 30));
      expect(parseTimeInput('  4.15 pm '), m(16, 15));
    });

    test('24-hour', () {
      expect(parseTimeInput('19:30'), m(19, 30));
      expect(parseTimeInput('07:30'), m(7, 30));
      expect(parseTimeInput('0730'), m(7, 30));
      expect(parseTimeInput('1930'), m(19, 30));
      expect(parseTimeInput('13'), m(13, 0));
      expect(parseTimeInput('0:15'), 15);
    });

    test('Bangla digits and day-period words', () {
      expect(parseTimeInput('৭:৩০ সন্ধ্যা'), m(19, 30));
      expect(parseTimeInput('সন্ধ্যা ৭:৩০'), m(19, 30));
      expect(parseTimeInput('৭:৩০ সকাল'), m(7, 30));
      expect(parseTimeInput('বিকাল ৪:০০'), m(16, 0));
      expect(parseTimeInput('দুপুর ১২:০০'), m(12, 0));
      expect(parseTimeInput('দুপুর ১:৩০'), m(13, 30));
      expect(parseTimeInput('রাত ১২:১৫'), 15);
      expect(parseTimeInput('রাত ৯:০০'), m(21, 0));
      expect(parseTimeInput('ভোর ৫:০০'), m(5, 0));
      expect(parseTimeInput('১৯:৩০'), m(19, 30));
    });

    test('a bare 12-hour time resolves inside the coaching window', () {
      // QA-07: "10:00" typed after a PM time is 10 AM, not 10 PM.
      expect(parseTimeInput('10:00', hintMin: m(19, 0)), m(10, 0));
      expect(parseTimeInput('10:30', hintMin: m(16, 0)), m(10, 30));
      expect(parseTimeInput('9', hintMin: m(16, 0)), m(9, 0));
      expect(parseTimeInput('11:15'), m(11, 15));
      expect(parseTimeInput('12:10', hintMin: m(8, 0)), m(12, 10));
      expect(parseTimeInput('12:10', hintMin: m(16, 0)), m(12, 10));
      expect(parseTimeInput('1:30'), m(13, 30));
      expect(parseTimeInput('4:15', hintMin: m(9, 0)), m(16, 15));
      expect(parseTimeInput('6'), m(18, 0));
      // 7 and 8 are mornings unless the previous value was in the evening.
      expect(parseTimeInput('7:30'), m(7, 30));
      expect(parseTimeInput('7:30', hintMin: m(9, 0)), m(7, 30));
      expect(parseTimeInput('7:30', hintMin: m(19, 0)), m(19, 30));
      expect(parseTimeInput('8', hintMin: m(16, 0)), m(20, 0));
    });

    test('rejects what is not a time', () {
      for (final bad in <String>[
        '',
        '   ',
        'abc',
        '25:00',
        '7:75',
        '7:3',
        '13:00 pm',
        '0 pm',
        'সকাল ৩:০০', // 3 o'clock is not in the morning period
        'সকাল ৭:৩০ pm',
        '7:30 pm pm x',
      ]) {
        expect(parseTimeInput(bad, hintMin: 600), isNull, reason: bad);
      }
    });
  });
}
