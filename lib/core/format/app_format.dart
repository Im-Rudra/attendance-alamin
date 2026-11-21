import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/format/lexicon.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';

/// All user-visible numbers, money, dates and times. Pure Dart; never uses
/// intl. The DB and validators always see ASCII digits ([toAsciiDigits]).
class AppFormat {
  const AppFormat(this.lang);

  final Lang lang;

  bool get _bn => lang == Lang.bn;

  static const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  /// Maps ASCII digits to Bangla digits when [lang] is bn; unchanged for en.
  String digits(String ascii) {
    if (!_bn) return ascii;
    final sb = StringBuffer();
    for (final unit in ascii.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) {
        sb.write(_bnDigits[unit - 0x30]);
      } else {
        sb.writeCharCode(unit);
      }
    }
    return sb.toString();
  }

  /// Maps Bangla digits (U+09E6..U+09EF) to ASCII; everything else unchanged.
  static String toAsciiDigits(String s) {
    final sb = StringBuffer();
    for (final unit in s.codeUnits) {
      if (unit >= 0x09E6 && unit <= 0x09EF) {
        sb.writeCharCode(0x30 + (unit - 0x09E6));
      } else {
        sb.writeCharCode(unit);
      }
    }
    return sb.toString();
  }

  /// Indian (lakh) grouping: 120000 gives ১,২০,০০০ (bn) / 1,20,000 (en).
  String number(int n) {
    final negative = n < 0;
    final s = (negative ? -n : n).toString();
    final grouped = _lakhGroup(s);
    return '${negative ? '-' : ''}${digits(grouped)}';
  }

  static String _lakhGroup(String s) {
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    parts.add(last3);
    return parts.join(',');
  }

  /// The taka sign and the thin space (U+2009) that follows it: in Hind
  /// Siliguri the sign is easily mistaken for the digit ৬ when it touches it.
  static const String takaSign = '৳';
  static const String takaGap = '\u2009';

  /// ৳ ১,৫০০ / ৳ 1,500 (negative: -৳ ১০০), thin space after the sign.
  String money(int taka) {
    if (taka < 0) return '-$takaSign$takaGap${number(-taka)}';
    return '$takaSign$takaGap${number(taka)}';
  }

  /// ৮৫% / 85%.
  String percent(int p) => '${digits(p.toString())}%';

  /// [m] is 1..12.
  String monthName(int m) => (_bn ? Lexicon.monthsBn : Lexicon.monthsEn)[m - 1];

  String monthShort(int m) =>
      (_bn ? Lexicon.monthsShortBn : Lexicon.monthsShortEn)[m - 1];

  /// [iso] is 1 (Monday) .. 7 (Sunday).
  String weekdayName(int iso) =>
      (_bn ? Lexicon.weekdaysBn : Lexicon.weekdaysEn)[iso - 1];

  String weekdayShort(int iso) =>
      (_bn ? Lexicon.weekdaysShortBn : Lexicon.weekdaysShortEn)[iso - 1];

  /// ৫ নভেম্বর ২০২৬ / 5 Nov 2026.
  String date(LocalDate d) {
    final month = _bn ? monthName(d.month) : monthShort(d.month);
    return '${digits(d.day.toString())} $month ${digits(d.year.toString())}';
  }

  /// ২২ নভে / 22 Nov.
  String dateShort(LocalDate d) =>
      '${digits(d.day.toString())} ${monthShort(d.month)}';

  /// বৃহস্পতিবার, ১৯ নভেম্বর / Thursday, 19 Nov.
  String weekdayDate(LocalDate d) {
    final month = _bn ? monthName(d.month) : monthShort(d.month);
    return '${weekdayName(d.isoWeekday)}, ${digits(d.day.toString())} $month';
  }

  /// নভেম্বর ২০২৬ / November 2026.
  String monthYear(YearMonth ym) =>
      '${monthName(ym.month)} ${digits(ym.year.toString())}';

  /// "অক্টোবর, নভেম্বর ২০২৬" style list of months (ascending, duplicates removed).
  ///
  /// The year is printed only for months whose year differs from
  /// [currentYear], once per run of equal years (after its last month).
  /// Months in [partial] get " (আংশিক)" / " (partial)".
  String monthList(
    List<YearMonth> months, {
    required int currentYear,
    Set<YearMonth> partial = const <YearMonth>{},
  }) {
    if (months.isEmpty) return '';
    final sorted = months.toSet().toList()..sort();
    final items = <String>[];
    for (var i = 0; i < sorted.length; i++) {
      final ym = sorted[i];
      final lastOfYear = i == sorted.length - 1 || sorted[i + 1].year != ym.year;
      final sb = StringBuffer(monthName(ym.month));
      if (lastOfYear && ym.year != currentYear) {
        sb
          ..write(' ')
          ..write(digits(ym.year.toString()));
      }
      if (partial.contains(ym)) {
        sb.write(_bn ? ' (আংশিক)' : ' (partial)');
      }
      items.add(sb.toString());
    }
    return items.join(', ');
  }

  /// বিকাল ৪:৩০ / 4:30 PM. 0 and 1440 are midnight (রাত ১২:০০ / 12:00 AM).
  String time(int minutes) {
    final clock = _clock12(minutes);
    if (_bn) return '${dayPeriod(minutes)} ${digits(clock)}';
    return '$clock ${dayPeriod(minutes)}';
  }

  /// Each end takes its own period; the period prefix is shown once when both
  /// ends share it (plan section 1 #23).
  ///
  /// bn: `সকাল ১০:০০–১১:০০`, `সকাল ১১:০০–দুপুর ১২:০০`.
  /// en: `4:00–5:00 PM`, `11:00 AM–12:00 PM`.
  String timeRange(int start, int end) {
    final a = _clock12(start);
    final b = _clock12(end);
    final pa = dayPeriod(start);
    final pb = dayPeriod(end);
    if (_bn) {
      if (pa == pb) return '$pa ${digits(a)}–${digits(b)}';
      return '$pa ${digits(a)}–$pb ${digits(b)}';
    }
    if (pa == pb) return '$a–$b $pa';
    return '$a $pa–$b $pb';
  }

  /// bn: ভোর / সকাল / দুপুর / বিকাল / সন্ধ্যা / রাত (plan section 1 #22).
  /// en: AM / PM.
  String dayPeriod(int minutes) {
    if (_bn) return Lexicon.periodsBn[Lexicon.periodIndex(minutes)];
    return minutes % 1440 < 720 ? 'AM' : 'PM';
  }

  /// "5th" style ordinal: bn ১ম ২য় ৩য় ৪র্থ ৫ম ৬ষ্ঠ ৭ম ৮ম ৯ম ১০ম ১১তম ...,
  /// en 1st 2nd 3rd 4th ... 11th 12th 13th ... 21st.
  String ordinal(int n) {
    if (_bn) {
      const small = {
        1: 'ম',
        2: 'য়',
        3: 'য়',
        4: 'র্থ',
        5: 'ম',
        6: 'ষ্ঠ',
        7: 'ম',
        8: 'ম',
        9: 'ম',
        10: 'ম',
      };
      return '${digits(n.toString())}${small[n] ?? 'তম'}';
    }
    final mod100 = n % 100;
    String suffix;
    if (mod100 >= 11 && mod100 <= 13) {
      suffix = 'th';
    } else {
      switch (n % 10) {
        case 1:
          suffix = 'st';
        case 2:
          suffix = 'nd';
        case 3:
          suffix = 'rd';
        default:
          suffix = 'th';
      }
    }
    return '$n$suffix';
  }

  /// Day-of-due label used by the dues UI: ৫ম দিন / 5th day.
  String ordinalDay(int n) => _bn ? '${ordinal(n)} দিন' : '${ordinal(n)} day';

  /// 12-hour clock text as ASCII, e.g. "4:30"; hour 0 and 12 print as 12.
  static String _clock12(int minutes) {
    final m = minutes % 1440;
    final h24 = m ~/ 60;
    final mm = (m % 60).toString().padLeft(2, '0');
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:$mm';
  }
}
