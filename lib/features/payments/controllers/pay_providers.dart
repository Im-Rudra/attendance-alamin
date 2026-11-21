// Data providers of the payments feature (M7-B). Everything is derived from the
// M4 repositories and the M5-B providers; nothing is stored here.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/features/payments/receipt_text.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

/// Every live payment row (receipts and waivers), newest first.
final payAllPaymentsProvider = StreamProvider.autoDispose<List<Payment>>(
    (ref) => ref.watch(paymentsRepositoryProvider).watchAll());

/// One student's rows (receipts and waivers), newest first.
final payStudentPaymentsProvider = StreamProvider.autoDispose.family<List<Payment>, String>(
    (ref, studentId) => ref.watch(paymentsRepositoryProvider).watchForStudent(studentId));

final payStudentProvider = StreamProvider.autoDispose.family<Student?, String>(
    (ref, id) => ref.watch(studentsRepositoryProvider).watchById(id));

/// The allocation rows of one receipt (waivers are not receipts), by month.
final payReceiptRowsProvider =
    Provider.autoDispose.family<AsyncValue<List<Payment>>, String>((ref, receiptId) {
  return ref.watch(payAllPaymentsProvider).whenData((List<Payment> all) => <Payment>[
        for (final Payment p in all)
          if (p.receiptId == receiptId && !p.waived) p,
      ]..sort((Payment a, Payment b) => a.billingMonth.compareTo(b.billingMonth)));
});

/// Dues of every enrollment of [studentId] that can take a payment: active
/// ones, and inactive ones only while they still owe. The first entry is the
/// one the form opens on.
final payChoicesProvider =
    Provider.autoDispose.family<AsyncValue<List<EnrollmentDues>>, String>((ref, studentId) {
  final LocalDate today = ref.watch(todayProvider);
  return combine2(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    (List<EnrollmentTerms> terms, List<PaymentFact> facts) {
      final List<EnrollmentDues> all = <EnrollmentDues>[
        for (final EnrollmentTerms t in terms)
          if (t.studentId == studentId)
            DuesEngine.forEnrollment(terms: t, payments: facts, today: today),
      ];
      final List<EnrollmentDues> usable = <EnrollmentDues>[
        for (final EnrollmentDues d in all)
          if (!d.inactive || d.openDue.isNotEmpty) d,
      ];
      return sortChoices(usable);
    },
  );
});

/// Active before inactive, then the enrollment with the oldest open due month
/// (then the worst warning) first; enrollments owing nothing last.
List<EnrollmentDues> sortChoices(List<EnrollmentDues> list) {
  int key(EnrollmentDues d) {
    final YearMonth? m = d.oldestOpenDue;
    if (m == null) return 1 << 30;
    return m.toInt();
  }

  final List<EnrollmentDues> out = <EnrollmentDues>[...list];
  out.sort((EnrollmentDues a, EnrollmentDues b) {
    if (a.inactive != b.inactive) return a.inactive ? 1 : -1;
    final int byMonth = key(a).compareTo(key(b));
    if (byMonth != 0) return byMonth;
    final int ra = a.worst?.rank ?? -1;
    final int rb = b.worst?.rank ?? -1;
    return rb.compareTo(ra);
  });
  return out;
}

/// Dues of one enrollment for the form: 12 months ahead, and (when editing a
/// receipt) WITHOUT that receipt's own rows (Lead notes, M2-A).
final payDuesProvider = Provider.autoDispose
    .family<AsyncValue<EnrollmentDues?>, ({String enrollmentId, String? receiptId})>((ref, key) {
  final LocalDate today = ref.watch(todayProvider);
  final String? receiptId = key.receiptId;
  final AsyncValue<List<Payment>> own = receiptId == null
      ? AsyncValue<List<Payment>>.data(<Payment>[])
      : ref.watch(payReceiptRowsProvider(receiptId));
  return combine3(
    ref.watch(enrollmentTermsProvider),
    ref.watch(paymentFactsProvider),
    own,
    (List<EnrollmentTerms> terms, List<PaymentFact> facts, List<Payment> rows) {
      final List<PaymentFact> rest = <PaymentFact>[...facts];
      for (final Payment r in rows) {
        final int i = rest.indexWhere((PaymentFact f) =>
            !f.waived &&
            f.enrollmentId == r.enrollmentId &&
            f.month == r.billingMonth &&
            f.amount == r.amount);
        if (i >= 0) rest.removeAt(i);
      }
      for (final EnrollmentTerms t in terms) {
        if (t.enrollmentId != key.enrollmentId) continue;
        return DuesEngine.forEnrollment(terms: t, payments: rest, today: today, aheadMonths: 12);
      }
      return null;
    },
  );
});

/// Everything a receipt needs; null while the receipt does not exist.
class ReceiptModel {
  const ReceiptModel({required this.receiptId, required this.facts, required this.first});

  final String receiptId;
  final ReceiptFacts facts;

  /// A row of the receipt (date, method, note, ids are the same on all rows).
  final Payment first;

  LocalDate get paidOn => first.paidOn;
  PaymentMethod get method => first.method;
  String? get note => first.note;
  String get studentId => first.studentId;
  String get enrollmentId => first.enrollmentId;
}

/// The allocation facts as they stood when [receiptId] was recorded (QA-05):
/// its own rows and every row recorded before it. [history] is the
/// repository's order (newest payment date first; on one date the receipt
/// recorded last comes first). Rows of later receipts never count, so an old
/// receipt keeps saying what it said when it was given.
List<PaymentFact> factsAsOfReceipt(String receiptId, List<Payment> history) {
  int last = -1;
  LocalDate? on;
  for (var i = 0; i < history.length; i++) {
    if (history[i].receiptId != receiptId) continue;
    last = i;
    on = history[i].paidOn;
  }
  if (on == null) return const <PaymentFact>[];
  return <PaymentFact>[
    for (var i = 0; i < history.length; i++)
      if (history[i].receiptId == receiptId ||
          history[i].paidOn.isBefore(on) ||
          (history[i].paidOn == on && i > last))
        PaymentFact(
          enrollmentId: history[i].enrollmentId,
          month: history[i].billingMonth,
          amount: history[i].amount,
          waived: history[i].waived,
        ),
  ];
}

/// Builds the receipt model from loaded data; null when [rows] is empty.
///
/// The partial months and the balance are those AT THE PAYMENT (QA-05,
/// acceptance 5): dues from [history] up to and including this receipt
/// ([factsAsOfReceipt]), on the payment date.
ReceiptModel? assembleReceipt({
  required String receiptId,
  required List<Payment> rows,
  required List<EnrollmentTerms> terms,
  required List<Payment> history,
  required Student? student,
}) {
  if (rows.isEmpty) return null;
  final Payment first = rows.first;
  EnrollmentTerms? mine;
  for (final EnrollmentTerms t in terms) {
    if (t.enrollmentId == first.enrollmentId) mine = t;
  }
  final LocalDate asOf = first.paidOn;
  int ahead = 12;
  for (final Payment p in rows) {
    final int gap = (p.billingMonth.year - asOf.year) * 12 + p.billingMonth.month - asOf.month;
    if (gap > ahead) ahead = gap;
  }
  final EnrollmentDues? dues = mine == null
      ? null
      : DuesEngine.forEnrollment(
          terms: mine,
          payments: factsAsOfReceipt(receiptId, history),
          today: asOf,
          aheadMonths: ahead,
        );
  return ReceiptModel(
    receiptId: receiptId,
    first: first,
    facts: ReceiptFacts(
      studentName: student?.name ?? mine?.studentName ?? '',
      roll: student?.roll,
      batchName: mine?.batchName ?? '',
      rows: rows,
      partialMonths: partialMonthsOf(rows, dues),
      remaining: dues?.totalOutstanding ?? 0,
    ),
  );
}

final payReceiptProvider =
    Provider.autoDispose.family<AsyncValue<ReceiptModel?>, String>((ref, receiptId) {
  final AsyncValue<List<Payment>> rowsAsync = ref.watch(payReceiptRowsProvider(receiptId));
  final AsyncValue<List<EnrollmentTerms>> termsAsync = ref.watch(enrollmentTermsProvider);
  final AsyncValue<List<Payment>> historyAsync = ref.watch(payAllPaymentsProvider);
  final AsyncValue<List<Payment>> joined = combine3(
    rowsAsync,
    termsAsync,
    historyAsync,
    (List<Payment> rows, List<EnrollmentTerms> terms, List<Payment> history) => rows,
  );
  if (joined.hasError) {
    return AsyncValue<ReceiptModel?>.error(joined.error!, joined.stackTrace ?? StackTrace.empty);
  }
  if (!joined.hasValue) return AsyncValue<ReceiptModel?>.loading();
  final List<Payment> rows = joined.requireValue;
  if (rows.isEmpty) return AsyncValue<ReceiptModel?>.data(null);
  final AsyncValue<Student?> student = ref.watch(payStudentProvider(rows.first.studentId));
  if (!student.hasValue && !student.hasError) return AsyncValue<ReceiptModel?>.loading();
  return AsyncValue<ReceiptModel?>.data(assembleReceipt(
    receiptId: receiptId,
    rows: rows,
    terms: termsAsync.requireValue,
    history: historyAsync.requireValue,
    student: student.value,
  ));
});

/// The receipt template text (default or the teacher's own) and the center name
/// for [lang].
final payReceiptSettingsProvider = FutureProvider.autoDispose
    .family<({String template, String center}), Lang>((ref, lang) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final String stored = await settings.get(templateKey(TemplateKind.receipt, lang));
  final String center = await settings.get(SettingKeys.centerName);
  return (template: editorTextFor(TemplateKind.receipt, lang, stored), center: center);
});
