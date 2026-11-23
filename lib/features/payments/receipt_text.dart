// Receipt text and month wording of the payments feature (Product 3.4, 5).
//
// The receipt comes from the editable template (default or the teacher's own)
// with the receipt placeholders filled. Digits follow the app language: Bangla
// digits in bn, Latin digits in en. No widgets here.

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/templates/template_engine.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// What a receipt says, before the template is applied.
class ReceiptFacts {
  const ReceiptFacts({
    required this.studentName,
    required this.batchName,
    required this.rows,
    required this.partialMonths,
    required this.remaining,
    this.roll,
    this.guardianPhone,
  });

  final String studentName;
  final String? roll;

  /// The guardian's phone, printed on the slip; null / blank when unknown.
  final String? guardianPhone;
  final String batchName;

  /// The receipt's allocation rows, one per month.
  final List<Payment> rows;

  /// Months of this receipt that are still only partly paid.
  final Set<YearMonth> partialMonths;

  /// Money still due in this enrollment (open months whose due date arrived).
  final int remaining;

  int get total => rows.fold(0, (int s, Payment p) => s + p.amount);

  /// Slip number of the receipt (`2026-0007`), or '' when it has none yet.
  String get receiptNo {
    for (final Payment p in rows) {
      final String? no = p.receiptNo;
      if (no != null && no.isNotEmpty) return no;
    }
    return '';
  }
  List<YearMonth> get months => <YearMonth>[for (final Payment p in rows) p.billingMonth];
}

/// Months of [rows] that are still partial in [dues].
Set<YearMonth> partialMonthsOf(List<Payment> rows, EnrollmentDues? dues) {
  if (dues == null) return const <YearMonth>{};
  final Set<YearMonth> mine = <YearMonth>{for (final Payment p in rows) p.billingMonth};
  return <YearMonth>{
    for (final MonthDue md in dues.months)
      if (mine.contains(md.month) && md.state == MonthState.partial) md.month,
  };
}

/// The receipt message for [facts] from [template] (Product 5). Placeholders:
/// center, student, id, batch, months, amount, method, date, remaining_line,
/// receipt_no (schema v2 slip number, digits in the app language).
/// An empty center, id or receipt number removes its surrounding
/// " — {center}" / " ({id})" / " ({receipt_no})" / " #{receipt_no}" /
/// " নং {receipt_no}" so the
/// message never shows empty brackets.
String renderReceiptText({
  required ReceiptFacts facts,
  required String template,
  required String center,
  required AppFormat fmt,
  required AppLocalizations l10n,
  required LocalDate today,
  required String methodLabel,
  required LocalDate paidOn,
}) {
  var text = template;
  final String id = (facts.roll ?? '').trim();
  final String centerName = center.trim();
  if (id.isEmpty) text = text.replaceAll(' ({id})', '');
  if (centerName.isEmpty) text = text.replaceAll(' — {center}', '');
  final String receiptNo = facts.receiptNo;
  if (receiptNo.isEmpty) {
    text = text
        .replaceAll(' ({receipt_no})', '')
        .replaceAll(' #{receipt_no}', '')
        .replaceAll(' নং {receipt_no}', '');
  }
  final String remainingLine =
      facts.remaining > 0 ? l10n.payReceiptRemaining(fmt.money(facts.remaining)) : l10n.payReceiptAllPaid;
  final String filled = fillTemplate(text, <String, String>{
    'center': centerName,
    'student': facts.studentName,
    'id': fmt.digits(id),
    'batch': facts.batchName,
    'months': fmt.monthList(facts.months, currentYear: today.year, partial: facts.partialMonths),
    'amount': fmt.number(facts.total),
    'method': methodLabel,
    'date': fmt.date(paidOn),
    'remaining_line': remainingLine,
    'receipt_no': fmt.digits(receiptNo),
  });
  return filled;
}

/// "অক্টোবর" / "অক্টোবর–নভেম্বর" / "অক্টোবর, ডিসেম্বর": the months of a payment
/// as a short span. Consecutive months become a range; the year shows only
/// for a year that is not [currentYear].
String monthsSpan(AppFormat fmt, List<YearMonth> months, {required int currentYear}) {
  final List<YearMonth> sorted = months.toSet().toList()..sort();
  if (sorted.isEmpty) return '';
  if (sorted.length == 1) return fmt.monthList(sorted, currentYear: currentYear);
  var consecutive = true;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].toInt() != sorted[i - 1].addMonths(1).toInt()) consecutive = false;
  }
  if (!consecutive) return fmt.monthList(sorted, currentYear: currentYear);
  final YearMonth first = sorted.first;
  final YearMonth last = sorted.last;
  final String head = first.year == last.year
      ? fmt.monthName(first.month)
      : fmt.monthList(<YearMonth>[first], currentYear: currentYear);
  final String tail = fmt.monthList(<YearMonth>[last], currentYear: currentYear);
  return '$head–$tail';
}

/// Bangla possessive of a month span ("অক্টোবর" gives "অক্টোবরের", "জানুয়ারি"
/// gives "জানুয়ারির", "জুলাই" gives "জুলাইয়ের", "মে" gives "মের", a trailing
/// year gives "২০২৭-এর"). English text is returned unchanged.
String possessive(String span, {required bool bangla}) {
  if (!bangla || span.isEmpty) return span;
  final int last = span.runes.last;
  final bool digit = (last >= 0x30 && last <= 0x39) || (last >= 0x09E6 && last <= 0x09EF);
  if (digit) return '${span}-এর';
  if (last == 0x09BF) return '${span}র'; // ি
  if (last == 0x0987) return '${span}য়ের'; // ই
  if (last == 0x09C7) return '${span}র'; // ে
  return '${span}ের';
}
