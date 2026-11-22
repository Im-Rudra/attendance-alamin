// The three CSV files of F23 (students, payments of a month, attendance of a
// month): row building is pure; [loadCsvFile] reads the repositories once.
// Dates are ISO (2026-11-21) and numbers plain ASCII so Excel can sort and add
// them; the words (column titles, statuses) follow the app language.

import 'dart:typed_data';

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/data/repositories/batches_repository.dart';
import 'package:attendance_alamin/data/repositories/enrollments_repository.dart';
import 'package:attendance_alamin/data/repositories/other_income_repository.dart';
import 'package:attendance_alamin/data/repositories/payments_repository.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/extras/controllers/csv_builder.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

enum CsvKind { students, payments, attendance }

/// A finished file: name plus BOM-prefixed UTF-8 bytes.
class CsvFile {
  const CsvFile({required this.fileName, required this.bytes, required this.rowCount});

  final String fileName;
  final Uint8List bytes;

  /// Data rows (the header is not counted).
  final int rowCount;
}

String _two(int v) => v.toString().padLeft(2, '0');

/// `2026-11`, ASCII.
String csvMonth(YearMonth m) => '${m.year}-${_two(m.month)}';

/// `students-2026-11.csv`, `payments-2026-11.csv`, `attendance-2026-11.csv`.
String csvFileName(CsvKind kind, YearMonth month) => '${kind.name}-${csvMonth(month)}.csv';

CsvFile _finish(CsvKind kind, YearMonth month, List<String> header, List<List<String>> rows) =>
    CsvFile(
      fileName: csvFileName(kind, month),
      bytes: csvBytes(buildCsv(header, rows)),
      rowCount: rows.length,
    );

/// Every live student with phones, status and the batches they are in now.
CsvFile buildStudentsCsv({
  required AppLocalizations l10n,
  required YearMonth month,
  required List<Student> students,
  required List<Enrollment> enrollments,
  required List<Batch> batches,
}) {
  final Map<String, String> batchName = <String, String>{for (final Batch b in batches) b.id: b.name};
  final Map<String, List<String>> batchesOf = <String, List<String>>{};
  for (final Enrollment e in enrollments) {
    if (e.endDate != null) continue;
    final String? name = batchName[e.batchId];
    if (name != null) (batchesOf[e.studentId] ??= <String>[]).add(name);
  }
  final List<Student> sorted = <Student>[...students]..sort(_byRollThenName);
  return _finish(
    CsvKind.students,
    month,
    <String>[
      l10n.extraColRoll,
      l10n.extraColName,
      l10n.extraColPhone,
      l10n.extraColGuardian,
      l10n.extraColGuardianPhone,
      l10n.extraColStatus,
      l10n.extraColAdmission,
      l10n.extraColBatches,
    ],
    <List<String>>[
      for (final Student s in sorted)
        <String>[
          s.roll ?? '',
          s.name,
          csvPhone(s.phone),
          s.guardianName ?? '',
          csvPhone(s.guardianPhone),
          s.status == StudentStatus.left ? l10n.extraStatusLeft : l10n.extraStatusActive,
          s.admissionDate.toIso(),
          (batchesOf[s.id] ?? const <String>[]).join(' / '),
        ],
    ],
  );
}

int _byRollThenName(Student a, Student b) {
  final int? ra = int.tryParse(AppFormat.toAsciiDigits(a.roll ?? ''));
  final int? rb = int.tryParse(AppFormat.toAsciiDigits(b.roll ?? ''));
  if (ra != null && rb != null && ra != rb) return ra.compareTo(rb);
  if (ra != null && rb == null) return -1;
  if (ra == null && rb != null) return 1;
  return a.name.compareTo(b.name);
}

/// Money received in [month] (by payment date): fee rows, waived months and
/// other income, oldest first.
CsvFile buildPaymentsCsv({
  required AppLocalizations l10n,
  required YearMonth month,
  required List<Payment> payments,
  required List<OtherIncome> otherIncome,
  required List<Student> students,
  required List<Batch> batches,
  required String Function(PaymentMethod method) methodLabel,
}) {
  final Map<String, String> studentName = <String, String>{for (final Student s in students) s.id: s.name};
  final Map<String, String> batchName = <String, String>{for (final Batch b in batches) b.id: b.name};
  final List<({String date, int order, List<String> row})> lines =
      <({String date, int order, List<String> row})>[];
  for (final Payment p in payments) {
    if (p.paidOn.yearMonth != month) continue;
    lines.add((
      date: p.paidOn.toIso(),
      order: 0,
      row: <String>[
        p.paidOn.toIso(),
        _shortId(p.receiptId),
        studentName[p.studentId] ?? '',
        batchName[p.batchId] ?? '',
        csvMonth(p.billingMonth),
        p.amount.toString(),
        p.waived ? '' : methodLabel(p.method),
        p.waived ? l10n.extraTypeWaived : l10n.extraTypeFee,
        p.note ?? '',
      ],
    ));
  }
  for (final OtherIncome o in otherIncome) {
    if (o.paidOn.yearMonth != month) continue;
    lines.add((
      date: o.paidOn.toIso(),
      order: 1,
      row: <String>[
        o.paidOn.toIso(),
        '',
        o.studentId == null ? '' : (studentName[o.studentId] ?? ''),
        '',
        o.label,
        o.amount.toString(),
        methodLabel(o.method),
        l10n.extraTypeOther,
        o.note ?? '',
      ],
    ));
  }
  lines.sort((a, b) {
    final int c = a.date.compareTo(b.date);
    return c != 0 ? c : a.order.compareTo(b.order);
  });
  return _finish(
    CsvKind.payments,
    month,
    <String>[
      l10n.extraColDate,
      l10n.extraColReceipt,
      l10n.extraColStudent,
      l10n.extraColBatch,
      l10n.extraColForMonth,
      l10n.extraColAmount,
      l10n.extraColMethod,
      l10n.extraColType,
      l10n.extraColNote,
    ],
    <List<String>>[for (final l in lines) l.row],
  );
}

String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

/// One row per student per class of [month]: date, batch, roll, name, status.
CsvFile buildAttendanceCsv({
  required AppLocalizations l10n,
  required YearMonth month,
  required List<AttendanceRecord> records,
  required List<AttendanceSession> sessions,
  required List<Student> students,
  required List<Batch> batches,
}) {
  final Map<String, Student> studentOf = <String, Student>{for (final Student s in students) s.id: s};
  final Map<String, String> batchName = <String, String>{for (final Batch b in batches) b.id: b.name};
  final Map<String, int> startOf = <String, int>{for (final AttendanceSession s in sessions) s.id: s.startMin};
  final List<AttendanceRecord> inMonth = <AttendanceRecord>[
    for (final AttendanceRecord r in records)
      if (r.date.yearMonth == month) r,
  ]..sort((a, b) {
      int c = a.date.compareTo(b.date);
      if (c != 0) return c;
      c = (startOf[a.sessionId] ?? 0).compareTo(startOf[b.sessionId] ?? 0);
      if (c != 0) return c;
      c = (batchName[a.batchId] ?? '').compareTo(batchName[b.batchId] ?? '');
      if (c != 0) return c;
      final Student? sa = studentOf[a.studentId];
      final Student? sb = studentOf[b.studentId];
      if (sa != null && sb != null) return _byRollThenName(sa, sb);
      return a.studentId.compareTo(b.studentId);
    });
  String statusText(AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => l10n.extraAttPresent,
        AttendanceStatus.absent => l10n.extraAttAbsent,
        AttendanceStatus.late => l10n.extraAttLate,
        AttendanceStatus.leave => l10n.extraAttLeave,
      };
  return _finish(
    CsvKind.attendance,
    month,
    <String>[
      l10n.extraColDate,
      l10n.extraColBatch,
      l10n.extraColRoll,
      l10n.extraColStudent,
      l10n.extraColStatus,
    ],
    <List<String>>[
      for (final AttendanceRecord r in inMonth)
        <String>[
          r.date.toIso(),
          batchName[r.batchId] ?? '',
          studentOf[r.studentId]?.roll ?? '',
          studentOf[r.studentId]?.name ?? '',
          statusText(r.status),
        ],
    ],
  );
}

/// Reads what [kind] needs from the repositories and builds the file.
Future<CsvFile> loadCsvFile({
  required CsvKind kind,
  required YearMonth month,
  required AppLocalizations l10n,
  required StudentsRepository students,
  required EnrollmentsRepository enrollments,
  required BatchesRepository batches,
  required PaymentsRepository payments,
  required OtherIncomeRepository otherIncome,
  required AttendanceRepository attendance,
  required String Function(PaymentMethod method) methodLabel,
}) async {
  final List<Student> allStudents = await students.watchAll().first;
  final List<Batch> allBatches = await batches.watchAll(includeArchived: true).first;
  switch (kind) {
    case CsvKind.students:
      return buildStudentsCsv(
        l10n: l10n,
        month: month,
        students: allStudents,
        enrollments: await enrollments.watchAll().first,
        batches: allBatches,
      );
    case CsvKind.payments:
      return buildPaymentsCsv(
        l10n: l10n,
        month: month,
        payments: await payments.watchAll().first,
        otherIncome: await otherIncome.watchBetween(month.firstDay, month.lastDay).first,
        students: allStudents,
        batches: allBatches,
        methodLabel: methodLabel,
      );
    case CsvKind.attendance:
      final List<SessionSummary> summaries =
          await attendance.watchSummaries(from: month.firstDay, to: month.lastDay).first;
      return buildAttendanceCsv(
        l10n: l10n,
        month: month,
        records: await attendance.watchRecords().first,
        sessions: <AttendanceSession>[for (final SessionSummary s in summaries) s.session],
        students: allStudents,
        batches: allBatches,
      );
  }
}
