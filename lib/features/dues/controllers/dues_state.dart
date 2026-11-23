// Providers of the dues feature (M7-C). Everything is derived from the M5-B
// providers (`duesReportProvider`, `enrollmentTermsProvider`,
// `paymentFactsProvider`) and the M4 repositories; the only state kept here is
// the dues filter and the collection month the teacher picked.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/place_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/controllers/collection_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';

// ---- dues list ---------------------------------------------------------------

/// The filter chips of the Fees screen. Kept in a provider (not in the screen)
/// so the collection summary can open the dues list "filtered to that month".
class DuesFilterController extends Notifier<DuesFilter> {
  @override
  DuesFilter build() => const DuesFilter();

  /// A scope chip replaces the scope and drops the month filter.
  void setScope(DuesScope scope) =>
      state = state.copyWith(scope: scope, clearMonth: true);

  /// Open fees of one billing month (from the collection summary).
  void setMonth(YearMonth month) =>
      state = state.copyWith(scope: DuesScope.all, month: month);

  void clearMonth() => state = state.copyWith(clearMonth: true);

  /// `null` = every batch.
  void setBatch(String? batchId) => state = batchId == null
      ? state.copyWith(clearBatch: true)
      : state.copyWith(batchId: batchId);

  void reset() => state = const DuesFilter();
}

final duesFilterProvider =
    NotifierProvider<DuesFilterController, DuesFilter>(DuesFilterController.new);

/// The filtered, sorted, grouped list.
final duesViewProvider = Provider<AsyncValue<DuesView>>((ref) {
  final LocalDate today = ref.watch(todayProvider);
  final DuesFilter filter = ref.watch(duesFilterProvider);
  return ref
      .watch(duesReportProvider)
      .whenData((DuesReport r) => buildDuesView(r, filter, today));
});

/// Students (for phone numbers); keyed by id.
final duesStudentsProvider = StreamProvider<List<Student>>(
    (ref) => ref.watch(studentsRepositoryProvider).watchAll());

final duesStudentMapProvider = Provider<Map<String, Student>>((ref) {
  final List<Student> list =
      ref.watch(duesStudentsProvider).value ?? const <Student>[];
  return <String, Student>{for (final Student s in list) s.id: s};
});

/// Live (not archived) batches for the batch filter.
final duesBatchesProvider = StreamProvider<List<Batch>>(
    (ref) => ref.watch(batchesRepositoryProvider).watchAll());

// ---- "reminded today" --------------------------------------------------------

Set<String> decodeReminded(String? raw) {
  if (raw == null || raw.isEmpty) return <String>{};
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is List<Object?>) {
      return <String>{for (final Object? x in decoded) if (x is String) x};
    }
  } on FormatException {
    // A damaged value reads as nobody reminded.
  }
  return <String>{};
}

String encodeReminded(Set<String> ids) => jsonEncode(ids.toList()..sort());

/// Ids of the students whose reminder was shared today (`reminded:<date>`).
final duesRemindedProvider = StreamProvider<Set<String>>((ref) {
  final LocalDate today = ref.watch(todayProvider);
  return ref
      .watch(localMetaRepositoryProvider)
      .watchRaw(LocalMetaKeys.reminded(today))
      .map(decodeReminded);
});

/// Remembers that [studentId] was reminded on [today].
Future<void> markReminded(
  LocalMetaRepository meta,
  LocalDate today,
  String studentId,
) async {
  final String key = LocalMetaKeys.reminded(today);
  final Set<String> ids = decodeReminded(await meta.getRaw(key));
  if (ids.add(studentId)) await meta.setRaw(key, encodeReminded(ids));
}

// ---- monthly collection ------------------------------------------------------

/// The month shown by the collection screen; `null` = the current month.
class CollMonthController extends Notifier<YearMonth?> {
  @override
  YearMonth? build() => null;

  void select(YearMonth? month) => state = month;
}

final collMonthProvider =
    NotifierProvider<CollMonthController, YearMonth?>(CollMonthController.new);

final collPaymentsProvider = StreamProvider<List<Payment>>(
    (ref) => ref.watch(paymentsRepositoryProvider).watchAll());

final collOtherIncomeProvider = StreamProvider.family<List<OtherIncome>, YearMonth>(
    (ref, month) => ref
        .watch(otherIncomeRepositoryProvider)
        .watchBetween(month.firstDay, month.lastDay));

class _Money {
  const _Money(this.terms, this.facts, this.payments);

  final List<EnrollmentTerms> terms;
  final List<PaymentFact> facts;
  final List<Payment> payments;
}

final collectionSummaryProvider =
    Provider.family<AsyncValue<CollectionSummary>, YearMonth>((ref, month) {
  final LocalDate today = ref.watch(todayProvider);
  final AsyncValue<_Money> money = combine3(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    ref.watch(collPaymentsProvider),
    (List<EnrollmentTerms> t, List<PaymentFact> f, List<Payment> p) =>
        _Money(t, f, p),
  );
  return combine2(
    money,
    ref.watch(collOtherIncomeProvider(month)),
    (_Money m, List<OtherIncome> o) => buildCollectionSummary(
      month: month,
      today: today,
      terms: m.terms,
      facts: m.facts,
      payments: m.payments,
      otherIncome: o,
    ),
  );
});

/// Per-place totals of [month] (schema v2, feedback item 3): one
/// [PlaceMonthSummary] per place that is not archived, in the teacher's order,
/// plus general other income. Only meant to be shown with 2+ places
/// (`hasManyPlacesProvider`); with one place it equals the collection summary.
final placesMonthBreakdownProvider =
    Provider.family<AsyncValue<PlacesMonthBreakdown>, YearMonth>((ref, month) {
  final LocalDate today = ref.watch(todayProvider);
  final AsyncValue<_Money> money = combine3(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    ref.watch(collPaymentsProvider),
    (List<EnrollmentTerms> t, List<PaymentFact> f, List<Payment> p) =>
        _Money(t, f, p),
  );
  return combine3(
    money,
    ref.watch(collOtherIncomeProvider(month)),
    ref.watch(placesProvider),
    (_Money m, List<OtherIncome> o, List<Place> places) =>
        buildPlacesMonthBreakdown(
      placeIds: <String>[for (final Place p in places) p.id],
      month: month,
      today: today,
      terms: m.terms,
      facts: m.facts,
      payments: m.payments,
      otherIncome: o,
    ),
  );
});

/// One place's collection summary of a month (filters on Fees, wave 3).
final placeCollectionSummaryProvider = Provider.family<
    AsyncValue<CollectionSummary>,
    ({String placeId, YearMonth month})>((ref, key) {
  final LocalDate today = ref.watch(todayProvider);
  final AsyncValue<_Money> money = combine3(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    ref.watch(collPaymentsProvider),
    (List<EnrollmentTerms> t, List<PaymentFact> f, List<Payment> p) =>
        _Money(t, f, p),
  );
  return combine2(
    money,
    ref.watch(collOtherIncomeProvider(key.month)),
    (_Money m, List<OtherIncome> o) => buildPlaceCollectionSummary(
      placeId: key.placeId,
      month: key.month,
      today: today,
      terms: m.terms,
      facts: m.facts,
      payments: m.payments,
      otherIncome: o,
    ),
  );
});

/// First billable month of any enrollment (lower bound of the month picker).
final collEarliestMonthProvider = Provider<YearMonth?>((ref) {
  final List<EnrollmentTerms> terms =
      ref.watch(enrollmentTermsProvider).value ?? const <EnrollmentTerms>[];
  YearMonth? earliest;
  for (final EnrollmentTerms t in terms) {
    if (earliest == null || t.start.isBefore(earliest)) earliest = t.start;
  }
  return earliest;
});

/// One batch's standing in one month (batch detail › বেতন).
final batchLedgerProvider = Provider.family<AsyncValue<List<LedgerLine>>,
    ({String batchId, YearMonth month})>((ref, key) {
  final LocalDate today = ref.watch(todayProvider);
  return combine2(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    (List<EnrollmentTerms> terms, List<PaymentFact> facts) => buildLedger(
      terms: terms,
      facts: facts,
      today: today,
      month: key.month,
      batchId: key.batchId,
    ),
  );
});
