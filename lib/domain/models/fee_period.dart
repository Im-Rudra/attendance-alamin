import 'package:attendance_alamin/core/time/year_month.dart';

/// A fee effective from [effective] (inclusive) until the next period.
/// [amount] is `null` only for a cleared enrollment override.
class FeePeriod {
  const FeePeriod({required this.effective, this.amount});

  final YearMonth effective;
  final int? amount;

  @override
  bool operator ==(Object other) =>
      other is FeePeriod &&
      other.effective == effective &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(effective, amount);

  @override
  String toString() => 'FeePeriod($effective, $amount)';
}
