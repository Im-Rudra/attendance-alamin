import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

/// Income that is not a monthly fee (exam fee, book, ...). F22.
class OtherIncome {
  const OtherIncome({
    required this.id,
    required this.label,
    required this.amount,
    required this.paidOn,
    required this.method,
    this.studentId,
    this.note,
  });

  final String id;
  final String? studentId;
  final String label;
  final int amount;
  final LocalDate paidOn;
  final PaymentMethod method;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is OtherIncome &&
      other.id == id &&
      other.studentId == studentId &&
      other.label == label &&
      other.amount == amount &&
      other.paidOn == paidOn &&
      other.method == method &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(id, studentId, label, amount, paidOn, method, note);

  @override
  String toString() => 'OtherIncome($id, $label, $amount)';
}
