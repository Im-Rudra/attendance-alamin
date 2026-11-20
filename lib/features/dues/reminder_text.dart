// The dues reminder message (Product 3.5 / section 5, scenario 14): the
// teacher's template (or the default) filled with the student's open months,
// and every digit written in the language of the app (Bangla digits in bn,
// Latin in en).

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/templates/template_engine.dart';
import 'package:attendance_alamin/core/time/year_month.dart';

final RegExp _phoneInParens = RegExp(r'\s*\(\s*\{teacher_phone\}\s*\)');

/// Fills [template] (the stored custom text or the language's default).
///
/// [months] are the open due months; [amount] is whole taka. [currentYear]
/// decides which month names get a year ("অক্টোবর, নভেম্বর" within the year).
/// An empty [teacherPhone] drops the " ({teacher_phone})" tail instead of
/// leaving "()" behind.
String buildReminderText({
  required Lang lang,
  required String template,
  required String student,
  required String batches,
  required List<YearMonth> months,
  required int amount,
  required int currentYear,
  required String center,
  required String teacherPhone,
}) {
  final AppFormat fmt = AppFormat(lang);
  final String phone = teacherPhone.trim();
  String t = template;
  if (phone.isEmpty) t = t.replaceAll(_phoneInParens, '');
  final String filled = fillTemplate(t, <String, String>{
    'student': student,
    'batch': batches,
    'months': fmt.monthList(months, currentYear: currentYear),
    'amount': fmt.number(amount),
    'center': center,
    'teacher_phone': phone,
  });
  return fmt.digits(AppFormat.toAsciiDigits(filled));
}
