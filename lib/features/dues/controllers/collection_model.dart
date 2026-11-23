// Pure model of the monthly collection summary (Product 3.7, F14): the billing
// month block (expected / received / waived / outstanding per batch and in
// total) and the cash-in block (payments by their payment date, by method,
// plus other income). No Flutter, no providers.

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/models/payment.dart';

/// One enrollment's standing in one billing month.
class LedgerLine {
  const LedgerLine({required this.terms, required this.due});

  final EnrollmentTerms terms;
  final MonthDue due;
}

/// The [month] of every enrollment that bills it (optionally one batch).
List<LedgerLine> buildLedger({
  required List<EnrollmentTerms> terms,
  required List<PaymentFact> facts,
  required LocalDate today,
  required YearMonth month,
  String? batchId,
}) {
  final Map<String, List<PaymentFact>> factsBy = <String, List<PaymentFact>>{};
  for (final PaymentFact f in facts) {
    (factsBy[f.enrollmentId] ??= <PaymentFact>[]).add(f);
  }
  final List<LedgerLine> lines = <LedgerLine>[];
  for (final EnrollmentTerms t in terms) {
    if (batchId != null && t.batchId != batchId) continue;
    final EnrollmentDues dues = DuesEngine.forEnrollment(
      terms: t,
      payments: factsBy[t.enrollmentId] ?? const <PaymentFact>[],
      today: today,
      aheadMonths: 12,
    );
    for (final MonthDue md in dues.months) {
      if (md.month == month) {
        lines.add(LedgerLine(terms: t, due: md));
        break;
      }
    }
  }
  return lines;
}

/// Sum of a set of ledger lines.
class MonthTotals {
  const MonthTotals({
    this.expected = 0,
    this.received = 0,
    this.waivedCount = 0,
    this.waivedAmount = 0,
    this.outstanding = 0,
    this.paidStudents = 0,
    this.totalStudents = 0,
  });

  /// Fee of the month over billable, non-waived enrollments.
  final int expected;

  /// Allocations to the month.
  final int received;
  final int waivedCount;
  final int waivedAmount;

  /// What is still owed for the month (per enrollment, never negative).
  final int outstanding;

  /// Students who paid every fee of the month in full / students with a fee.
  final int paidStudents;
  final int totalStudents;
}

MonthTotals totalsOf(List<LedgerLine> lines) {
  var expected = 0;
  var received = 0;
  var waivedCount = 0;
  var waivedAmount = 0;
  var outstanding = 0;
  final Map<String, bool> paidByStudent = <String, bool>{};
  for (final LedgerLine l in lines) {
    final MonthDue d = l.due;
    if (d.state == MonthState.waived) {
      waivedCount++;
      waivedAmount += d.fee;
      continue;
    }
    if (d.state == MonthState.free) continue;
    expected += d.fee;
    received += d.paid;
    outstanding += d.remaining;
    final bool paid = d.state == MonthState.paid;
    final bool? before = paidByStudent[l.terms.studentId];
    paidByStudent[l.terms.studentId] = (before ?? true) && paid;
  }
  var paidStudents = 0;
  for (final bool p in paidByStudent.values) {
    if (p) paidStudents++;
  }
  return MonthTotals(
    expected: expected,
    received: received,
    waivedCount: waivedCount,
    waivedAmount: waivedAmount,
    outstanding: outstanding,
    paidStudents: paidStudents,
    totalStudents: paidByStudent.length,
  );
}

class BatchMonthSummary {
  const BatchMonthSummary({
    required this.batchId,
    required this.batchName,
    required this.totals,
  });

  final String batchId;
  final String batchName;
  final MonthTotals totals;
}

class MethodTotal {
  const MethodTotal(this.method, this.amount);

  final PaymentMethod method;
  final int amount;
}

/// One receipt (all its month rows) paid in the calendar month.
class ReceiptLine {
  const ReceiptLine({
    required this.receiptId,
    required this.studentId,
    required this.paidOn,
    required this.method,
    required this.amount,
    required this.months,
    this.receiptNo,
  });

  final String receiptId;

  /// Slip number (schema v2), null for a receipt without one.
  final String? receiptNo;
  final String studentId;
  final LocalDate paidOn;
  final PaymentMethod method;
  final int amount;
  final List<YearMonth> months;
}

class CollectionSummary {
  const CollectionSummary({
    required this.month,
    required this.totals,
    required this.batches,
    required this.feesCash,
    required this.byMethod,
    required this.otherIncome,
    required this.receipts,
  });

  final YearMonth month;

  /// Block 1: everything billed for [month].
  final MonthTotals totals;
  final List<BatchMonthSummary> batches;

  /// Block 2: money that came in during the calendar month.
  final int feesCash;
  final List<MethodTotal> byMethod;
  final int otherIncome;
  final List<ReceiptLine> receipts;

  int get cashTotal => feesCash + otherIncome;
}

CollectionSummary buildCollectionSummary({
  required YearMonth month,
  required LocalDate today,
  required List<EnrollmentTerms> terms,
  required List<PaymentFact> facts,
  required List<Payment> payments,
  required List<OtherIncome> otherIncome,
}) {
  final List<LedgerLine> lines =
      buildLedger(terms: terms, facts: facts, today: today, month: month);
  final Map<String, List<LedgerLine>> byBatch = <String, List<LedgerLine>>{};
  for (final LedgerLine l in lines) {
    (byBatch[l.terms.batchId] ??= <LedgerLine>[]).add(l);
  }
  final List<BatchMonthSummary> batches = <BatchMonthSummary>[
    for (final MapEntry<String, List<LedgerLine>> e in byBatch.entries)
      BatchMonthSummary(
        batchId: e.key,
        batchName: e.value.first.terms.batchName,
        totals: totalsOf(e.value),
      ),
  ]..sort((BatchMonthSummary a, BatchMonthSummary b) => a.batchName.compareTo(b.batchName));

  final LocalDate first = month.firstDay;
  final LocalDate last = month.lastDay;
  final Map<PaymentMethod, int> methods = <PaymentMethod, int>{};
  final Map<String, _ReceiptAcc> receipts = <String, _ReceiptAcc>{};
  var feesCash = 0;
  for (final Payment p in payments) {
    if (p.waived || p.paidOn.isBefore(first) || p.paidOn.isAfter(last)) continue;
    feesCash += p.amount;
    methods[p.method] = (methods[p.method] ?? 0) + p.amount;
    final _ReceiptAcc acc = receipts.putIfAbsent(p.receiptId, () => _ReceiptAcc(p));
    acc.amount += p.amount;
    acc.months.add(p.billingMonth);
  }
  final List<MethodTotal> byMethod = <MethodTotal>[
    for (final MapEntry<PaymentMethod, int> e in methods.entries) MethodTotal(e.key, e.value),
  ]..sort((MethodTotal a, MethodTotal b) {
      if (a.amount != b.amount) return b.amount.compareTo(a.amount);
      return a.method.code.compareTo(b.method.code);
    });
  final List<ReceiptLine> receiptLines = <ReceiptLine>[
    for (final _ReceiptAcc a in receipts.values)
      ReceiptLine(
        receiptId: a.first.receiptId,
        studentId: a.first.studentId,
        paidOn: a.first.paidOn,
        method: a.first.method,
        amount: a.amount,
        months: a.months.toList()..sort(),
        receiptNo: a.first.receiptNo,
      ),
  ]..sort((ReceiptLine a, ReceiptLine b) {
      final int byDate = b.paidOn.compareTo(a.paidOn);
      if (byDate != 0) return byDate;
      return a.receiptId.compareTo(b.receiptId);
    });

  var other = 0;
  for (final OtherIncome o in otherIncome) {
    if (o.paidOn.isBefore(first) || o.paidOn.isAfter(last)) continue;
    other += o.amount;
  }

  return CollectionSummary(
    month: month,
    totals: totalsOf(lines),
    batches: batches,
    feesCash: feesCash,
    byMethod: byMethod,
    otherIncome: other,
    receipts: receiptLines,
  );
}

class _ReceiptAcc {
  _ReceiptAcc(this.first);

  final Payment first;
  int amount = 0;
  final Set<YearMonth> months = <YearMonth>{};
}

// ---- per place (schema v2, feedback item 3) ----------------------------------

/// [buildCollectionSummary] restricted to one place: the enrollments of its
/// batches (`EnrollmentTerms.placeId`), the payments of those batches and the
/// other income stored with that place. [batchPlaces] (batch id -> place id)
/// covers batches that have no live enrollment left; the terms win otherwise.
CollectionSummary buildPlaceCollectionSummary({
  required String placeId,
  required YearMonth month,
  required LocalDate today,
  required List<EnrollmentTerms> terms,
  required List<PaymentFact> facts,
  required List<Payment> payments,
  required List<OtherIncome> otherIncome,
  Map<String, String> batchPlaces = const <String, String>{},
}) {
  final Map<String, String> placeOfBatch = <String, String>{
    ...batchPlaces,
    for (final EnrollmentTerms t in terms) t.batchId: t.placeId,
  };
  final List<EnrollmentTerms> mine = <EnrollmentTerms>[
    for (final EnrollmentTerms t in terms)
      if (t.placeId == placeId) t,
  ];
  final Set<String> enrollments = <String>{for (final EnrollmentTerms t in mine) t.enrollmentId};
  return buildCollectionSummary(
    month: month,
    today: today,
    terms: mine,
    facts: <PaymentFact>[
      for (final PaymentFact f in facts)
        if (enrollments.contains(f.enrollmentId)) f,
    ],
    payments: <Payment>[
      for (final Payment p in payments)
        if (placeOfBatch[p.batchId] == placeId) p,
    ],
    otherIncome: <OtherIncome>[
      for (final OtherIncome o in otherIncome)
        if (o.placeId == placeId) o,
    ],
  );
}

/// One place's month: the place-restricted collection summary plus the three
/// numbers the per-place totals show.
class PlaceMonthSummary {
  const PlaceMonthSummary({required this.placeId, required this.summary});

  final String placeId;
  final CollectionSummary summary;

  /// Fee money received in the calendar month (by payment date).
  int get collected => summary.feesCash;

  /// Still owed for the billing month.
  int get dues => summary.totals.outstanding;

  /// Other income of the place received in the calendar month.
  int get otherIncome => summary.otherIncome;
}

/// Every place's month, in `placeIds` order, plus the other income that
/// belongs to no place ("general").
class PlacesMonthBreakdown {
  const PlacesMonthBreakdown({
    required this.month,
    required this.places,
    required this.generalOtherIncome,
  });

  final YearMonth month;
  final List<PlaceMonthSummary> places;
  final int generalOtherIncome;
}

PlacesMonthBreakdown buildPlacesMonthBreakdown({
  required List<String> placeIds,
  required YearMonth month,
  required LocalDate today,
  required List<EnrollmentTerms> terms,
  required List<PaymentFact> facts,
  required List<Payment> payments,
  required List<OtherIncome> otherIncome,
  Map<String, String> batchPlaces = const <String, String>{},
}) {
  final LocalDate first = month.firstDay;
  final LocalDate last = month.lastDay;
  var general = 0;
  for (final OtherIncome o in otherIncome) {
    if (o.placeId != null || o.paidOn.isBefore(first) || o.paidOn.isAfter(last)) continue;
    general += o.amount;
  }
  return PlacesMonthBreakdown(
    month: month,
    places: <PlaceMonthSummary>[
      for (final String id in placeIds)
        PlaceMonthSummary(
          placeId: id,
          summary: buildPlaceCollectionSummary(
            placeId: id,
            month: month,
            today: today,
            terms: terms,
            facts: facts,
            payments: payments,
            otherIncome: otherIncome,
            batchPlaces: batchPlaces,
          ),
        ),
    ],
    generalOtherIncome: general,
  );
}
