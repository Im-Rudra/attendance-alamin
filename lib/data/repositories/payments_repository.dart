import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/payment.dart';

/// Payments (one receipt = one or more allocation rows sharing `receiptId`)
/// and waivers (plan M4-B, Product 3.3/3.4, plan 1 #9).
///
/// Waivers are payment rows with `waived = true`, `amount = 0` and
/// `receiptId == id`; they appear in [watchAll] / [watchForStudent] /
/// [watchFacts] but are not receipts ([receipt], [updateReceipt] and
/// [deleteReceipt] ignore them).
abstract interface class PaymentsRepository {
  /// Live rows, newest payment date first.
  Stream<List<Payment>> watchAll();
  Stream<List<Payment>> watchForStudent(String studentId);
  Stream<List<PaymentFact>> watchFacts();

  /// Validates the allocations with `DuesEngine.validateAllocations` (dues
  /// for today, 12 months ahead) and writes one row per month, all with one
  /// new receipt id, in one transaction. Returns the receipt id.
  Future<String> record(PaymentDraft d);

  /// Re-validates against dues built WITHOUT this receipt's rows, then
  /// replaces its rows atomically (same month = same row, kept id).
  Future<void> updateReceipt(String receiptId, PaymentDraft d);

  /// Tombstones every row of the receipt.
  Future<void> deleteReceipt(String receiptId);

  /// Live rows of one receipt, by month.
  Future<List<Payment>> receipt(String receiptId);

  /// Marks a billable month waived (id = `Ids.waiver`); repeat calls update
  /// the reason.
  Future<void> waive(String enrollmentId, YearMonth month, {String? reason});
  Future<void> unwaive(String enrollmentId, YearMonth month);
}
