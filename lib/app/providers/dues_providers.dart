import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One row per live enrollment with the batch / override fees the dues engine
/// needs.
final enrollmentTermsProvider = StreamProvider<List<EnrollmentTerms>>(
    (ref) => ref.watch(enrollmentsRepositoryProvider).watchTerms());

/// Every payment / waiver as a (enrollment, month, amount) fact.
final paymentFactsProvider = StreamProvider<List<PaymentFact>>(
    (ref) => ref.watch(paymentsRepositoryProvider).watchFacts());

/// The dues list (Product 3.5) as of [todayProvider].
final duesReportProvider = Provider<AsyncValue<DuesReport>>((ref) {
  final today = ref.watch(todayProvider);
  return combine2(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    (terms, facts) =>
        DuesEngine.report(today: today, terms: terms, payments: facts),
  );
});

/// A student's dues as listed in the report (active group first, else the
/// grey inactive group); `null` when the student has no open due month.
final studentDuesProvider =
    Provider.family<AsyncValue<StudentDues?>, String>((ref, studentId) {
  return ref.watch(duesReportProvider).whenData((report) {
    for (final s in report.active) {
      if (s.studentId == studentId) return s;
    }
    for (final s in report.inactive) {
      if (s.studentId == studentId) return s;
    }
    return null;
  });
});

/// All billable months of one enrollment (paid, partial, upcoming...); `null`
/// when the enrollment is unknown. Computed with `aheadMonths` 12, the value
/// `DuesEngine.autoAllocate` requires.
final enrollmentDuesProvider =
    Provider.family<AsyncValue<EnrollmentDues?>, String>((ref, enrollmentId) {
  final today = ref.watch(todayProvider);
  return combine2(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    (terms, facts) {
      for (final t in terms) {
        if (t.enrollmentId != enrollmentId) continue;
        return DuesEngine.forEnrollment(
          terms: t,
          payments: facts,
          today: today,
          aheadMonths: 12,
        );
      }
      return null;
    },
  );
});

/// Dues of one batch's active students (inactive enrollments excluded).
class BatchDuesSummary {
  const BatchDuesSummary({this.worst, this.count = 0, this.total = 0});

  /// Highest severity among the batch's enrollments with an open due month.
  final DueLevel? worst;

  /// Students with an open due month in this batch.
  final int count;

  /// Outstanding taka in this batch.
  final int total;

  @override
  bool operator ==(Object other) =>
      other is BatchDuesSummary &&
      other.worst == worst &&
      other.count == count &&
      other.total == total;

  @override
  int get hashCode => Object.hash(worst, count, total);

  @override
  String toString() => 'BatchDuesSummary($worst, $count, $total)';
}

final batchDuesProvider =
    Provider.family<AsyncValue<BatchDuesSummary>, String>((ref, batchId) {
  return ref.watch(duesReportProvider).whenData((report) {
    DueLevel? worst;
    final students = <String>{};
    var total = 0;
    for (final s in report.active) {
      for (final e in s.enrollments) {
        if (e.terms.batchId != batchId || e.openDue.isEmpty) continue;
        students.add(s.studentId);
        total += e.totalOutstanding;
        final w = e.worst;
        if (w != null && (worst == null || w.rank > worst.rank)) worst = w;
      }
    }
    return BatchDuesSummary(worst: worst, count: students.length, total: total);
  });
});
