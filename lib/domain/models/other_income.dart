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
    this.placeId,
  });

  final String id;
  final String? studentId;
  final String label;
  final int amount;
  final LocalDate paidOn;
  final PaymentMethod method;
  final String? note;

  /// The place it belongs to (schema v2); null = general (no place).
  final String? placeId;

  @override
  bool operator ==(Object other) =>
      other is OtherIncome &&
      other.id == id &&
      other.studentId == studentId &&
      other.label == label &&
      other.amount == amount &&
      other.paidOn == paidOn &&
      other.method == method &&
      other.note == note &&
      other.placeId == placeId;

  @override
  int get hashCode =>
      Object.hash(id, studentId, label, amount, paidOn, method, note, placeId);

  @override
  String toString() => 'OtherIncome($id, $label, $amount)';
}
