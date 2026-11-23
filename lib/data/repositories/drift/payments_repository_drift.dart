import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/db_queries.dart';
import 'package:attendance_alamin/data/db/mappers.dart';
import 'package:attendance_alamin/data/db/schema_v2.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/drift/people_common.dart';
import 'package:attendance_alamin/data/repositories/payments_repository.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:drift/drift.dart' hide Batch;

/// A validated draft: the enrollment row and one amount per month (ascending).
class _CheckedDraft {
  const _CheckedDraft(this.enrollment, this.byMonth, this.method, this.note);

  final EnrollmentRow enrollment;
  final List<(YearMonth, int)> byMonth;
  final PaymentMethod method;
  final String? note;
}

class DriftPaymentsRepository implements PaymentsRepository {
  DriftPaymentsRepository(this._db, this._stamper,
      {CenterTime center = CenterTime.dhaka})
      : _center = center;

  final AppDatabase _db;
  final SyncStamper _stamper;
  final CenterTime _center;

  /// Newest payment date first, then receipt, then month (tie-break of
  /// [_history]).
  static int _historyOrder(Payment a, Payment b) {
    final d = b.paidOn.compareTo(a.paidOn);
    if (d != 0) return d;
    final r = a.receiptId.compareTo(b.receiptId);
    if (r != 0) return r;
    final m = a.billingMonth.compareTo(b.billingMonth);
    if (m != 0) return m;
    return a.id.compareTo(b.id);
  }

  /// On one payment date the receipt recorded last comes first, so the
  /// list is in recording order (the receipt view reads the balance as it
  /// stood at a receipt from it, QA-05).
  static List<Payment> _history(List<PaymentRow> rows) {
    final recordedAt = <String, int>{};
    for (final r in rows) {
      final seen = recordedAt[r.receiptId];
      if (seen == null || r.createdAt < seen) {
        recordedAt[r.receiptId] = r.createdAt;
      }
    }
    return rows.map(paymentFromRow).toList()
      ..sort((a, b) {
        final d = b.paidOn.compareTo(a.paidOn);
        if (d != 0) return d;
        final t = (recordedAt[b.receiptId] ?? 0)
            .compareTo(recordedAt[a.receiptId] ?? 0);
        if (t != 0) return t;
        return _historyOrder(a, b);
      });
  }

  @override
  Stream<List<Payment>> watchAll() =>
      (_db.select(_db.payments)..where((t) => t.deletedAt.isNull()))
          .watch()
          .map(_history);

  @override
  Stream<List<Payment>> watchForStudent(String studentId) =>
      (_db.select(_db.payments)
            ..where(
                (t) => t.studentId.equals(studentId) & t.deletedAt.isNull()))
          .watch()
          .map(_history);

  @override
  Stream<List<PaymentFact>> watchFacts() =>
      (_db.select(_db.payments)..where((t) => t.deletedAt.isNull()))
          .watch()
          .map((rows) => [
                for (final r in rows)
                  PaymentFact(
                    enrollmentId: r.enrollmentId,
                    month: YearMonth.fromInt(r.billingMonth),
                    amount: r.amount,
                    waived: r.waived,
                  ),
              ]);

  /// Validates [d] inside the current transaction. Dues are computed for
  /// today with 12 months ahead from the live rows of the enrollment, minus
  /// the rows of [excludeReceiptId] (dues-engine caller rule for edits).
  Future<_CheckedDraft> _check(PaymentDraft d, {String? excludeReceiptId}) async {
    final method = checkMethod(d.method);
    if (d.total > Validators.amountMax) {
      throw const ValidationException(ErrorCodes.amountTooLarge,
          field: 'amount');
    }
    final e = await requireEnrollment(_db, d.enrollmentId);
    if (e.studentId != d.studentId) {
      throw notFound('enrollment ${d.enrollmentId} of student ${d.studentId}');
    }
    EnrollmentTerms? terms;
    for (final t in await loadEnrollmentTerms(_db, _center)) {
      if (t.enrollmentId == e.id) terms = t;
    }
    if (terms == null) throw notFound('enrollment terms ${e.id}');

    final rows = await (_db.select(_db.payments)
          ..where((t) => t.enrollmentId.equals(e.id) & t.deletedAt.isNull()))
        .get();
    final facts = [
      for (final r in rows)
        if (r.receiptId != excludeReceiptId)
          PaymentFact(
            enrollmentId: r.enrollmentId,
            month: YearMonth.fromInt(r.billingMonth),
            amount: r.amount,
            waived: r.waived,
          ),
    ];
    final dues = DuesEngine.forEnrollment(
      terms: terms,
      payments: facts,
      today: todayOf(_stamper, _center),
      aheadMonths: 12,
    );
    DuesEngine.validateAllocations(dues: dues, allocations: d.allocations);

    final sums = <int, int>{};
    for (final a in d.allocations) {
      final k = a.month.toInt();
      sums[k] = (sums[k] ?? 0) + a.amount;
    }
    final months = sums.keys.toList()..sort();
    return _CheckedDraft(
      e,
      [for (final m in months) (YearMonth.fromInt(m), sums[m] ?? 0)],
      method,
      trimOrNull(d.note),
    );
  }

  Payment _row(String id, String receiptId, PaymentDraft d, _CheckedDraft c,
          YearMonth month, int amount, String? receiptNo) =>
      Payment(
        id: id,
        receiptId: receiptId,
        studentId: c.enrollment.studentId,
        enrollmentId: c.enrollment.id,
        batchId: c.enrollment.batchId,
        billingMonth: month,
        amount: amount,
        paidOn: d.paidOn,
        method: c.method,
        note: c.note,
        receiptNo: receiptNo,
      );

  Future<void> _insert(Payment p) {
    final now = _stamper.nowMs();
    return _db.into(_db.payments).insert(paymentToCompanion(p).copyWith(
          createdAt: Value(now),
          updatedAt: Value(now),
          deviceId: Value(_stamper.deviceId),
        ));
  }

  @override
  Future<String> record(PaymentDraft d) {
    return _db.transaction(() async {
      final c = await _check(d);
      final receiptId = Ids.v4();
      // Slip number, given out inside this transaction (never reused).
      final receiptNo = await allocateReceiptNo(_db, d.paidOn);
      for (final (month, amount) in c.byMonth) {
        await _insert(_row(Ids.v4(), receiptId, d, c, month, amount, receiptNo));
      }
      return receiptId;
    });
  }

  Future<List<PaymentRow>> _receiptRows(String receiptId) =>
      (_db.select(_db.payments)
            ..where((t) =>
                t.receiptId.equals(receiptId) &
                t.deletedAt.isNull() &
                t.waived.equals(false)))
          .get();

  @override
  Future<void> updateReceipt(String receiptId, PaymentDraft d) {
    return _db.transaction(() async {
      final old = await _receiptRows(receiptId);
      if (old.isEmpty) throw notFound('receipt $receiptId');
      final c = await _check(d, excludeReceiptId: receiptId);
      // The number stays with the receipt (even if the date moves to another
      // year); a receipt from before numbering gets one now.
      String? receiptNo;
      for (final r in old) {
        receiptNo ??= r.receiptNo;
      }
      receiptNo ??= await allocateReceiptNo(_db, d.paidOn);

      // Same (enrollment, month) keeps its row id; every other old row is
      // tombstoned and new months get new rows, all with this receipt id.
      final reusable = <String, PaymentRow>{};
      for (final r in old) {
        reusable.putIfAbsent('${r.enrollmentId}:${r.billingMonth}', () => r);
      }
      final kept = <String>{};
      for (final (month, amount) in c.byMonth) {
        final prev = reusable.remove('${c.enrollment.id}:${month.toInt()}');
        if (prev == null) {
          await _insert(
              _row(Ids.v4(), receiptId, d, c, month, amount, receiptNo));
          continue;
        }
        kept.add(prev.id);
        final next = _row(prev.id, receiptId, d, c, month, amount, receiptNo);
        if (paymentFromRow(prev) == next) continue;
        await (_db.update(_db.payments)..where((t) => t.id.equals(prev.id)))
            .write(paymentToCompanion(next).copyWith(
          updatedAt: Value(_stamper.nextUpdatedAt(prev.updatedAt)),
          rev: Value(_stamper.nextRev(prev.rev)),
          deviceId: Value(_stamper.deviceId),
        ));
      }
      for (final r in old) {
        if (!kept.contains(r.id)) {
          await tombstoneId(_db, _stamper, _db.payments, r.id);
        }
      }
    });
  }

  @override
  Future<void> deleteReceipt(String receiptId) {
    return _db.transaction(() async {
      final n = await tombstoneWhere(_db, _stamper, _db.payments,
          'receipt_id = ? AND waived = 0', [Variable.withString(receiptId)]);
      if (n == 0) throw notFound('receipt $receiptId');
    });
  }

  @override
  Future<List<Payment>> receipt(String receiptId) async {
    final rows = await _receiptRows(receiptId);
    return rows.map(paymentFromRow).toList()
      ..sort((a, b) {
        final m = a.billingMonth.compareTo(b.billingMonth);
        return m != 0 ? m : a.id.compareTo(b.id);
      });
  }

  @override
  Future<void> waive(String enrollmentId, YearMonth month, {String? reason}) {
    return _db.transaction(() async {
      final e = await requireEnrollment(_db, enrollmentId);
      final start = YearMonth.fromInt(e.startMonth);
      final endInt = e.endMonth;
      final billable = !month.isBefore(start) &&
          (endInt == null || !month.isAfter(YearMonth.fromInt(endInt)));
      if (!billable) {
        throw const ValidationException(ErrorCodes.dateInvalid,
            field: 'month');
      }
      await writeWaiver(_db, _stamper, e, month,
          on: todayOf(_stamper, _center), reason: reason);
    });
  }

  @override
  Future<void> unwaive(String enrollmentId, YearMonth month) {
    return _db.transaction(() async {
      await tombstoneWhere(
        _db,
        _stamper,
        _db.payments,
        'enrollment_id = ? AND billing_month = ? AND waived = 1',
        [Variable.withString(enrollmentId), Variable.withInt(month.toInt())],
      );
    });
  }
}
