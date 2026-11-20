// Pure logic behind the Today screen (no widgets, no providers): which class
// the hero shows, the month's collection, the day's attendance, the backup
// nudge rule, the recent receipts and the reminder-window hint.

import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/payment.dart';

const int _msPerDay = 86400000;

// ---- hero ------------------------------------------------------------------

enum HeroKind {
  /// No live batch at all: the setup card.
  noBatches,

  /// Today has no class.
  noClasses,

  /// A class is running and still has no roll call.
  current,

  /// The next class of today (no roll call yet).
  next,

  /// Today's classes are over but one has no roll call.
  pending,

  /// Every class of today has its roll call.
  allDone,

  /// Another date than today is picked on the day strip.
  otherDay,
}

class HeroState {
  const HeroState({
    required this.kind,
    this.focus,
    this.minutes = 0,
    this.taken = 0,
    this.total = 0,
  });

  final HeroKind kind;

  /// The class the pill opens (current / next / pending, or the first class
  /// without roll call of a past date).
  final DayClass? focus;

  /// current: minutes left; next: minutes until it starts.
  final int minutes;

  /// Classes of the day with a roll call / classes of the day (cancelled ones
  /// excluded).
  final int taken;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is HeroState &&
      other.kind == kind &&
      other.focus == focus &&
      other.minutes == minutes &&
      other.taken == taken &&
      other.total == total;

  @override
  int get hashCode => Object.hash(kind, focus, minutes, taken, total);

  @override
  String toString() => 'HeroState($kind, $focus, $minutes, $taken/$total)';
}

/// What the hero card shows for [date] given the day's [classes].
HeroState buildHero({
  required bool hasBatches,
  required LocalDate date,
  required LocalDate today,
  required int nowMin,
  required List<DayClass> classes,
}) {
  if (!hasBatches) return const HeroState(kind: HeroKind.noBatches);
  final List<DayClass> live = <DayClass>[
    for (final DayClass c in classes)
      if (!c.cancelled) c,
  ];
  final int taken = live.where((DayClass c) => c.taken).length;

  if (date != today) {
    DayClass? focus;
    if (date.isBefore(today)) {
      for (final DayClass c in live) {
        if (!c.taken) {
          focus = c;
          break;
        }
      }
    }
    return HeroState(
      kind: HeroKind.otherDay,
      focus: focus,
      taken: taken,
      total: live.length,
    );
  }

  if (live.isEmpty) return const HeroState(kind: HeroKind.noClasses);

  for (final DayClass c in live) {
    if (c.taken || c.endMin <= nowMin) continue;
    if (c.startMin <= nowMin) {
      return HeroState(
        kind: HeroKind.current,
        focus: c,
        minutes: c.endMin - nowMin,
        taken: taken,
        total: live.length,
      );
    }
    return HeroState(
      kind: HeroKind.next,
      focus: c,
      minutes: c.startMin - nowMin,
      taken: taken,
      total: live.length,
    );
  }

  DayClass? pending;
  for (final DayClass c in live) {
    if (!c.taken) pending = c;
  }
  if (pending != null) {
    return HeroState(
      kind: HeroKind.pending,
      focus: pending,
      taken: taken,
      total: live.length,
    );
  }
  return HeroState(kind: HeroKind.allDone, taken: taken, total: live.length);
}

// ---- week helpers ------------------------------------------------------------

/// First day of the week of [d] when weeks start on ISO weekday [weekStart].
LocalDate weekStartFor(LocalDate d, int weekStart) =>
    d.addDays(-((d.isoWeekday - weekStart + 7) % 7));

/// The escalation bar's ringed day: today's date while it is in the first ten
/// days of the month, else `null` (every segment filled).
int? escalationDayOf(LocalDate today) => today.day <= 10 ? today.day : null;

// ---- day attendance ----------------------------------------------------------

class DayAttendance {
  const DayAttendance({
    required this.total,
    required this.taken,
    required this.tally,
    this.lowest,
    this.lowestPercent,
  });

  /// Classes of the day without the cancelled ones.
  final int total;

  /// Classes with a saved roll call.
  final int taken;

  /// Sum of every saved roll call of the day.
  final AttendanceTally tally;

  /// The batch class with the lowest attendance (two or more roll calls).
  final DayClass? lowest;
  final int? lowestPercent;

  int? get percent => tally.percent;
}

DayAttendance buildDayAttendance(List<DayClass> classes) {
  var total = 0;
  var taken = 0;
  var present = 0, absent = 0, late = 0, leave = 0;
  DayClass? lowest;
  int? lowestPercent;
  var withPercent = 0;
  for (final DayClass c in classes) {
    if (c.cancelled) continue;
    total++;
    final AttendanceTally? t = c.tally;
    if (!c.taken || t == null) continue;
    taken++;
    present += t.present;
    absent += t.absent;
    late += t.late;
    leave += t.leave;
    final int? p = t.percent;
    if (p != null) {
      withPercent++;
      if (lowestPercent == null || p < lowestPercent) {
        lowestPercent = p;
        lowest = c;
      }
    }
  }
  return DayAttendance(
    total: total,
    taken: taken,
    tally: AttendanceTally(
        present: present, absent: absent, late: late, leave: leave),
    lowest: withPercent >= 2 ? lowest : null,
    lowestPercent: withPercent >= 2 ? lowestPercent : null,
  );
}

// ---- month collection --------------------------------------------------------

class MonthCollection {
  const MonthCollection({
    required this.collected,
    required this.expected,
    required this.byMethod,
  });

  /// Money received with a payment date in the month (waivers excluded).
  final int collected;

  /// The month's fees over every billable, active enrollment.
  final int expected;

  /// [collected] split by payment method, biggest first.
  final List<MethodAmount> byMethod;

  /// 0..100 (collected over expected, capped); `null` without any fee.
  int? get percent {
    if (expected <= 0) return null;
    final int p = (collected * 100) ~/ expected;
    return p > 100 ? 100 : p;
  }

  double get fraction {
    if (expected <= 0) return 0;
    final double f = collected / expected;
    return f > 1 ? 1 : f;
  }
}

class MethodAmount {
  const MethodAmount(this.method, this.amount);

  final PaymentMethod method;
  final int amount;
}

MonthCollection buildMonthCollection({
  required LocalDate today,
  required List<EnrollmentTerms> terms,
  required List<PaymentFact> facts,
  required List<Payment> payments,
}) {
  final YearMonth month = today.yearMonth;
  final Map<String, List<PaymentFact>> factsBy = <String, List<PaymentFact>>{};
  for (final PaymentFact f in facts) {
    (factsBy[f.enrollmentId] ??= <PaymentFact>[]).add(f);
  }
  var expected = 0;
  for (final EnrollmentTerms t in terms) {
    if (t.studentLeft || t.batchArchived || t.enrollmentEnded) continue;
    final EnrollmentDues dues = DuesEngine.forEnrollment(
      terms: t,
      payments: factsBy[t.enrollmentId] ?? const <PaymentFact>[],
      today: today,
      aheadMonths: 12,
    );
    for (final MonthDue md in dues.months) {
      if (md.month != month) continue;
      if (md.state == MonthState.waived ||
          md.state == MonthState.free ||
          md.feeMissing) {
        break;
      }
      expected += md.fee;
      break;
    }
  }

  var collected = 0;
  final Map<String, int> sums = <String, int>{};
  final Map<String, PaymentMethod> methods = <String, PaymentMethod>{};
  for (final Payment p in payments) {
    if (p.waived || p.amount <= 0) continue;
    if (p.paidOn.yearMonth != month) continue;
    collected += p.amount;
    sums[p.method.code] = (sums[p.method.code] ?? 0) + p.amount;
    methods[p.method.code] = p.method;
  }
  final List<MethodAmount> byMethod = <MethodAmount>[
    for (final MapEntry<String, int> e in sums.entries)
      MethodAmount(methods[e.key]!, e.value),
  ]..sort((MethodAmount a, MethodAmount b) {
      final int c = b.amount.compareTo(a.amount);
      return c != 0 ? c : a.method.code.compareTo(b.method.code);
    });
  return MonthCollection(
      collected: collected, expected: expected, byMethod: byMethod);
}

// ---- recent receipts ---------------------------------------------------------

class RecentReceipt {
  const RecentReceipt({
    required this.receiptId,
    required this.studentId,
    required this.total,
    required this.paidOn,
  });

  final String receiptId;
  final String studentId;
  final int total;
  final LocalDate paidOn;
}

/// The last [limit] receipts (rows sharing a receipt id are one receipt),
/// newest payment date first. Waivers are not receipts.
List<RecentReceipt> recentReceipts(List<Payment> payments, {int limit = 5}) {
  final Map<String, RecentReceipt> byId = <String, RecentReceipt>{};
  for (final Payment p in payments) {
    if (p.waived || p.amount <= 0) continue;
    final RecentReceipt? old = byId[p.receiptId];
    byId[p.receiptId] = RecentReceipt(
      receiptId: p.receiptId,
      studentId: p.studentId,
      total: (old?.total ?? 0) + p.amount,
      paidOn: old == null || p.paidOn.isAfter(old.paidOn) ? p.paidOn : old.paidOn,
    );
  }
  final List<RecentReceipt> all = byId.values.toList()
    ..sort((RecentReceipt a, RecentReceipt b) {
      final int c = b.paidOn.compareTo(a.paidOn);
      return c != 0 ? c : b.receiptId.compareTo(a.receiptId);
    });
  return all.length <= limit ? all : all.sublist(0, limit);
}

// ---- backup nudge ------------------------------------------------------------

class BackupStatus {
  const BackupStatus({required this.due, this.daysAgo});

  /// The nudge shows (and the tile turns info-coloured).
  final bool due;

  /// Whole days since the last export; `null` = never.
  final int? daysAgo;
}

/// Product F18 / Settings: nudge when the last export is older than
/// [reminderDays] (0 = off), or when there was none and the center has at
/// least [minStudentsWhenNever] students.
BackupStatus backupStatus({
  required int? lastExportMs,
  required int nowMs,
  required int reminderDays,
  required int studentCount,
  int minStudentsWhenNever = 10,
}) {
  if (lastExportMs == null) {
    return BackupStatus(
      due: reminderDays > 0 && studentCount >= minStudentsWhenNever,
    );
  }
  final int age = nowMs - lastExportMs;
  final int days = age < 0 ? 0 : age ~/ _msPerDay;
  return BackupStatus(
    due: reminderDays > 0 && age > reminderDays * _msPerDay,
    daysAgo: days,
  );
}

// ---- reminder window ---------------------------------------------------------

/// Whole days of class reminders still planned when fewer than three remain,
/// else `null` (no hint). `null` too when reminders are off or never planned.
int? reminderDaysLeft({
  required bool enabled,
  required int? plannedUntilMs,
  required int nowMs,
}) {
  if (!enabled || plannedUntilMs == null) return null;
  final int left = plannedUntilMs - nowMs;
  if (left >= 3 * _msPerDay) return null;
  return left <= 0 ? 0 : left ~/ _msPerDay;
}
