/// Product-owned spellings (01-product.md section 5). Pure Dart, no ARB.
abstract final class Lexicon {
  static const monthsBn = [
    'জানুয়ারি',
    'ফেব্রুয়ারি',
    'মার্চ',
    'এপ্রিল',
    'মে',
    'জুন',
    'জুলাই',
    'আগস্ট',
    'সেপ্টেম্বর',
    'অক্টোবর',
    'নভেম্বর',
    'ডিসেম্বর',
  ];

  static const monthsShortBn = [
    'জানু',
    'ফেব্রু',
    'মার্চ',
    'এপ্রি',
    'মে',
    'জুন',
    'জুলা',
    'আগ',
    'সেপ্টে',
    'অক্টো',
    'নভে',
    'ডিসে',
  ];

  /// Index 0 = Monday (ISO weekday 1) ... index 6 = Sunday (ISO weekday 7).
  static const weekdaysBn = [
    'সোমবার',
    'মঙ্গলবার',
    'বুধবার',
    'বৃহস্পতিবার',
    'শুক্রবার',
    'শনিবার',
    'রবিবার',
  ];

  static const weekdaysShortBn = [
    'সোম',
    'মঙ্গল',
    'বুধ',
    'বৃহঃ',
    'শুক্র',
    'শনি',
    'রবি',
  ];

  static const monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const monthsShortEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const weekdaysEn = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const weekdaysShortEn = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Day-period words, in picker order (plan section 1 #22).
  static const periodsBn = [
    'ভোর',
    'সকাল',
    'দুপুর',
    'বিকাল',
    'সন্ধ্যা',
    'রাত',
  ];

  static const periodVor = 0;
  static const periodSokal = 1;
  static const periodDupur = 2;
  static const periodBikal = 3;
  static const periodSondha = 4;
  static const periodRat = 5;

  /// Index into [periodsBn] for [minutes] past midnight (1440 counts as 0:00).
  ///
  /// ভোর 04:00-05:59 · সকাল 06:00-11:59 · দুপুর 12:00-14:59 ·
  /// বিকাল 15:00-17:59 · সন্ধ্যা 18:00-19:59 · রাত 20:00-03:59.
  static int periodIndex(int minutes) {
    final m = minutes % 1440;
    if (m >= 240 && m < 360) return periodVor;
    if (m >= 360 && m < 720) return periodSokal;
    if (m >= 720 && m < 900) return periodDupur;
    if (m >= 900 && m < 1080) return periodBikal;
    if (m >= 1080 && m < 1200) return periodSondha;
    return periodRat;
  }
}
