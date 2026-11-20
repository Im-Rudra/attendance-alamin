// Pure model of the dues list (Product 3.5, UX 2d): filters, the per-student
// rows built from a `DuesReport`, and the severity-sorted active / grey
// groups. No Flutter, no providers: unit-testable.

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';

/// The scope chips of the dues list (UX 2d: সব · মেয়াদোত্তীর্ণ · এ মাসে).
enum DuesScope { all, overdue, thisMonth }

class DuesFilter {
  const DuesFilter({this.scope = DuesScope.all, this.month, this.batchId});

  final DuesScope scope;

  /// Only open fees of this billing month (set from the collection summary).
  final YearMonth? month;

  /// Only the enrollments of this batch.
  final String? batchId;

  bool get isDefault => scope == DuesScope.all && month == null && batchId == null;

  DuesFilter copyWith({
    DuesScope? scope,
    YearMonth? month,
    bool clearMonth = false,
    String? batchId,
    bool clearBatch = false,
  }) =>
      DuesFilter(
        scope: scope ?? this.scope,
        month: clearMonth ? null : (month ?? this.month),
        batchId: clearBatch ? null : (batchId ?? this.batchId),
      );

  @override
  bool operator ==(Object other) =>
      other is DuesFilter &&
      other.scope == scope &&
      other.month == month &&
      other.batchId == batchId;

  @override
  int get hashCode => Object.hash(scope, month, batchId);
}

/// Why a due sits in the grey group.
enum InactiveReason { left, archived, ended }

/// One student of the list, with the numbers of the enrollments / months that
/// pass the filter.
class DuesRow {
  const DuesRow({
    required this.studentId,
    required this.name,
    required this.total,
    required this.months,
    required this.batchNames,
    required this.enrollmentIds,
    required this.inactive,
    this.level,
    this.dayInDue,
    this.partialRemaining,
    this.waiveEnrollmentId,
    this.waiveMonth,
    this.reason,
  });

  final String studentId;
  final String name;

  /// Outstanding taka over the included months.
  final int total;

  /// Open due months, ascending, distinct.
  final List<YearMonth> months;

  /// Batches that still owe, in the engine's enrollment order.
  final List<String> batchNames;
  final List<String> enrollmentIds;

  /// In the grey group (left / archived / ended): no severity.
  final bool inactive;

  /// Worst level; `null` for the grey group.
  final DueLevel? level;

  /// 1..10 inside the warning window, `null` when overdue or grey.
  final int? dayInDue;

  /// Remaining taka when the single open month is partly paid.
  final int? partialRemaining;

  /// Set when exactly one (enrollment, month) is open: the waive target.
  final String? waiveEnrollmentId;
  final YearMonth? waiveMonth;

  final InactiveReason? reason;

  int get monthCount => months.length;
}

/// The active groups plus the grey group.
class DuesView {
  const DuesView({required this.active, required this.inactive});

  /// Sorted: level desc, open months desc, total desc, name.
  final List<DuesRow> active;
  final List<DuesRow> inactive;

  bool get isEmpty => active.isEmpty && inactive.isEmpty;

  /// Active rows of one level (the list is already sorted).
  List<DuesRow> ofLevel(DueLevel level) =>
      <DuesRow>[for (final DuesRow r in active) if (r.level == level) r];

  /// Every row the teacher can walk through: active first, then grey.
  List<DuesRow> get all => <DuesRow>[...active, ...inactive];
}

/// Severity groups shown on screen, worst first (upcoming never has a row:
/// only due months are listed).
const List<DueLevel> kDuesGroupOrder = <DueLevel>[
  DueLevel.overdue,
  DueLevel.finalDays,
  DueLevel.urgent,
  DueLevel.followUp,
  DueLevel.remind,
  DueLevel.justDue,
];

/// Rows of [report] that pass [filter], grouped and sorted.
DuesView buildDuesView(DuesReport report, DuesFilter filter, LocalDate today) {
  final List<DuesRow> active = <DuesRow>[];
  for (final StudentDues s in report.active) {
    final DuesRow? r = _rowOf(s, filter, today, inactive: false);
    if (r != null) active.add(r);
  }
  active.sort(_compareRows);
  final List<DuesRow> inactive = <DuesRow>[];
  // "Overdue" is a severity: the grey group has none.
  if (filter.scope != DuesScope.overdue) {
    for (final StudentDues s in report.inactive) {
      final DuesRow? r = _rowOf(s, filter, today, inactive: true);
      if (r != null) inactive.add(r);
    }
    inactive.sort(_compareRows);
  }
  return DuesView(active: active, inactive: inactive);
}

int _compareRows(DuesRow a, DuesRow b) {
  final int ra = a.level?.rank ?? -1;
  final int rb = b.level?.rank ?? -1;
  if (ra != rb) return rb.compareTo(ra);
  if (a.monthCount != b.monthCount) return b.monthCount.compareTo(a.monthCount);
  if (a.total != b.total) return b.total.compareTo(a.total);
  return a.name.compareTo(b.name);
}

DuesRow? _rowOf(StudentDues s, DuesFilter f, LocalDate today, {required bool inactive}) {
  final YearMonth? month = f.month ?? (f.scope == DuesScope.thisMonth ? today.yearMonth : null);
  var total = 0;
  DueLevel? level;
  int? day;
  final Set<YearMonth> months = <YearMonth>{};
  final List<String> batchNames = <String>[];
  final List<String> enrollmentIds = <String>[];
  final List<({String enrollmentId, YearMonth month})> pairs = <({String enrollmentId, YearMonth month})>[];
  MonthDue? singleDue;
  InactiveReason? reason;
  for (final EnrollmentDues e in s.enrollments) {
    if (f.batchId != null && e.terms.batchId != f.batchId) continue;
    var any = false;
    for (final MonthDue md in e.openDue) {
      if (month != null && md.month != month) continue;
      any = true;
      total += md.remaining;
      months.add(md.month);
      pairs.add((enrollmentId: e.terms.enrollmentId, month: md.month));
      singleDue = md;
      final DueLevel? l = md.level;
      if (!inactive && l != null) {
        if (level == null || l.rank > level.rank) {
          level = l;
          day = md.dayInDue;
        } else if (l == level && (md.dayInDue ?? 0) > (day ?? 0)) {
          day = md.dayInDue;
        }
      }
    }
    if (!any) continue;
    enrollmentIds.add(e.terms.enrollmentId);
    if (!batchNames.contains(e.terms.batchName)) batchNames.add(e.terms.batchName);
    reason ??= e.terms.studentLeft
        ? InactiveReason.left
        : (e.terms.batchArchived ? InactiveReason.archived : InactiveReason.ended);
  }
  if (enrollmentIds.isEmpty) return null;
  if (f.scope == DuesScope.overdue && level != DueLevel.overdue) return null;
  final List<YearMonth> sorted = months.toList()..sort();
  final bool single = pairs.length == 1;
  return DuesRow(
    studentId: s.studentId,
    name: s.name,
    total: total,
    months: sorted,
    batchNames: batchNames,
    enrollmentIds: enrollmentIds,
    inactive: inactive,
    level: level,
    dayInDue: level == DueLevel.overdue ? null : day,
    partialRemaining: (single && singleDue != null && singleDue.state == MonthState.partial)
        ? singleDue.remaining
        : null,
    waiveEnrollmentId: single ? pairs.first.enrollmentId : null,
    waiveMonth: single ? pairs.first.month : null,
    reason: inactive ? reason : null,
  );
}

/// The date-of-month shown on the escalation bar: today's day while inside the
/// first ten days of the month, else `null` (every segment is filled).
int? escalationDay(LocalDate today) => today.day <= 10 ? today.day : null;

/// The dues of one student from [report] (active group first, else grey).
StudentDues? duesOfStudent(DuesReport report, String studentId) {
  for (final StudentDues s in report.active) {
    if (s.studentId == studentId) return s;
  }
  for (final StudentDues s in report.inactive) {
    if (s.studentId == studentId) return s;
  }
  return null;
}
