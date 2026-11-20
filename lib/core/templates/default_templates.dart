import 'package:attendance_alamin/core/format/lang.dart';

/// Default message templates (01-product.md section 5, verbatim). They live in
/// Dart, not ARB, because `{placeholders}` would be parsed by gen-l10n.
///
/// Reminder placeholders: `{student}` `{batch}` `{months}` `{amount}`
/// `{center}` `{teacher_phone}`.
/// Receipt placeholders: `{center}` `{student}` `{id}` `{batch}` `{months}`
/// `{amount}` `{method}` `{date}` `{remaining_line}`.
abstract final class DefaultTemplates {
  static const reminderBn = 'সম্মানিত অভিভাবক,\n'
      '{student}-এর {batch} ব্যাচের {months} মাসের বেতন মোট ৳{amount} এখনো বাকি আছে। '
      'অনুগ্রহ করে দ্রুত পরিশোধ করুন।\n'
      'ধন্যবাদ — {center} ({teacher_phone})';

  static const reminderEn =
      "Dear Guardian, {student}'s fee for {batch} for {months} "
      '(total ৳{amount}) is still due. Please pay at your earliest. '
      'Thank you — {center} ({teacher_phone})';

  static const receiptBn = 'রসিদ — {center}\n'
      'শিক্ষার্থী: {student} ({id})\n'
      'ব্যাচ: {batch}\n'
      'মাস: {months}\n'
      'জমা: ৳{amount} ({method}), তারিখ {date}\n'
      '{remaining_line}\n'
      'ধন্যবাদ।';

  static const receiptEn = 'Receipt — {center}\n'
      'Student: {student} ({id})\n'
      'Batch: {batch}\n'
      'Months: {months}\n'
      'Paid: ৳{amount} ({method}), date {date}\n'
      '{remaining_line}\n'
      'Thank you.';

  static String reminder(Lang lang) =>
      lang == Lang.bn ? reminderBn : reminderEn;

  static String receipt(Lang lang) => lang == Lang.bn ? receiptBn : receiptEn;
}
