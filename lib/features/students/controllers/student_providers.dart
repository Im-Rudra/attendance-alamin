// Data providers of the students feature (M6-D). Everything here is derived
// from the M4 repositories and the M5-B providers; nothing is stored.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Live students (active and left), roll then name.
final stuRosterProvider = StreamProvider<List<Student>>(
    (ref) => ref.watch(studentsRepositoryProvider).watchAll());

final stuStudentProvider = StreamProvider.family<Student?, String>(
    (ref, id) => ref.watch(studentsRepositoryProvider).watchById(id));

/// Every batch including archived ones (an enrollment may point at one).
final stuBatchesProvider = StreamProvider<List<Batch>>((ref) =>
    ref.watch(batchesRepositoryProvider).watchAll(includeArchived: true));

final stuSubjectsProvider = StreamProvider<List<Subject>>(
    (ref) => ref.watch(subjectsRepositoryProvider).watchAll());

/// "নতুন ভর্তির বেতন শুরু" cutoff day (Settings, default 15).
final stuCutoffProvider = FutureProvider<int>((ref) =>
    ref.watch(settingsRepositoryProvider).get(SettingKeys.billingCutoffDay));

final stuPaymentsProvider = StreamProvider<List<Payment>>(
    (ref) => ref.watch(paymentsRepositoryProvider).watchAll());

final stuRecordsProvider = StreamProvider<List<AttendanceRecord>>(
    (ref) => ref.watch(attendanceRepositoryProvider).watchRecords());

/// The stored photo; only read when the student has one.
final stuPhotoProvider =
    FutureProvider.family<Uint8List?, ({String id, bool has})>((ref, key) async {
  if (!key.has) return null;
  return ref.read(studentsRepositoryProvider).getPhoto(key.id);
});

/// One line of the students list / table.
class StudentRow {
  const StudentRow({
    required this.student,
    required this.batches,
    this.dues,
    this.lastPaidOn,
    this.attendancePercent,
    this.subjectNames = const <String, String>{},
  });

  final Student student;

  /// Subject name by subject id, so a batch can be named "subject · batch".
  final Map<String, String> subjectNames;

  /// "Physics — HSC · 10 AM batch" for [b] (the bare name without a subject).
  String labelOf(AppLocalizations l10n, Batch b) =>
      batchLabel(l10n, subjectNames[b.subjectId] ?? '', b.name);

  /// Every batch of the row as one label, one after the other.
  String batchesText(AppLocalizations l10n, {String separator = ' | '}) =>
      batches.map((Batch b) => labelOf(l10n, b)).join(separator);

  /// Batches of the open enrollments (all of them for a student who left).
  final List<Batch> batches;

  /// `null` when nothing is open.
  final StudentDues? dues;
  final LocalDate? lastPaidOn;
  final int? attendancePercent;

  String get id => student.id;
}

/// Pure assembly of the rows (unit-testable).
List<StudentRow> buildStudentRows({
  required List<Student> students,
  required List<Enrollment> enrollments,
  required List<Batch> batches,
  required DuesReport report,
  required List<Payment> payments,
  required List<AttendanceRecord> records,
  List<Subject> subjects = const <Subject>[],
}) {
  final Map<String, String> subjectNames = <String, String>{
    for (final Subject s in subjects) s.id: s.name,
  };
  final Map<String, Batch> batchById = <String, Batch>{
    for (final Batch b in batches) b.id: b,
  };
  final Map<String, StudentDues> duesBy = <String, StudentDues>{};
  for (final StudentDues d in report.inactive) {
    duesBy[d.studentId] = d;
  }
  for (final StudentDues d in report.active) {
    duesBy[d.studentId] = d;
  }
  final Map<String, LocalDate> lastPaid = <String, LocalDate>{};
  for (final Payment p in payments) {
    if (p.waived) continue;
    final LocalDate? cur = lastPaid[p.studentId];
    if (cur == null || p.paidOn.isAfter(cur)) lastPaid[p.studentId] = p.paidOn;
  }
  final Map<String, List<Enrollment>> enrBy = <String, List<Enrollment>>{};
  for (final Enrollment e in enrollments) {
    (enrBy[e.studentId] ??= <Enrollment>[]).add(e);
  }
  final Map<String, List<AttendanceRecord>> recBy =
      <String, List<AttendanceRecord>>{};
  for (final AttendanceRecord r in records) {
    (recBy[r.studentId] ??= <AttendanceRecord>[]).add(r);
  }

  final List<StudentRow> rows = <StudentRow>[];
  for (final Student s in students) {
    final List<Enrollment> mine = enrBy[s.id] ?? const <Enrollment>[];
    final bool left = s.status == StudentStatus.left;
    final Set<String> seen = <String>{};
    final List<Batch> shown = <Batch>[];
    for (final Enrollment e in mine) {
      if (!left && e.endDate != null) continue;
      final Batch? b = batchById[e.batchId];
      if (b != null && seen.add(b.id)) shown.add(b);
    }
    shown.sort((Batch a, Batch b) => a.sortOrder.compareTo(b.sortOrder));

    var tally = const AttendanceTally();
    final List<AttendanceRecord> myRecords =
        recBy[s.id] ?? const <AttendanceRecord>[];
    for (final Enrollment e in mine) {
      final List<({LocalDate date, AttendanceStatus status})> sessions =
          <({LocalDate date, AttendanceStatus status})>[
        for (final AttendanceRecord r in myRecords)
          if (r.batchId == e.batchId) (date: r.date, status: r.status),
      ];
      final AttendanceTally t =
          AttendanceStats.tallyWithin(sessions, from: e.joinDate, to: e.endDate);
      tally = AttendanceTally(
        present: tally.present + t.present,
        absent: tally.absent + t.absent,
        late: tally.late + t.late,
        leave: tally.leave + t.leave,
      );
    }
    rows.add(StudentRow(
      student: s,
      batches: shown,
      dues: duesBy[s.id],
      lastPaidOn: lastPaid[s.id],
      attendancePercent: tally.percent,
      subjectNames: subjectNames,
    ));
  }
  return rows;
}

/// The list rows, live.
final stuRowsProvider = Provider<AsyncValue<List<StudentRow>>>((ref) {
  final people = combine3(
    ref.watch(stuRosterProvider),
    ref.watch(allEnrollmentsProvider),
    ref.watch(stuBatchesProvider),
    (s, e, b) => (s: s, e: e, b: b),
  );
  // Subjects only decorate the batch label: never block the list on them.
  final List<Subject> subjects = ref.watch(stuSubjectsProvider).value ?? const <Subject>[];
  final money = combine3(
    ref.watch(duesReportProvider),
    ref.watch(stuPaymentsProvider),
    ref.watch(stuRecordsProvider),
    (r, p, a) => (r: r, p: p, a: a),
  );
  return combine2(
    people,
    money,
    (x, y) => buildStudentRows(
      students: x.s,
      enrollments: x.e,
      batches: x.b,
      report: y.r,
      payments: y.p,
      records: y.a,
      subjects: subjects,
    ),
  );
});

/// Search / filter state of the list (kept by the screen).
class StudentFilter {
  const StudentFilter({
    this.query = '',
    this.batchId,
    this.onlyDues = false,
    this.onlyLeft = false,
  });

  final String query;
  final String? batchId;
  final bool onlyDues;
  final bool onlyLeft;

  StudentFilter copyWith({
    String? query,
    String? batchId,
    bool clearBatch = false,
    bool? onlyDues,
    bool? onlyLeft,
  }) =>
      StudentFilter(
        query: query ?? this.query,
        batchId: clearBatch ? null : (batchId ?? this.batchId),
        onlyDues: onlyDues ?? this.onlyDues,
        onlyLeft: onlyLeft ?? this.onlyLeft,
      );
}

/// Name, roll or phone match; Bangla and ASCII digits both work.
bool studentMatchesQuery(Student s, String rawQuery) {
  final String q = AppFormat.toAsciiDigits(rawQuery.trim()).toLowerCase();
  if (q.isEmpty) return true;
  if (s.name.toLowerCase().contains(q)) return true;
  final String? roll = s.roll;
  if (roll != null && AppFormat.toAsciiDigits(roll).toLowerCase() == q) {
    return true;
  }
  final String digits = q.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length >= 3) {
    for (final String? p in <String?>[s.phone, s.guardianPhone]) {
      if (p != null && p.contains(digits)) return true;
    }
  }
  return false;
}

/// Students with a batch at [placeId] (everyone when null): the place filter
/// of the header (2+ places).
List<StudentRow> rowsAtPlace(List<StudentRow> rows, String? placeId) => placeId == null
    ? rows
    : <StudentRow>[
        for (final StudentRow r in rows)
          if (r.batches.any((Batch b) => b.placeId == placeId)) r,
      ];

List<StudentRow> applyStudentFilter(List<StudentRow> rows, StudentFilter f) {
  return <StudentRow>[
    for (final StudentRow r in rows)
      if ((r.student.status == StudentStatus.left) == f.onlyLeft &&
          (f.batchId == null ||
              r.batches.any((Batch b) => b.id == f.batchId)) &&
          (!f.onlyDues || r.dues != null) &&
          studentMatchesQuery(r.student, f.query))
        r,
  ];
}
