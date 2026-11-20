import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/value_equality.dart';

/// Warning level of an open month (Product 3.5, levels 0..6).
///
/// Declaration ORDER is binding: the theme maps
/// `SeverityLevel.values[dueLevel.index]` (see `lib/app/theme/tokens.dart`).
enum DueLevel {
  upcoming(0),
  justDue(1),
  remind(2),
  followUp(3),
  urgent(4),
  finalDays(5),
  overdue(6);

  const DueLevel(this.rank);

  final int rank;

  /// Level for [dayInDue] = days since the due date, 1-based:
  /// <=0 upcoming, 1-2 justDue, 3-4 remind, 5-6 followUp, 7-8 urgent,
  /// 9-10 finalDays, >=11 overdue.
  static DueLevel forDay(int dayInDue) {
    if (dayInDue <= 0) return DueLevel.upcoming;
    if (dayInDue <= 2) return DueLevel.justDue;
    if (dayInDue <= 4) return DueLevel.remind;
    if (dayInDue <= 6) return DueLevel.followUp;
    if (dayInDue <= 8) return DueLevel.urgent;
    if (dayInDue <= 10) return DueLevel.finalDays;
    return DueLevel.overdue;
  }
}

enum MonthState { waived, free, paid, partial, unpaid }

/// Everything the dues engine needs to know about one enrollment.
class EnrollmentTerms {
  const EnrollmentTerms({
    required this.enrollmentId,
    required this.studentId,
    required this.batchId,
    required this.studentName,
    required this.batchName,
    required this.subjectName,
    required this.billing,
    required this.start,
    this.end,
    this.batchFees = const [],
    this.overrides = const [],
    this.batchArchived = false,
    this.studentLeft = false,
    this.enrollmentEnded = false,
  });

  final String enrollmentId;
  final String studentId;
  final String batchId;
  final String studentName;
  final String batchName;
  final String subjectName;
  final BillingType billing;
  final YearMonth start;
  final YearMonth? end;

  /// Batch fee history (ascending by `effective` is conventional, not required).
  final List<FeePeriod> batchFees;

  /// Enrollment fee-override history (`amount == null` = override cleared).
  final List<FeePeriod> overrides;
  final bool batchArchived;
  final bool studentLeft;
  final bool enrollmentEnded;

  @override
  bool operator ==(Object other) =>
      other is EnrollmentTerms &&
      other.enrollmentId == enrollmentId &&
      other.studentId == studentId &&
      other.batchId == batchId &&
      other.studentName == studentName &&
      other.batchName == batchName &&
      other.subjectName == subjectName &&
      other.billing == billing &&
      other.start == start &&
      other.end == end &&
      listEq(other.batchFees, batchFees) &&
      listEq(other.overrides, overrides) &&
      other.batchArchived == batchArchived &&
      other.studentLeft == studentLeft &&
      other.enrollmentEnded == enrollmentEnded;

  @override
  int get hashCode => Object.hash(
        enrollmentId,
        studentId,
        batchId,
        studentName,
        batchName,
        subjectName,
        billing,
        start,
        end,
        Object.hashAll(batchFees),
        Object.hashAll(overrides),
        batchArchived,
        studentLeft,
        enrollmentEnded,
      );

  @override
  String toString() => 'EnrollmentTerms($enrollmentId)';
}

/// A payment row reduced to what the engine needs.
class PaymentFact {
  const PaymentFact({
    required this.enrollmentId,
    required this.month,
    required this.amount,
    this.waived = false,
  });

  final String enrollmentId;
  final YearMonth month;
  final int amount;
  final bool waived;

  @override
  bool operator ==(Object other) =>
      other is PaymentFact &&
      other.enrollmentId == enrollmentId &&
      other.month == month &&
      other.amount == amount &&
      other.waived == waived;

  @override
  int get hashCode => Object.hash(enrollmentId, month, amount, waived);

  @override
  String toString() => 'PaymentFact($enrollmentId, $month, $amount)';
}

class MonthDue {
  const MonthDue({
    required this.month,
    required this.fee,
    required this.feeMissing,
    required this.paid,
    required this.remaining,
    required this.state,
    required this.dueDate,
    required this.isDue,
    this.level,
    this.dayInDue,
    this.overpaid = 0,
  });

  final YearMonth month;
  final int fee;
  final bool feeMissing;
  final int paid;
  final int remaining;
  final MonthState state;
  final LocalDate dueDate;
  final bool isDue;

  /// `null` when the month is closed (paid / free / waived).
  final DueLevel? level;

  /// 1..10 while inside the 10-day window, else `null`.
  final int? dayInDue;
  final int overpaid;

  bool get isOpen => state == MonthState.partial || state == MonthState.unpaid;

  @override
  bool operator ==(Object other) =>
      other is MonthDue &&
      other.month == month &&
      other.fee == fee &&
      other.feeMissing == feeMissing &&
      other.paid == paid &&
      other.remaining == remaining &&
      other.state == state &&
      other.dueDate == dueDate &&
      other.isDue == isDue &&
      other.level == level &&
      other.dayInDue == dayInDue &&
      other.overpaid == overpaid;

  @override
  int get hashCode => Object.hash(month, fee, feeMissing, paid, remaining,
      state, dueDate, isDue, level, dayInDue, overpaid);

  @override
  String toString() => 'MonthDue($month, $state, rem $remaining)';
}

class EnrollmentDues {
  const EnrollmentDues({
    required this.terms,
    required this.months,
    required this.openDue,
    required this.totalOutstanding,
    required this.inactive,
    this.worst,
    this.worstDay,
    this.oldestOpenDue,
  });

  final EnrollmentTerms terms;

  /// `start..min(end, today + 12 months)`.
  final List<MonthDue> months;

  /// Open months whose due date has arrived.
  final List<MonthDue> openDue;
  final int totalOutstanding;
  final DueLevel? worst;
  final int? worstDay;
  final YearMonth? oldestOpenDue;

  /// left || archived || ended.
  final bool inactive;

  @override
  bool operator ==(Object other) =>
      other is EnrollmentDues &&
      other.terms == terms &&
      listEq(other.months, months) &&
      listEq(other.openDue, openDue) &&
      other.totalOutstanding == totalOutstanding &&
      other.worst == worst &&
      other.worstDay == worstDay &&
      other.oldestOpenDue == oldestOpenDue &&
      other.inactive == inactive;

  @override
  int get hashCode => Object.hash(
        terms,
        Object.hashAll(months),
        Object.hashAll(openDue),
        totalOutstanding,
        worst,
        worstDay,
        oldestOpenDue,
        inactive,
      );

  @override
  String toString() => 'EnrollmentDues(${terms.enrollmentId})';
}

class StudentDues {
  const StudentDues({
    required this.studentId,
    required this.name,
    required this.enrollments,
    required this.openDueMonths,
    required this.totalOutstanding,
    required this.openMonths,
    this.worst,
    this.worstDay,
    this.oldestOpenDue,
  });

  final String studentId;
  final String name;
  final List<EnrollmentDues> enrollments;
  final DueLevel? worst;
  final int? worstDay;
  final int openDueMonths;
  final int totalOutstanding;
  final YearMonth? oldestOpenDue;
  final List<YearMonth> openMonths;

  @override
  bool operator ==(Object other) =>
      other is StudentDues &&
      other.studentId == studentId &&
      other.name == name &&
      listEq(other.enrollments, enrollments) &&
      other.worst == worst &&
      other.worstDay == worstDay &&
      other.openDueMonths == openDueMonths &&
      other.totalOutstanding == totalOutstanding &&
      other.oldestOpenDue == oldestOpenDue &&
      listEq(other.openMonths, openMonths);

  @override
  int get hashCode => Object.hash(
        studentId,
        name,
        Object.hashAll(enrollments),
        worst,
        worstDay,
        openDueMonths,
        totalOutstanding,
        oldestOpenDue,
        Object.hashAll(openMonths),
      );

  @override
  String toString() => 'StudentDues($studentId, $totalOutstanding)';
}

class DuesReport {
  const DuesReport({
    required this.active,
    required this.inactive,
    required this.countByLevel,
    required this.totalOutstandingActive,
    required this.totalOutstandingInactive,
    required this.studentsWithDues,
    required this.overdueStudents,
  });

  /// Sorted: level desc, open due months desc, total desc, name.
  final List<StudentDues> active;
  final List<StudentDues> inactive;
  final Map<DueLevel, int> countByLevel;
  final int totalOutstandingActive;
  final int totalOutstandingInactive;
  final int studentsWithDues;
  final int overdueStudents;

  @override
  bool operator ==(Object other) =>
      other is DuesReport &&
      listEq(other.active, active) &&
      listEq(other.inactive, inactive) &&
      mapEq(other.countByLevel, countByLevel) &&
      other.totalOutstandingActive == totalOutstandingActive &&
      other.totalOutstandingInactive == totalOutstandingInactive &&
      other.studentsWithDues == studentsWithDues &&
      other.overdueStudents == overdueStudents;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(active),
        Object.hashAll(inactive),
        mapHash(countByLevel),
        totalOutstandingActive,
        totalOutstandingInactive,
        studentsWithDues,
        overdueStudents,
      );
}
