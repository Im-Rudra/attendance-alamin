import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/drift/people_common.dart';
import 'package:attendance_alamin/data/repositories/other_income_repository.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:drift/drift.dart' hide Batch;

class DriftOtherIncomeRepository implements OtherIncomeRepository {
  DriftOtherIncomeRepository(this._db, this._stamper);

  final AppDatabase _db;
  final SyncStamper _stamper;

  @override
  Stream<List<OtherIncome>> watchBetween(LocalDate from, LocalDate to) {
    final q = _db.select(_db.otherIncome)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.paidOn.isBiggerOrEqualValue(from.toIso()) &
          t.paidOn.isSmallerOrEqualValue(to.toIso()))
      ..orderBy([
        (t) => OrderingTerm.asc(t.paidOn),
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    return q.watch().map((rows) => rows.map(otherIncomeFromRow).toList());
  }

  static String _label(String raw) {
    try {
      return Validators.name(raw);
    } on ValidationException catch (e) {
      throw ValidationException(e.code, field: 'label');
    }
  }

  @override
  Future<String> add(OtherIncome draft) async {
    final label = _label(draft.label);
    if (draft.amount <= 0) {
      throw const ValidationException(ErrorCodes.amountInvalid,
          field: 'amount');
    }
    checkAmount(draft.amount);
    final method = checkMethod(draft.method);
    return _db.transaction(() async {
      final studentId = draft.studentId;
      if (studentId != null) await requireStudent(_db, studentId);
      final id = Ids.v4();
      final now = _stamper.nowMs();
      final row = OtherIncome(
        id: id,
        studentId: studentId,
        label: label,
        amount: draft.amount,
        paidOn: draft.paidOn,
        method: method,
        note: trimOrNull(draft.note),
      );
      await _db.into(_db.otherIncome).insert(otherIncomeToCompanion(row)
          .copyWith(
              createdAt: Value(now),
              updatedAt: Value(now),
              deviceId: Value(_stamper.deviceId)));
      return id;
    });
  }

  @override
  Future<void> softDelete(String id) {
    return _db.transaction(() async {
      final n = await tombstoneId(_db, _stamper, _db.otherIncome, id);
      if (n == 0) throw notFound('other income $id');
    });
  }
}
