import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';

/// Income that is not a monthly fee (F22).
abstract interface class OtherIncomeRepository {
  /// Live rows with `from <= paidOn <= to`, by date.
  Stream<List<OtherIncome>> watchBetween(LocalDate from, LocalDate to);

  /// Validates and stores [draft] under a new id (`draft.id` is ignored);
  /// returns the id.
  Future<String> add(OtherIncome draft);
  Future<void> softDelete(String id);
}
