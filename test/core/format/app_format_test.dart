import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/format/lexicon.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bn = AppFormat(Lang.bn);
  const en = AppFormat(Lang.en);

  group('Lang', () {
    test('code / fromCode', () {
      expect(Lang.bn.code, 'bn');
      expect(Lang.en.code, 'en');
      expect(Lang.fromCode('en'), Lang.en);
      expect(Lang.fromCode('bn'), Lang.bn);
      expect(Lang.fromCode(null), Lang.bn);
      expect(Lang.fromCode('fr'), Lang.bn);
      expect(Lang.fromCode(''), Lang.bn);
    });
  });

  group('Lexicon (exact Product spellings)', () {
    test('months', () {
      expect(Lexicon.monthsBn, [
        'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', //
        'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
      ]);
      expect(Lexicon.monthsShortBn, [
        'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রি', 'মে', 'জুন', //
        'জুলা', 'আগ', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে',
      ]);
      expect(Lexicon.monthsEn.length, 12);
      expect(Lexicon.monthsShortEn.length, 12);
    });

    test('weekdays are ISO ordered (Monday first)', () {
      expect(Lexicon.weekdaysBn, [
        'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', //
        'শুক্রবার', 'শনিবার', 'রবিবার',
      ]);
      expect(Lexicon.weekdaysShortBn, [
        'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি', //
      ]);
      expect(Lexicon.weekdaysEn.first, 'Monday');
      expect(Lexicon.weekdaysEn.last, 'Sunday');
      expect(Lexicon.weekdaysShortEn, ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
    });

    test('period words', () {
      expect(Lexicon.periodsBn, ['ভোর', 'সকাল', 'দুপুর', 'বিকাল', 'সন্ধ্যা', 'রাত']);
    });
  });

  group('digits / toAsciiDigits', () {
    test('digits maps ASCII to Bangla only in bn', () {
      expect(bn.digits('0123456789'), '০১২৩৪৫৬৭৮৯');
      expect(en.digits('0123456789'), '0123456789');
      expect(bn.digits('4:30 PM a1'), '৪:৩০ PM a১');
      expect(bn.digits(''), '');
    });

    test('toAsciiDigits maps Bangla digits to ASCII', () {
      expect(AppFormat.toAsciiDigits('০১৭১২'), '01712');
      expect(AppFormat.toAsciiDigits('০১২৩৪৫৬৭৮৯'), '0123456789');
      expect(AppFormat.toAsciiDigits('01712'), '01712');
      expect(AppFormat.toAsciiDigits('৳১,৫০০'), '৳1,500');
      expect(AppFormat.toAsciiDigits('ক১খ'), 'ক1খ');
      expect(AppFormat.toAsciiDigits(''), '');
    });

    test('round trip', () {
      const s = '0123456789';
      expect(AppFormat.toAsciiDigits(bn.digits(s)), s);
    });
  });

  group('number / money / percent (lakh grouping)', () {
    // (n, bn, en)
    const numbers = <(int, String, String)>[
      (0, '০', '0'),
      (1, '১', '1'),
      (999, '৯৯৯', '999'),
      (1000, '১,০০০', '1,000'),
      (1500, '১,৫০০', '1,500'),
      (9999, '৯,৯৯৯', '9,999'),
      (10000, '১০,০০০', '10,000'),
      (99999, '৯৯,৯৯৯', '99,999'),
      (100000, '১,০০,০০০', '1,00,000'),
      (100001, '১,০০,০০১', '1,00,001'),
      (120000, '১,২০,০০০', '1,20,000'),
      (999999, '৯,৯৯,৯৯৯', '9,99,999'),
      (1000000, '১০,০০,০০০', '10,00,000'),
      (12345678, '১,২৩,৪৫,৬৭৮', '1,23,45,678'),
      (-1500, '-১,৫০০', '-1,500'),
      (-100000, '-১,০০,০০০', '-1,00,000'),
    ];
    for (final (n, b, e) in numbers) {
      test('number($n)', () {
        expect(bn.number(n), b);
        expect(en.number(n), e);
      });
    }

    const moneys = <(int, String, String)>[
      (0, '৳০', '৳0'),
      (1, '৳১', '৳1'),
      (800, '৳৮০০', '৳800'),
      (1000, '৳১,০০০', '৳1,000'),
      (1500, '৳১,৫০০', '৳1,500'),
      (2500, '৳২,৫০০', '৳2,500'),
      (99999, '৳৯৯,৯৯৯', '৳99,999'),
      (100000, '৳১,০০,০০০', '৳1,00,000'),
      (120000, '৳১,২০,০০০', '৳1,20,000'),
      (1000000, '৳১০,০০,০০০', '৳10,00,000'),
      (-100, '-৳১০০', '-৳100'),
    ];
    for (final (taka, b, e) in moneys) {
      test('money($taka)', () {
        expect(bn.money(taka), b);
        expect(en.money(taka), e);
      });
    }

    test('percent', () {
      expect(bn.percent(85), '৮৫%');
      expect(en.percent(85), '85%');
      expect(bn.percent(0), '০%');
      expect(bn.percent(100), '১০০%');
      expect(en.percent(100), '100%');
    });
  });

  group('month and weekday names', () {
    test('all 12 months, full and short', () {
      for (var m = 1; m <= 12; m++) {
        expect(bn.monthName(m), Lexicon.monthsBn[m - 1]);
        expect(bn.monthShort(m), Lexicon.monthsShortBn[m - 1]);
        expect(en.monthName(m), Lexicon.monthsEn[m - 1]);
        expect(en.monthShort(m), Lexicon.monthsShortEn[m - 1]);
      }
      expect(bn.monthName(11), 'নভেম্বর');
      expect(bn.monthShort(11), 'নভে');
      expect(en.monthName(11), 'November');
      expect(en.monthShort(11), 'Nov');
      expect(en.monthName(5), 'May');
    });

    test('all 7 ISO weekdays', () {
      for (var d = 1; d <= 7; d++) {
        expect(bn.weekdayName(d), Lexicon.weekdaysBn[d - 1]);
        expect(bn.weekdayShort(d), Lexicon.weekdaysShortBn[d - 1]);
        expect(en.weekdayName(d), Lexicon.weekdaysEn[d - 1]);
        expect(en.weekdayShort(d), Lexicon.weekdaysShortEn[d - 1]);
      }
      expect(bn.weekdayName(6), 'শনিবার');
      expect(bn.weekdayShort(6), 'শনি');
      expect(bn.weekdayName(7), 'রবিবার');
      expect(en.weekdayName(4), 'Thursday');
      expect(en.weekdayShort(4), 'Thu');
    });
  });

  group('dates', () {
    // (iso, bn date, en date, bn short, en short, bn weekdayDate, en weekdayDate)
    const table = <(String, String, String, String, String, String, String)>[
      (
        '2026-11-05',
        '৫ নভেম্বর ২০২৬',
        '5 Nov 2026',
        '৫ নভে',
        '5 Nov',
        'বৃহস্পতিবার, ৫ নভেম্বর',
        'Thursday, 5 Nov',
      ),
      (
        '2026-11-19',
        '১৯ নভেম্বর ২০২৬',
        '19 Nov 2026',
        '১৯ নভে',
        '19 Nov',
        'বৃহস্পতিবার, ১৯ নভেম্বর',
        'Thursday, 19 Nov',
      ),
      (
        '2026-11-21',
        '২১ নভেম্বর ২০২৬',
        '21 Nov 2026',
        '২১ নভে',
        '21 Nov',
        'শনিবার, ২১ নভেম্বর',
        'Saturday, 21 Nov',
      ),
      (
        '2026-11-22',
        '২২ নভেম্বর ২০২৬',
        '22 Nov 2026',
        '২২ নভে',
        '22 Nov',
        'রবিবার, ২২ নভেম্বর',
        'Sunday, 22 Nov',
      ),
      (
        '2026-01-31',
        '৩১ জানুয়ারি ২০২৬',
        '31 Jan 2026',
        '৩১ জানু',
        '31 Jan',
        'শনিবার, ৩১ জানুয়ারি',
        'Saturday, 31 Jan',
      ),
      (
        '2024-02-29',
        '২৯ ফেব্রুয়ারি ২০২৪',
        '29 Feb 2024',
        '২৯ ফেব্রু',
        '29 Feb',
        'বৃহস্পতিবার, ২৯ ফেব্রুয়ারি',
        'Thursday, 29 Feb',
      ),
      (
        '2026-12-31',
        '৩১ ডিসেম্বর ২০২৬',
        '31 Dec 2026',
        '৩১ ডিসে',
        '31 Dec',
        'বৃহস্পতিবার, ৩১ ডিসেম্বর',
        'Thursday, 31 Dec',
      ),
      (
        '2026-12-14',
        '১৪ ডিসেম্বর ২০২৬',
        '14 Dec 2026',
        '১৪ ডিসে',
        '14 Dec',
        'সোমবার, ১৪ ডিসেম্বর',
        'Monday, 14 Dec',
      ),
    ];
    for (final (iso, bnDate, enDate, bnShort, enShort, bnWd, enWd) in table) {
      test(iso, () {
        final d = LocalDate.parse(iso);
        expect(bn.date(d), bnDate);
        expect(en.date(d), enDate);
        expect(bn.dateShort(d), bnShort);
        expect(en.dateShort(d), enShort);
        expect(bn.weekdayDate(d), bnWd);
        expect(en.weekdayDate(d), enWd);
      });
    }

    test('monthYear', () {
      expect(bn.monthYear(const YearMonth(2026, 11)), 'নভেম্বর ২০২৬');
      expect(en.monthYear(const YearMonth(2026, 11)), 'November 2026');
      expect(bn.monthYear(const YearMonth(2027, 1)), 'জানুয়ারি ২০২৭');
      expect(en.monthYear(const YearMonth(2027, 1)), 'January 2027');
    });
  });

  group('monthList (plan section 1 #24)', () {
    const sep = YearMonth(2026, 9);
    const oct = YearMonth(2026, 10);
    const nov = YearMonth(2026, 11);

    test('empty list', () {
      expect(bn.monthList(const [], currentYear: 2026), '');
    });

    test('current-year months have no year', () {
      expect(bn.monthList([oct, nov], currentYear: 2026), 'অক্টোবর, নভেম্বর');
      expect(bn.monthList([nov], currentYear: 2026), 'নভেম্বর');
      expect(en.monthList([oct, nov], currentYear: 2026), 'October, November');
    });

    test('other-year months get the year once per year group (Product example)', () {
      expect(bn.monthList([oct, nov], currentYear: 2025), 'অক্টোবর, নভেম্বর ২০২৬');
      expect(en.monthList([oct, nov], currentYear: 2025), 'October, November 2026');
      expect(bn.monthList([nov], currentYear: 2027), 'নভেম্বর ২০২৬');
    });

    test('mixed years: year after the last month of each non-current group', () {
      const months = [YearMonth(2025, 12), YearMonth(2026, 1), YearMonth(2026, 2)];
      expect(
        bn.monthList(months, currentYear: 2026),
        'ডিসেম্বর ২০২৫, জানুয়ারি, ফেব্রুয়ারি',
      );
      expect(
        bn.monthList(months, currentYear: 2024),
        'ডিসেম্বর ২০২৫, জানুয়ারি, ফেব্রুয়ারি ২০২৬',
      );
      expect(
        en.monthList(months, currentYear: 2025),
        'December, January, February 2026',
      );
      expect(
        en.monthList(months, currentYear: 2026),
        'December 2025, January, February',
      );
    });

    test('three-month list across a year change', () {
      const months = [
        YearMonth(2026, 11),
        YearMonth(2026, 12),
        YearMonth(2027, 1),
      ];
      expect(
        bn.monthList(months, currentYear: 2026),
        'নভেম্বর, ডিসেম্বর, জানুয়ারি ২০২৭',
      );
    });

    test('partial months (Scenario 5 receipt)', () {
      expect(
        bn.monthList([sep, oct, nov], currentYear: 2026, partial: {nov}),
        'সেপ্টেম্বর, অক্টোবর, নভেম্বর (আংশিক)',
      );
      expect(
        en.monthList([sep, oct, nov], currentYear: 2026, partial: {nov}),
        'September, October, November (partial)',
      );
      expect(
        bn.monthList([sep, oct, nov], currentYear: 2026, partial: {sep}),
        'সেপ্টেম্বর (আংশিক), অক্টোবর, নভেম্বর',
      );
      expect(
        bn.monthList([oct, nov], currentYear: 2025, partial: {nov}),
        'অক্টোবর, নভেম্বর ২০২৬ (আংশিক)',
      );
    });

    test('input is sorted and de-duplicated', () {
      expect(
        bn.monthList([nov, sep, oct, sep], currentYear: 2026),
        'সেপ্টেম্বর, অক্টোবর, নভেম্বর',
      );
    });
  });

  group('time, dayPeriod (bands from plan section 1 #22)', () {
    // (minutes, bn period, bn time, en period, en time)
    const table = <(int, String, String, String, String)>[
      (0, 'রাত', 'রাত ১২:০০', 'AM', '12:00 AM'),
      (1440, 'রাত', 'রাত ১২:০০', 'AM', '12:00 AM'),
      (59, 'রাত', 'রাত ১২:৫৯', 'AM', '12:59 AM'),
      (180, 'রাত', 'রাত ৩:০০', 'AM', '3:00 AM'),
      (239, 'রাত', 'রাত ৩:৫৯', 'AM', '3:59 AM'),
      (240, 'ভোর', 'ভোর ৪:০০', 'AM', '4:00 AM'),
      (359, 'ভোর', 'ভোর ৫:৫৯', 'AM', '5:59 AM'),
      (360, 'সকাল', 'সকাল ৬:০০', 'AM', '6:00 AM'),
      (600, 'সকাল', 'সকাল ১০:০০', 'AM', '10:00 AM'),
      (719, 'সকাল', 'সকাল ১১:৫৯', 'AM', '11:59 AM'),
      (720, 'দুপুর', 'দুপুর ১২:০০', 'PM', '12:00 PM'),
      (780, 'দুপুর', 'দুপুর ১:০০', 'PM', '1:00 PM'),
      (899, 'দুপুর', 'দুপুর ২:৫৯', 'PM', '2:59 PM'),
      (900, 'বিকাল', 'বিকাল ৩:০০', 'PM', '3:00 PM'),
      (990, 'বিকাল', 'বিকাল ৪:৩০', 'PM', '4:30 PM'),
      (1079, 'বিকাল', 'বিকাল ৫:৫৯', 'PM', '5:59 PM'),
      (1080, 'সন্ধ্যা', 'সন্ধ্যা ৬:০০', 'PM', '6:00 PM'),
      (1199, 'সন্ধ্যা', 'সন্ধ্যা ৭:৫৯', 'PM', '7:59 PM'),
      (1200, 'রাত', 'রাত ৮:০০', 'PM', '8:00 PM'),
      (1380, 'রাত', 'রাত ১১:০০', 'PM', '11:00 PM'),
      (1439, 'রাত', 'রাত ১১:৫৯', 'PM', '11:59 PM'),
    ];
    for (final (minutes, bnP, bnT, enP, enT) in table) {
      test('$minutes min', () {
        expect(bn.dayPeriod(minutes), bnP);
        expect(bn.time(minutes), bnT);
        expect(en.dayPeriod(minutes), enP);
        expect(en.time(minutes), enT);
      });
    }

    test('Lexicon.periodIndex band edges', () {
      const edges = <(int, int)>[
        (0, Lexicon.periodRat),
        (239, Lexicon.periodRat),
        (240, Lexicon.periodVor),
        (359, Lexicon.periodVor),
        (360, Lexicon.periodSokal),
        (719, Lexicon.periodSokal),
        (720, Lexicon.periodDupur),
        (899, Lexicon.periodDupur),
        (900, Lexicon.periodBikal),
        (1079, Lexicon.periodBikal),
        (1080, Lexicon.periodSondha),
        (1199, Lexicon.periodSondha),
        (1200, Lexicon.periodRat),
        (1439, Lexicon.periodRat),
        (1440, Lexicon.periodRat),
      ];
      for (final (minutes, index) in edges) {
        expect(Lexicon.periodIndex(minutes), index, reason: '$minutes');
      }
    });
  });

  group('timeRange (plan section 1 #23)', () {
    // (start, end, bn, en)
    const table = <(int, int, String, String)>[
      // Acceptance examples.
      (600, 660, 'সকাল ১০:০০–১১:০০', '10:00–11:00 AM'),
      (660, 720, 'সকাল ১১:০০–দুপুর ১২:০০', '11:00 AM–12:00 PM'),
      (720, 780, 'দুপুর ১২:০০–১:০০', '12:00–1:00 PM'),
      // Product / acceptance scenarios.
      (960, 1020, 'বিকাল ৪:০০–৫:০০', '4:00–5:00 PM'),
      (1020, 1080, 'বিকাল ৫:০০–সন্ধ্যা ৬:০০', '5:00–6:00 PM'),
      (480, 540, 'সকাল ৮:০০–৯:০০', '8:00–9:00 AM'),
      (540, 600, 'সকাল ৯:০০–১০:০০', '9:00–10:00 AM'),
      (780, 840, 'দুপুর ১:০০–২:০০', '1:00–2:00 PM'),
      // Period changes inside the range.
      (870, 930, 'দুপুর ২:৩০–বিকাল ৩:৩০', '2:30–3:30 PM'),
      (1140, 1200, 'সন্ধ্যা ৭:০০–রাত ৮:০০', '7:00–8:00 PM'),
      (300, 360, 'ভোর ৫:০০–সকাল ৬:০০', '5:00–6:00 AM'),
      (180, 270, 'রাত ৩:০০–ভোর ৪:৩০', '3:00–4:30 AM'),
      // Late night, midnight and noon edges.
      (1200, 1260, 'রাত ৮:০০–৯:০০', '8:00–9:00 PM'),
      (1380, 1440, 'রাত ১১:০০–১২:০০', '11:00 PM–12:00 AM'),
      (0, 60, 'রাত ১২:০০–১:০০', '12:00–1:00 AM'),
      (690, 750, 'সকাল ১১:৩০–দুপুর ১২:৩০', '11:30 AM–12:30 PM'),
    ];
    for (final (start, end, b, e) in table) {
      test('$start–$end', () {
        expect(bn.timeRange(start, end), b);
        expect(en.timeRange(start, end), e);
      });
    }
  });

  group('ordinals for the dues UI', () {
    // (n, bn, en)
    const table = <(int, String, String)>[
      (1, '১ম', '1st'),
      (2, '২য়', '2nd'),
      (3, '৩য়', '3rd'),
      (4, '৪র্থ', '4th'),
      (5, '৫ম', '5th'),
      (6, '৬ষ্ঠ', '6th'),
      (7, '৭ম', '7th'),
      (8, '৮ম', '8th'),
      (9, '৯ম', '9th'),
      (10, '১০ম', '10th'),
      (11, '১১তম', '11th'),
      (12, '১২তম', '12th'),
      (13, '১৩তম', '13th'),
      (21, '২১তম', '21st'),
      (22, '২২তম', '22nd'),
      (23, '২৩তম', '23rd'),
      (101, '১০১তম', '101st'),
      (111, '১১১তম', '111th'),
    ];
    for (final (n, b, e) in table) {
      test('ordinal($n)', () {
        expect(bn.ordinal(n), b);
        expect(en.ordinal(n), e);
      });
    }

    test('ordinalDay', () {
      expect(bn.ordinalDay(5), '৫ম দিন');
      expect(en.ordinalDay(5), '5th day');
      expect(bn.ordinalDay(1), '১ম দিন');
      expect(bn.ordinalDay(10), '১০ম দিন');
      expect(en.ordinalDay(3), '3rd day');
    });
  });
}
