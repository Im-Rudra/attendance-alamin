// Receipt text of an other-income payment (F22): plain lines in the app
// language, ready for the share sheet.

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

String otherIncomeReceiptText({
  required AppLocalizations l10n,
  required AppFormat fmt,
  required OtherIncome income,
  required String methodLabel,
  String centerName = '',
  String? studentName,
}) {
  final List<String> lines = <String>[
    if (centerName.trim().isNotEmpty) centerName.trim(),
    l10n.extraReceiptTitle(income.label),
    l10n.extraReceiptAmount(fmt.money(income.amount)),
    l10n.extraReceiptDate(fmt.date(income.paidOn)),
    l10n.extraReceiptMethod(methodLabel),
    if (studentName != null && studentName.trim().isNotEmpty) l10n.extraReceiptStudent(studentName.trim()),
    l10n.extraReceiptThanks,
  ];
  return lines.join('\n');
}
