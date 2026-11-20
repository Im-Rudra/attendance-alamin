// Public surface of the payments feature (plan section 1 #32). STUB by M5-A;
// bodies by M7-B. Signatures are frozen.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/core/time/year_month.dart';

/// Collect-payment sheet; returns the receipt id, or null.
Future<String?> showCollectPaymentSheet(BuildContext context, {required String studentId, String? enrollmentId}) async =>
    null;

/// Inline payment panel (desktop dues ‖ panel).
class CollectPaymentPanel extends StatelessWidget {
  const CollectPaymentPanel({super.key, required this.studentId, this.enrollmentId});

  final String studentId;
  final String? enrollmentId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Builds the receipt text from the template and shares it.
Future<void> shareReceipt(BuildContext context, {required String receiptId}) async {}

/// Waive one month's fee; true when waived.
Future<bool> showWaiveDialog(BuildContext context, {required String enrollmentId, required YearMonth month}) async =>
    false;

/// Payment history of one student (profile).
class PaymentHistoryList extends StatelessWidget {
  const PaymentHistoryList({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
