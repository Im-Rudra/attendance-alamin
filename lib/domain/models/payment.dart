import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

export 'package:attendance_alamin/domain/models/enums.dart' show PaymentMethod;

/// One row per billing month (an allocation). Rows that were entered together
/// share a [receiptId] (one payment record / receipt).
class Payment {
  const Payment({
    required this.id,
    required this.receiptId,
    required this.studentId,
    required this.enrollmentId,
    required this.batchId,
    required this.billingMonth,
    required this.amount,
    required this.paidOn,
    required this.method,
    this.note,
    this.waived = false,
    this.receiptNo,
  });

  final String id;
  final String receiptId;
  final String studentId;
  final String enrollmentId;
  final String batchId;
  final YearMonth billingMonth;
  final int amount;
  final LocalDate paidOn;
  final PaymentMethod method;
  final String? note;
  final bool waived;

  /// Slip number of the receipt (`2026-0007`, see `ReceiptNo`), the same on
  /// every row of the receipt. Null on waivers and on receipts not numbered
  /// yet (schema v2 numbers every receipt on save / migration / import).
  final String? receiptNo;

  @override
  bool operator ==(Object other) =>
      other is Payment &&
      other.id == id &&
      other.receiptId == receiptId &&
      other.studentId == studentId &&
      other.enrollmentId == enrollmentId &&
      other.batchId == batchId &&
      other.billingMonth == billingMonth &&
      other.amount == amount &&
      other.paidOn == paidOn &&
      other.method == method &&
      other.note == note &&
      other.waived == waived &&
      other.receiptNo == receiptNo;

  @override
  int get hashCode => Object.hash(id, receiptId, studentId, enrollmentId,
      batchId, billingMonth, amount, paidOn, method, note, waived, receiptNo);

  @override
  String toString() => 'Payment($id, $billingMonth, $amount)';
}
