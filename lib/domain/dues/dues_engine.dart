import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';

/// The money logic (Product 3.0-3.5, Arch 4, plan 1 #7-#11). Pure Dart:
/// `today` is always a parameter, there is no clock, DB or Flutter here.
///
/// Conventions every caller relies on:
/// * All money is per enrollment. A student in several batches has several
///   independent due streams; student level only sums them.
/// * [EnrollmentTerms.start] is the first billable month (FBM) and
///   [EnrollmentTerms.end] the last billable month (LBM, `null` = open-ended).
///   Months outside `[start, end]` are not billable and never appear.
/// * A [PaymentFact] is one allocation row (one receipt may have several).
///   Waived facts never count as paid; any waived fact makes the month waived.
abstract final class DuesEngine {
  /// Advance payments may be allocated up to this many months after
  /// today's month (Product 3.4).
  static const int _advanceMonths = 12;

  /// Days 1..10 of the due month are the warning window (Product 3.5).
  static const int _warningDays = 10;

  /// Leaving / archiving on this day of the month or later bills that month
  /// (Product 3.2: "left day >= 11").
  static const int _lastBillableFromDay = 11;

  /// Prepaid: the 1st of [m]. Postpaid: the 1st of the month after [m].
  static LocalDate dueDate(BillingType b, YearMonth m) => switch (b) {
        BillingType.prepaid => m.firstDay,
        BillingType.postpaid => m.addMonths(1).firstDay,
      };

  /// Effective monthly fee for [m] (Product 3.1): the latest override with
  /// `effective <= m` wins unless its amount is `null` (override cleared);
  /// otherwise the latest batch fee with `effective <= m`.
  ///
  /// History starts with the earliest record (Chair rule, QA-01): a month
  /// before every fee record of the enrollment (batch fees and overrides)
  /// is read as that earliest month, so the first fee is in effect from the
  /// start unless a later change says otherwise (a teacher migrating a
  /// student whose first billable month precedes the batch's first fee
  /// record still gets those months billed). A month after an override-only
  /// start with no batch fee yet falls back to the earliest batch fee. Only
  /// with no fee record at all is the fee 0 and `missing` true (never a due;
  /// surfaced in the UI).
  static ({int fee, bool missing}) feeFor(EnrollmentTerms t, YearMonth m) {
    final firstBatch = _earliestMonth(t.batchFees);
    final firstOverride = _earliestMonth(t.overrides);
    final YearMonth anchor;
    if (firstBatch == null) {
      if (firstOverride == null) return (fee: 0, missing: true);
      anchor = firstOverride;
    } else {
      anchor = firstOverride == null || firstBatch.isBefore(firstOverride)
          ? firstBatch
          : firstOverride;
    }
    final at = m.isBefore(anchor) ? anchor : m;
    final overrideAmount = _latestAtOrBefore(t.overrides, at)?.amount;
    if (overrideAmount != null) return (fee: overrideAmount, missing: false);
    final batch = _latestAtOrBefore(t.batchFees, at) ??
        (firstBatch == null ? null : _latestAtOrBefore(t.batchFees, firstBatch));
    final batchAmount = batch?.amount;
    if (batchAmount != null) return (fee: batchAmount, missing: false);
    return (fee: 0, missing: true);
  }

  /// Every billable month of one enrollment from `start` to
  /// `min(end, today's month + aheadMonths)`, with totals over the open months
  /// that are already due.
  static EnrollmentDues forEnrollment({
    required EnrollmentTerms terms,
    required List<PaymentFact> payments,
    required LocalDate today,
    int aheadMonths = 12,
  }) {
    final paidByMonth = <YearMonth, int>{};
    final waivedMonths = <YearMonth>{};
    for (final p in payments) {
      if (p.enrollmentId != terms.enrollmentId) continue;
      if (p.waived) {
        waivedMonths.add(p.month);
      } else {
        paidByMonth[p.month] = (paidByMonth[p.month] ?? 0) + p.amount;
      }
    }

    var last = today.yearMonth.addMonths(aheadMonths < 0 ? 0 : aheadMonths);
    final end = terms.end;
    if (end != null && end.isBefore(last)) last = end;

    final months = <MonthDue>[];
    for (var m = terms.start; !m.isAfter(last); m = m.addMonths(1)) {
      months.add(_monthDue(
        terms: terms,
        month: m,
        paid: paidByMonth[m] ?? 0,
        waived: waivedMonths.contains(m),
        today: today,
      ));
    }

    final openDue = <MonthDue>[
      for (final md in months)
        if (md.isOpen && md.isDue) md,
    ];
    var total = 0;
    DueLevel? worst;
    int? worstDay;
    for (final md in openDue) {
      total += md.remaining;
      final level = md.level;
      if (level == null) continue;
      if (worst == null || level.rank > worst.rank) {
        worst = level;
        worstDay = md.dayInDue;
      } else if (level == worst && (md.dayInDue ?? 0) > (worstDay ?? 0)) {
        worstDay = md.dayInDue;
      }
    }

    return EnrollmentDues(
      terms: terms,
      months: months,
      openDue: openDue,
      totalOutstanding: total,
      inactive: _isInactive(terms),
      worst: worst,
      worstDay: worstDay,
      oldestOpenDue: openDue.isEmpty ? null : openDue.first.month,
    );
  }

  /// The dues list (Product 3.5, plan 1 #8).
  ///
  /// Only enrollments with at least one open, due month take part. Active
  /// enrollments are grouped per student into [DuesReport.active] (sorted:
  /// level desc, open due months desc, total desc, name). Enrollments of a
  /// left student, an archived batch or an ended enrollment go to
  /// [DuesReport.inactive] (the grey "ছেড়ে যাওয়া / আর্কাইভ" group): there the
  /// student's `worst`/`worstDay` are `null` (no escalation), they are not in
  /// [DuesReport.countByLevel] and their money is in
  /// [DuesReport.totalOutstandingInactive]. A student removed from one batch
  /// but active in another can therefore appear once in each list.
  static DuesReport report({
    required LocalDate today,
    required List<EnrollmentTerms> terms,
    required List<PaymentFact> payments,
  }) {
    final factsByEnrollment = <String, List<PaymentFact>>{};
    for (final p in payments) {
      factsByEnrollment.putIfAbsent(p.enrollmentId, () => <PaymentFact>[]).add(p);
    }

    final activeByStudent = <String, List<EnrollmentDues>>{};
    final inactiveByStudent = <String, List<EnrollmentDues>>{};
    for (final t in terms) {
      final dues = forEnrollment(
        terms: t,
        payments: factsByEnrollment[t.enrollmentId] ?? const <PaymentFact>[],
        today: today,
      );
      if (dues.openDue.isEmpty) continue;
      final target = dues.inactive ? inactiveByStudent : activeByStudent;
      target.putIfAbsent(t.studentId, () => <EnrollmentDues>[]).add(dues);
    }

    final active = <StudentDues>[
      for (final e in activeByStudent.entries)
        _studentDues(e.key, e.value, escalates: true),
    ]..sort(_compareStudents);
    final inactive = <StudentDues>[
      for (final e in inactiveByStudent.entries)
        _studentDues(e.key, e.value, escalates: false),
    ]..sort(_compareStudents);

    final countByLevel = <DueLevel, int>{
      for (final l in DueLevel.values)
        if (l != DueLevel.upcoming) l: 0,
    };
    var totalActive = 0;
    var overdueStudents = 0;
    for (final s in active) {
      totalActive += s.totalOutstanding;
      final w = s.worst;
      if (w != null) countByLevel[w] = (countByLevel[w] ?? 0) + 1;
      if (w == DueLevel.overdue) overdueStudents++;
    }
    var totalInactive = 0;
    for (final s in inactive) {
      totalInactive += s.totalOutstanding;
    }

    return DuesReport(
      active: active,
      inactive: inactive,
      countByLevel: countByLevel,
      totalOutstandingActive: totalActive,
      totalOutstandingInactive: totalInactive,
      studentsWithDues: active.length,
      overdueStudents: overdueStudents,
    );
  }

  /// FBM default from the join date (Product 3.2): join day `1..cutoffDay`
  /// bills the join month, a later day starts with the next month.
  /// The cutoff is read when the enrollment is created; changing the setting
  /// later never touches stored `startMonth`s.
  static YearMonth defaultFirstBillableMonth(LocalDate joinDate, int cutoffDay) =>
      joinDate.day <= cutoffDay
          ? joinDate.yearMonth
          : joinDate.yearMonth.addMonths(1);

  /// LBM default for leaving / removal / archive on [leaveOrArchiveDate]
  /// (Product 3.2): day >= 11 bills that month, day 1..10 stops at the
  /// previous month.
  static YearMonth defaultLastBillableMonth(LocalDate leaveOrArchiveDate) =>
      leaveOrArchiveDate.day >= _lastBillableFromDay
          ? leaveOrArchiveDate.yearMonth
          : leaveOrArchiveDate.yearMonth.addMonths(-1);

  /// Splits [amount] over the open months of [dues], oldest first (due or
  /// upcoming), never more than a month's remaining, and never into a month
  /// after `today`'s month + 12 (Product 3.4). Waived, free and paid months
  /// are skipped. Throws [ValidationException] `allocationBeyondHorizon` when
  /// part of the amount cannot be placed, `amountInvalid` for a negative
  /// amount. Amount 0 gives an empty list.
  ///
  /// [dues] must come from [forEnrollment] with the same `today` and the
  /// default `aheadMonths` (12), so every month up to the horizon is present.
  static List<Allocation> autoAllocate({
    required EnrollmentDues dues,
    required int amount,
    required LocalDate today,
  }) {
    if (amount < 0) {
      throw const ValidationException(ErrorCodes.amountInvalid, field: 'amount');
    }
    final horizon = today.yearMonth.addMonths(_advanceMonths);
    var left = amount;
    final out = <Allocation>[];
    for (final md in dues.months) {
      if (left <= 0) break;
      if (!md.isOpen || md.month.isAfter(horizon)) continue;
      final take = md.remaining < left ? md.remaining : left;
      if (take <= 0) continue;
      out.add(Allocation(month: md.month, amount: take));
      left -= take;
    }
    if (left > 0) {
      throw ValidationException(
        ErrorCodes.allocationBeyondHorizon,
        field: 'amount',
        detail: 'unplaced $left',
      );
    }
    return out;
  }

  /// Checks a manual allocation (Product 3.4). Throws [ValidationException]:
  /// * `amountInvalid` when the list is empty or any allocation is <= 0;
  /// * `allocationBeyondHorizon` for a billable month after the last month of
  ///   [dues] (i.e. beyond today + 12 months);
  /// * `allocationExceedsRemaining` when a month (allocations to the same
  ///   month are summed) gets more than its remaining: paid, free and waived
  ///   months have 0 remaining, non-billable months (before FBM / after LBM)
  ///   accept nothing.
  ///
  /// When editing a receipt, build [dues] from the payments WITHOUT that
  /// receipt's own rows.
  static void validateAllocations({
    required EnrollmentDues dues,
    required List<Allocation> allocations,
  }) {
    if (allocations.isEmpty) {
      throw const ValidationException(
        ErrorCodes.amountInvalid,
        field: 'allocations',
      );
    }
    final sums = <YearMonth, int>{};
    for (final a in allocations) {
      if (a.amount <= 0) {
        throw ValidationException(
          ErrorCodes.amountInvalid,
          field: 'allocations',
          detail: a.month.toString(),
        );
      }
      sums[a.month] = (sums[a.month] ?? 0) + a.amount;
    }

    final byMonth = <YearMonth, MonthDue>{
      for (final md in dues.months) md.month: md,
    };
    final lastListed = dues.months.isEmpty ? null : dues.months.last.month;
    final start = dues.terms.start;
    final end = dues.terms.end;
    for (final e in sums.entries) {
      final month = e.key;
      final md = byMonth[month];
      if (md == null) {
        final billable =
            !month.isBefore(start) && (end == null || !month.isAfter(end));
        final beyond =
            billable && (lastListed == null || month.isAfter(lastListed));
        throw ValidationException(
          beyond
              ? ErrorCodes.allocationBeyondHorizon
              : ErrorCodes.allocationExceedsRemaining,
          field: 'allocations',
          detail: month.toString(),
        );
      }
      if (e.value > md.remaining) {
        throw ValidationException(
          ErrorCodes.allocationExceedsRemaining,
          field: 'allocations',
          detail: month.toString(),
        );
      }
    }
  }

  /// Number of (enrollment, month) pairs that are settled now (paid, or free
  /// with money on them) and would become partial with the [after] terms
  /// (Product 3.1 warning "N টি মাস আংশিক হয়ে যাবে"). Enrollments are matched
  /// by id; months up to today + 12 are compared (advance-paid months count).
  static int monthsBecomingPartial({
    required List<EnrollmentTerms> before,
    required List<EnrollmentTerms> after,
    required List<PaymentFact> payments,
    required LocalDate today,
  }) {
    final afterById = <String, EnrollmentTerms>{
      for (final t in after) t.enrollmentId: t,
    };
    var count = 0;
    for (final b in before) {
      final a = afterById[b.enrollmentId];
      if (a == null) continue;
      final was = forEnrollment(terms: b, payments: payments, today: today);
      final now = forEnrollment(terms: a, payments: payments, today: today);
      final nowByMonth = <YearMonth, MonthDue>{
        for (final md in now.months) md.month: md,
      };
      for (final md in was.months) {
        if (md.state != MonthState.paid && md.state != MonthState.free) {
          continue;
        }
        if (nowByMonth[md.month]?.state == MonthState.partial) count++;
      }
    }
    return count;
  }

  // ---------------------------------------------------------------------------

  static MonthDue _monthDue({
    required EnrollmentTerms terms,
    required YearMonth month,
    required int paid,
    required bool waived,
    required LocalDate today,
  }) {
    final f = feeFor(terms, month);
    final fee = f.fee;
    final due = dueDate(terms.billing, month);
    final isDue = !today.isBefore(due);

    final MonthState state;
    if (waived) {
      state = MonthState.waived;
    } else if (fee <= 0) {
      state = MonthState.free;
    } else if (paid >= fee) {
      state = MonthState.paid;
    } else if (paid > 0) {
      state = MonthState.partial;
    } else {
      state = MonthState.unpaid;
    }
    final open = state == MonthState.partial || state == MonthState.unpaid;
    final remaining = open ? fee - (paid > 0 ? paid : 0) : 0;
    final excess = paid - (fee > 0 ? fee : 0);

    DueLevel? level;
    int? dayInDue;
    if (open) {
      if (!isDue) {
        level = DueLevel.upcoming;
      } else {
        // Day-of-month inside the due month; any later month gives a day
        // > 28, i.e. overdue ("any older month = overdue").
        final day = due.daysUntil(today) + 1;
        level = DueLevel.forDay(day);
        if (day <= _warningDays) dayInDue = day;
      }
    }

    return MonthDue(
      month: month,
      fee: fee,
      feeMissing: f.missing,
      paid: paid,
      remaining: remaining,
      state: state,
      dueDate: due,
      isDue: isDue,
      level: level,
      dayInDue: dayInDue,
      overpaid: excess > 0 ? excess : 0,
    );
  }

  static bool _isInactive(EnrollmentTerms t) =>
      t.studentLeft || t.batchArchived || t.enrollmentEnded;

  static YearMonth? _earliestMonth(List<FeePeriod> periods) {
    YearMonth? first;
    for (final p in periods) {
      if (first == null || p.effective.isBefore(first)) first = p.effective;
    }
    return first;
  }

  static FeePeriod? _latestAtOrBefore(List<FeePeriod> periods, YearMonth m) {
    FeePeriod? best;
    for (final p in periods) {
      if (p.effective.isAfter(m)) continue;
      // On equal months the later list entry wins.
      if (best == null || !p.effective.isBefore(best.effective)) best = p;
    }
    return best;
  }

  static StudentDues _studentDues(
    String studentId,
    List<EnrollmentDues> list, {
    required bool escalates,
  }) {
    final enrollments = [...list]..sort(_compareEnrollments);
    var total = 0;
    DueLevel? worst;
    int? worstDay;
    YearMonth? oldest;
    final months = <YearMonth>{};
    for (final e in enrollments) {
      total += e.totalOutstanding;
      for (final md in e.openDue) {
        months.add(md.month);
      }
      final eo = e.oldestOpenDue;
      if (eo != null && (oldest == null || eo.isBefore(oldest))) oldest = eo;
      if (!escalates) continue;
      final w = e.worst;
      if (w == null) continue;
      if (worst == null || w.rank > worst.rank) {
        worst = w;
        worstDay = e.worstDay;
      } else if (w == worst && (e.worstDay ?? 0) > (worstDay ?? 0)) {
        worstDay = e.worstDay;
      }
    }
    final openMonths = months.toList()..sort();
    return StudentDues(
      studentId: studentId,
      name: enrollments.first.terms.studentName,
      enrollments: enrollments,
      openDueMonths: openMonths.length,
      totalOutstanding: total,
      openMonths: openMonths,
      worst: worst,
      worstDay: worstDay,
      oldestOpenDue: oldest,
    );
  }

  static int _compareEnrollments(EnrollmentDues a, EnrollmentDues b) {
    final s = a.terms.subjectName.compareTo(b.terms.subjectName);
    if (s != 0) return s;
    final n = a.terms.batchName.compareTo(b.terms.batchName);
    if (n != 0) return n;
    return a.terms.enrollmentId.compareTo(b.terms.enrollmentId);
  }

  /// Plan 1 #8: level desc, open due months desc, total desc, name.
  static int _compareStudents(StudentDues a, StudentDues b) {
    final ra = a.worst?.rank ?? -1;
    final rb = b.worst?.rank ?? -1;
    if (ra != rb) return rb.compareTo(ra);
    if (a.openDueMonths != b.openDueMonths) {
      return b.openDueMonths.compareTo(a.openDueMonths);
    }
    if (a.totalOutstanding != b.totalOutstanding) {
      return b.totalOutstanding.compareTo(a.totalOutstanding);
    }
    final n = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (n != 0) return n;
    final exact = a.name.compareTo(b.name);
    if (exact != 0) return exact;
    return a.studentId.compareTo(b.studentId);
  }
}
