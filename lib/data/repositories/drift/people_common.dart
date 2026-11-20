// Helpers shared by the M4-B drift repositories (people & money).

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:drift/drift.dart' hide Batch;

/// Today's center date, read from the stamper's clock.
LocalDate todayOf(SyncStamper stamper, CenterTime center) =>
    center.dateOfEpochMs(stamper.nowMs());

/// Trimmed text or `null` when blank.
String? trimOrNull(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// Money amount 0..1,000,000 (plan 2.9). Throws [ValidationException]
/// `amountInvalid` (negative) / `amountTooLarge`.
int checkAmount(int amount, {String field = 'amount'}) {
  if (amount < 0) {
    throw ValidationException(ErrorCodes.amountInvalid, field: field);
  }
  if (amount > Validators.amountMax) {
    throw ValidationException(ErrorCodes.amountTooLarge, field: field);
  }
  return amount;
}

/// A method the DB CHECK accepts: a built-in or `custom:<1..20 chars>`.
/// Throws [ValidationException] (field `method`) otherwise.
PaymentMethod checkMethod(PaymentMethod m) {
  try {
    return PaymentMethod.parse(m.code);
  } on FormatException {
    final label = m.customLabel;
    if (label != null && label.length > PaymentMethod.maxCustomLabelLength) {
      throw const ValidationException(ErrorCodes.nameTooLong, field: 'method');
    }
    throw const ValidationException(ErrorCodes.nameRequired, field: 'method');
  }
}

/// Start/end minutes the DB CHECK accepts (`0 <= start < end <= 1440`).
void checkTimes(int startMin, int endMin) {
  if (startMin < 0 || startMin >= endMin || endMin > 1440) {
    throw const ValidationException(ErrorCodes.slotTimeInvalid, field: 'time');
  }
}

NotFoundException notFound(String what) =>
    NotFoundException(ErrorCodes.notFound, detail: what);

/// Numeric value of a roll ("07", "৭"), `null` when it is not all digits.
int? rollNumber(String? roll) {
  if (roll == null) return null;
  final s = AppFormat.toAsciiDigits(roll.trim());
  if (s.isEmpty || s.length > 9 || !RegExp(r'^\d+$').hasMatch(s)) return null;
  return int.parse(s);
}

/// Numeric rolls first (by value), then other rolls (by text), then no roll;
/// ties by name (case-insensitive), then id.
int compareByRollThenName(Student a, Student b) {
  final ra = rollNumber(a.roll);
  final rb = rollNumber(b.roll);
  if (ra != null && rb != null) {
    if (ra != rb) return ra.compareTo(rb);
  } else if (ra != null) {
    return -1;
  } else if (rb != null) {
    return 1;
  } else {
    final sa = a.roll;
    final sb = b.roll;
    if (sa != null && sb == null) return -1;
    if (sa == null && sb != null) return 1;
    if (sa != null && sb != null) {
      final c = sa.compareTo(sb);
      if (c != 0) return c;
    }
  }
  final n = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  if (n != 0) return n;
  final exact = a.name.compareTo(b.name);
  if (exact != 0) return exact;
  return a.id.compareTo(b.id);
}

/// Tombstones the live rows of [table] matching [where] (SQL, `?` params in
/// [args]) with the stamping rule of plan 2.6 applied per row:
/// `deleted_at = now`, `updated_at = max(now, updated_at + 1)`,
/// `rev = rev + 1`, `device_id`. Returns the number of rows tombstoned.
Future<int> tombstoneWhere(
  AppDatabase db,
  SyncStamper stamper,
  TableInfo<Table, dynamic> table,
  String where,
  List<Variable> args,
) {
  final now = stamper.nowMs();
  return db.customUpdate(
    'UPDATE ${table.actualTableName} SET deleted_at = ?, '
    'updated_at = MAX(?, updated_at + 1), rev = rev + 1, device_id = ? '
    'WHERE deleted_at IS NULL AND ($where)',
    variables: [
      Variable.withInt(now),
      Variable.withInt(now),
      Variable.withString(stamper.deviceId),
      ...args,
    ],
    updates: {table},
    updateKind: UpdateKind.update,
  );
}

/// Tombstones one row by id (no-op when it is missing or already deleted).
Future<int> tombstoneId(AppDatabase db, SyncStamper stamper,
        TableInfo<Table, dynamic> table, String id) =>
    tombstoneWhere(db, stamper, table, 'id = ?', [Variable.withString(id)]);

/// Live enrollment row or [NotFoundException].
Future<EnrollmentRow> requireEnrollment(AppDatabase db, String id) async {
  final row = await (db.select(db.enrollments)
        ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
      .getSingleOrNull();
  if (row == null) throw notFound('enrollment $id');
  return row;
}

/// Live student row or [NotFoundException].
Future<StudentRow> requireStudent(AppDatabase db, String id) async {
  final row = await (db.select(db.students)
        ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
      .getSingleOrNull();
  if (row == null) throw notFound('student $id');
  return row;
}

/// Live batch row or [NotFoundException].
Future<BatchRow> requireBatch(AppDatabase db, String id) async {
  final row = await (db.select(db.batches)
        ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
      .getSingleOrNull();
  if (row == null) throw notFound('batch $id');
  return row;
}

/// Writes (or revives) the waiver row of ([e], [month]): id
/// `Ids.waiver(e.id, month)`, `receipt_id = id`, `waived = 1`, `amount = 0`,
/// method `other`, note = reason. An identical live waiver is left alone.
Future<void> writeWaiver(
  AppDatabase db,
  SyncStamper stamper,
  EnrollmentRow e,
  YearMonth month, {
  required LocalDate on,
  String? reason,
}) async {
  final id = Ids.waiver(e.id, month);
  final note = trimOrNull(reason);
  final existing = await (db.select(db.payments)..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  final waiver = Payment(
    id: id,
    receiptId: id,
    studentId: e.studentId,
    enrollmentId: e.id,
    batchId: e.batchId,
    billingMonth: month,
    amount: 0,
    paidOn: on,
    method: PaymentMethod.other,
    note: note,
    waived: true,
  );
  if (existing == null) {
    final now = stamper.nowMs();
    await db.into(db.payments).insert(paymentToCompanion(waiver).copyWith(
          createdAt: Value(now),
          updatedAt: Value(now),
          deviceId: Value(stamper.deviceId),
        ));
    return;
  }
  if (existing.deletedAt == null && existing.waived && existing.note == note) {
    return;
  }
  await (db.update(db.payments)..where((t) => t.id.equals(id)))
      .write(paymentToCompanion(waiver).copyWith(
    deletedAt: const Value(null),
    updatedAt: Value(stamper.nextUpdatedAt(existing.updatedAt)),
    rev: Value(stamper.nextRev(existing.rev)),
    deviceId: Value(stamper.deviceId),
  ));
}
