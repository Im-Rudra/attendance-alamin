// Public surface of the payments feature (plan section 1 #32). Signatures are
// frozen; the bodies live in widgets/ and controllers/ (M7-B).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/features/payments/widgets/collect_payment_panel.dart';
import 'package:attendance_alamin/features/payments/widgets/collect_payment_sheet.dart';
import 'package:attendance_alamin/features/payments/widgets/payment_history_list.dart';
import 'package:attendance_alamin/features/payments/widgets/receipt_preview.dart';
import 'package:attendance_alamin/features/payments/widgets/waive_dialog.dart';

/// Collect-payment sheet; returns the receipt id, or null.
Future<String?> showCollectPaymentSheet(BuildContext context, {required String studentId, String? enrollmentId}) =>
    openCollectPaymentSheet(context, studentId: studentId, enrollmentId: enrollmentId);

/// Inline payment panel (desktop dues ‖ panel).
class CollectPaymentPanel extends StatelessWidget {
  const CollectPaymentPanel({super.key, required this.studentId, this.enrollmentId});

  final String studentId;
  final String? enrollmentId;

  @override
  Widget build(BuildContext context) => CollectPaymentPanelBody(studentId: studentId, enrollmentId: enrollmentId);
}

/// Builds the receipt text from the template and shares it.
Future<void> shareReceipt(BuildContext context, {required String receiptId}) =>
    shareReceiptNow(context, receiptId: receiptId);

/// Waive one month's fee; true when waived.
Future<bool> showWaiveDialog(BuildContext context, {required String enrollmentId, required YearMonth month}) =>
    runWaiveDialog(context, enrollmentId: enrollmentId, month: month);

/// Payment history of one student (profile).
class PaymentHistoryList extends StatelessWidget {
  const PaymentHistoryList({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) => PaymentHistoryBody(studentId: studentId);
}
