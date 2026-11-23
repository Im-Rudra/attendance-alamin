// In-memory fakes of the M4-B repositories for widget / controller tests
// (plan 2.11: widget tests use fakes, not drift).
//
// They mirror the observable behaviour (deterministic ids, tombstone-free
// reads, receipts grouping rows, roll-call upserts) without validation. Set
// `failNext` on any fake to make its next write throw that exception.

import 'dart:async';
import 'dart:typed_data';

import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/data/repositories/enrollments_repository.dart';
import 'package:attendance_alamin/data/repositories/other_income_repository.dart';
import 'package:attendance_alamin/data/repositories/payments_repository.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

/// Change notifications + `failNext` shared by the fakes.
mixin _FakeBase {
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Thrown (once) by the next write.
  AppException? failNext;

  /// Number of writes performed (successful or not).
  int writes = 0;

  void _write() {
    writes++;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  void _changed() => _changes.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  Future<void> dispose() => _changes.close();
}

int _rollThenName(Student a, Student b) {
  final ra = int.tryParse(a.roll ?? '');
  final rb = int.tryParse(b.roll ?? '');
  if (ra != null && rb != null && ra != rb) return ra.compareTo(rb);
  if (ra != null && rb == null) return -1;
  if (ra == null && rb != null) return 1;
  return a.name.compareTo(b.name);
}

class FakeStudentsRepository with _FakeBase implements StudentsRepository {
  FakeStudentsRepository({List<Student> students = const []})
      : students = [...students];

  final List<Student> students;

  /// When set, [create] waits for it (tests of typing during a slow save).
  Future<void>? createGate;
  final Map<String, Uint8List> photos = {};
  DeleteImpact impact = const DeleteImpact(sessions: 0, payments: 0, students: 1);

  /// `today` used by [rejoin]; defaults to 2026-11-20.
  LocalDate today = const LocalDate(2026, 11, 20);

  /// The "back from" date and waive choice of the last [rejoin].
  LocalDate? rejoinedOn;
  bool? rejoinWaived;

  Student? _find(String id) {
    for (final s in students) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _replace(Student s) {
    final i = students.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      students[i] = s;
    } else {
      students.add(s);
    }
    _changed();
  }

  Student _copy(Student s,
          {StudentStatus? status,
          LocalDate? leftDate,
          bool clearLeft = false,
          bool? hasPhoto}) =>
      Student(
        id: s.id,
        name: s.name,
        admissionDate: s.admissionDate,
        status: status ?? s.status,
        roll: s.roll,
        phone: s.phone,
        guardianName: s.guardianName,
        guardianPhone: s.guardianPhone,
        leftDate: clearLeft ? null : (leftDate ?? s.leftDate),
        notes: s.notes,
        hasPhoto: hasPhoto ?? s.hasPhoto,
      );

  @override
  Stream<List<Student>> watchAll({StudentStatus? status}) => _watch(() => [
        for (final s in students)
          if (status == null || s.status == status) s,
      ]..sort(_rollThenName));

  @override
  Stream<Student?> watchById(String id) => _watch(() => _find(id));

  @override
  Future<Student?> getById(String id) async => _find(id);

  @override
  Future<List<Student>> findDuplicates(
      {required String name, String? phone}) async {
    final n = name.trim().toLowerCase();
    return [
      for (final s in students)
        if (s.name.trim().toLowerCase() == n ||
            (phone != null && (s.phone == phone || s.guardianPhone == phone)))
          s,
    ];
  }

  @override
  Future<String> nextRoll() async {
    var max = 0;
    for (final s in students) {
      final v = int.tryParse(s.roll ?? '');
      if (v != null && v > max) max = v;
    }
    return (max + 1).toString().padLeft(2, '0');
  }

  @override
  Future<String> create(StudentDraft d) async {
    final Future<void>? gate = createGate;
    if (gate != null) await gate;
    _write();
    final id = Ids.v4();
    _replace(Student(
      id: id,
      name: d.name.trim(),
      admissionDate: d.admissionDate,
      status: StudentStatus.active,
      roll: d.roll,
      phone: d.phone,
      guardianName: d.guardianName,
      guardianPhone: d.guardianPhone,
      notes: d.notes,
    ));
    return id;
  }

  @override
  Future<void> update(String id, StudentDraft d) async {
    _write();
    final s = _find(id);
    if (s == null) return;
    _replace(Student(
      id: id,
      name: d.name.trim(),
      admissionDate: d.admissionDate,
      status: s.status,
      roll: d.roll,
      phone: d.phone,
      guardianName: d.guardianName,
      guardianPhone: d.guardianPhone,
      leftDate: s.leftDate,
      notes: d.notes,
      hasPhoto: s.hasPhoto,
    ));
  }

  @override
  Future<void> markLeft(String id,
      {required LocalDate on,
      required Map<String, YearMonth> lastBillableByEnrollment}) async {
    _write();
    final s = _find(id);
    if (s != null) {
      _replace(_copy(s, status: StudentStatus.left, leftDate: on));
    }
  }

  @override
  Future<int> rejoin(String id, {required bool waiveGap, LocalDate? on}) async {
    _write();
    final s = _find(id);
    if (s == null || s.status != StudentStatus.left) return 0;
    rejoinedOn = on ?? today;
    rejoinWaived = waiveGap;
    _replace(_copy(s, status: StudentStatus.active, clearLeft: true));
    final left = s.leftDate;
    if (left == null) return 0;
    final lbm = DuesEngine.defaultLastBillableMonth(left);
    final gap = lbm.monthsUntil((on ?? today).yearMonth) - 1;
    return gap < 0 ? 0 : gap;
  }

  @override
  Future<Uint8List?> getPhoto(String id) async => photos[id];

  @override
  Future<void> setPhoto(String id, Uint8List? jpeg) async {
    _write();
    if (jpeg != null && jpeg.length > kMaxPhotoBytes) {
      throw const _FakeValidation('photoTooLarge');
    }
    if (jpeg == null || jpeg.isEmpty) {
      photos.remove(id);
    } else {
      photos[id] = jpeg;
    }
    final s = _find(id);
    if (s != null) _replace(_copy(s, hasPhoto: photos.containsKey(id)));
  }

  @override
  Future<DeleteImpact> deleteImpact(String id) async => impact;

  @override
  Future<void> softDelete(String id) async {
    _write();
    students.removeWhere((s) => s.id == id);
    photos.remove(id);
    _changed();
  }
}

/// Validation failure thrown by the fakes (same code strings as `ErrorCodes`).
final class _FakeValidation extends AppException {
  const _FakeValidation(super.code);
}

class FakeEnrollmentsRepository with _FakeBase implements EnrollmentsRepository {
  FakeEnrollmentsRepository({
    List<Enrollment> enrollments = const [],
    List<EnrollmentTerms> terms = const [],
    List<Student> students = const [],
  })  : enrollments = [...enrollments],
        terms = [...terms],
        students = [...students];

  final List<Enrollment> enrollments;

  /// Returned by [watchTerms] as given (no derivation from [enrollments]).
  final List<EnrollmentTerms> terms;

  /// Used by [rosterOn].
  final List<Student> students;
  final Map<String, List<FeePeriod>> overrides = {};

  Enrollment? _find(String id) {
    for (final e in enrollments) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _replace(Enrollment e) {
    final i = enrollments.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      enrollments[i] = e;
    } else {
      enrollments.add(e);
    }
    _changed();
  }

  @override
  Stream<List<Enrollment>> watchAll() => _watch(() => [...enrollments]);

  @override
  Stream<List<Enrollment>> watchForStudent(String studentId) => _watch(() => [
        for (final e in enrollments)
          if (e.studentId == studentId) e,
      ]);

  @override
  Stream<List<Enrollment>> watchForBatch(String batchId) => _watch(() => [
        for (final e in enrollments)
          if (e.batchId == batchId) e,
      ]);

  @override
  Stream<List<EnrollmentTerms>> watchTerms() => _watch(() => [...terms]);

  @override
  Future<String> enroll({
    required String studentId,
    required String batchId,
    required LocalDate joinDate,
    required YearMonth startMonth,
    int? feeOverride,
  }) async {
    _write();
    for (final e in enrollments) {
      if (e.studentId == studentId && e.batchId == batchId && e.endDate == null) {
        throw const _FakeValidation('duplicateOpenEnrollment');
      }
    }
    final id = Ids.v4();
    _replace(Enrollment(
      id: id,
      studentId: studentId,
      batchId: batchId,
      joinDate: joinDate,
      startMonth: startMonth,
    ));
    if (feeOverride != null) {
      overrides[id] = [FeePeriod(effective: startMonth, amount: feeOverride)];
    }
    return id;
  }

  @override
  Future<void> setStartMonth(String enrollmentId, YearMonth m) async {
    _write();
    final e = _find(enrollmentId);
    if (e == null) return;
    _replace(Enrollment(
      id: e.id,
      studentId: e.studentId,
      batchId: e.batchId,
      joinDate: e.joinDate,
      startMonth: m,
      endMonth: e.endMonth,
      endDate: e.endDate,
      notes: e.notes,
    ));
  }

  @override
  Future<void> setOverride(String enrollmentId, int? amount,
      {required YearMonth from}) async {
    _write();
    final list = overrides.putIfAbsent(enrollmentId, () => [])
      ..removeWhere((f) => f.effective == from)
      ..add(FeePeriod(effective: from, amount: amount))
      ..sort((a, b) => a.effective.compareTo(b.effective));
    overrides[enrollmentId] = list;
    _changed();
  }

  @override
  Stream<List<FeePeriod>> watchOverrides(String enrollmentId) =>
      _watch(() => [...?overrides[enrollmentId]]);

  @override
  Future<void> updateJoinDate(String enrollmentId, DateTime joinDate) async {
    _write();
    final e = _find(enrollmentId);
    if (e == null) return;
    _replace(Enrollment(
      id: e.id,
      studentId: e.studentId,
      batchId: e.batchId,
      joinDate: LocalDate(joinDate.year, joinDate.month, joinDate.day),
      startMonth: e.startMonth,
      endMonth: e.endMonth,
      endDate: e.endDate,
      notes: e.notes,
    ));
  }

  @override
  Future<void> end(String enrollmentId,
      {required LocalDate on, required YearMonth lastBillableMonth}) async {
    _write();
    final e = _find(enrollmentId);
    if (e == null) return;
    _replace(Enrollment(
      id: e.id,
      studentId: e.studentId,
      batchId: e.batchId,
      joinDate: e.joinDate,
      startMonth: e.startMonth,
      endMonth: lastBillableMonth,
      endDate: on,
      notes: e.notes,
    ));
  }

  @override
  Future<List<Student>> rosterOn(String batchId, LocalDate date) async {
    final ids = {
      for (final e in enrollments)
        if (e.batchId == batchId && e.coversDate(date)) e.studentId,
    };
    return [
      for (final s in students)
        if (ids.contains(s.id)) s,
    ]..sort(_rollThenName);
  }
}

class FakePaymentsRepository with _FakeBase implements PaymentsRepository {
  FakePaymentsRepository({
    List<Payment> payments = const [],
    Map<String, String> batchOfEnrollment = const {},
  })  : payments = [...payments],
        batchOfEnrollment = {...batchOfEnrollment};

  final List<Payment> payments;

  /// Enrollment id -> batch id, used to fill `Payment.batchId`.
  final Map<String, String> batchOfEnrollment;

  /// `paidOn` of waivers.
  LocalDate today = const LocalDate(2026, 11, 20);

  @override
  Stream<List<Payment>> watchAll() => _watch(() => _recordingOrder(payments));

  /// Newest payment date first; on one date the receipt added last first
  /// (the drift repository's order).
  static List<Payment> _recordingOrder(Iterable<Payment> rows) {
    final list = [...rows];
    final added = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      added.putIfAbsent(list[i].receiptId, () => i);
    }
    return list
      ..sort((a, b) {
        final d = b.paidOn.compareTo(a.paidOn);
        if (d != 0) return d;
        return added[b.receiptId]!.compareTo(added[a.receiptId]!);
      });
  }

  @override
  Stream<List<Payment>> watchForStudent(String studentId) => _watch(() =>
      _recordingOrder([
        for (final p in payments)
          if (p.studentId == studentId) p,
      ]));

  @override
  Stream<List<PaymentFact>> watchFacts() => _watch(() => [
        for (final p in payments)
          PaymentFact(
            enrollmentId: p.enrollmentId,
            month: p.billingMonth,
            amount: p.amount,
            waived: p.waived,
          ),
      ]);

  List<Payment> _rows(String receiptId, PaymentDraft d) {
    final sums = <YearMonth, int>{};
    for (final a in d.allocations) {
      sums[a.month] = (sums[a.month] ?? 0) + a.amount;
    }
    final months = sums.keys.toList()..sort();
    return [
      for (final m in months)
        Payment(
          id: Ids.v4(),
          receiptId: receiptId,
          studentId: d.studentId,
          enrollmentId: d.enrollmentId,
          batchId: batchOfEnrollment[d.enrollmentId] ?? '',
          billingMonth: m,
          amount: sums[m] ?? 0,
          paidOn: d.paidOn,
          method: d.method,
          note: d.note,
        ),
    ];
  }

  @override
  Future<String> record(PaymentDraft d) async {
    _write();
    final receiptId = Ids.v4();
    payments.addAll(_rows(receiptId, d));
    _changed();
    return receiptId;
  }

  @override
  Future<void> updateReceipt(String receiptId, PaymentDraft d) async {
    _write();
    payments.removeWhere((p) => p.receiptId == receiptId && !p.waived);
    payments.addAll(_rows(receiptId, d));
    _changed();
  }

  @override
  Future<void> deleteReceipt(String receiptId) async {
    _write();
    payments.removeWhere((p) => p.receiptId == receiptId && !p.waived);
    _changed();
  }

  @override
  Future<List<Payment>> receipt(String receiptId) async => [
        for (final p in payments)
          if (p.receiptId == receiptId && !p.waived) p,
      ]..sort((a, b) => a.billingMonth.compareTo(b.billingMonth));

  @override
  Future<void> waive(String enrollmentId, YearMonth month,
      {String? reason}) async {
    _write();
    final id = Ids.waiver(enrollmentId, month);
    payments.removeWhere((p) => p.id == id);
    String studentId = '';
    for (final p in payments) {
      if (p.enrollmentId == enrollmentId) studentId = p.studentId;
    }
    payments.add(Payment(
      id: id,
      receiptId: id,
      studentId: studentId,
      enrollmentId: enrollmentId,
      batchId: batchOfEnrollment[enrollmentId] ?? '',
      billingMonth: month,
      amount: 0,
      paidOn: today,
      method: PaymentMethod.other,
      note: reason,
      waived: true,
    ));
    _changed();
  }

  @override
  Future<void> unwaive(String enrollmentId, YearMonth month) async {
    _write();
    payments.removeWhere((p) =>
        p.waived && p.enrollmentId == enrollmentId && p.billingMonth == month);
    _changed();
  }
}

class FakeAttendanceRepository with _FakeBase implements AttendanceRepository {
  FakeAttendanceRepository({
    List<AttendanceSession> sessions = const [],
    List<AttendanceRecord> records = const [],
  })  : sessions = [...sessions],
        records = [...records];

  final List<AttendanceSession> sessions;
  final List<AttendanceRecord> records;

  /// Occurrence ids whose cancel was removed by `removeCancel`.
  final List<String> uncancelled = [];

  void _save(AttendanceSession s, Map<String, AttendanceStatus> statuses) {
    sessions
      ..removeWhere((x) => x.id == s.id)
      ..add(s);
    records
      ..removeWhere((r) => r.sessionId == s.id)
      ..addAll([
        for (final e in statuses.entries)
          AttendanceRecord(
            id: Ids.record(s.occ, e.key),
            sessionId: s.id,
            batchId: s.batchId,
            studentId: e.key,
            date: s.date,
            status: e.value,
          ),
      ]);
    _changed();
  }

  @override
  Future<(AttendanceSession, List<AttendanceRecord>)?> getSession(
      String occ) async {
    final id = Ids.sessionForOcc(occ);
    for (final s in sessions) {
      if (s.id == id) {
        return (s, [
          for (final r in records)
            if (r.sessionId == id) r,
        ]);
      }
    }
    return null;
  }

  @override
  Future<void> saveRollCall({
    required Occurrence occurrence,
    required Map<String, AttendanceStatus> statuses,
    String? note,
    bool removeCancel = false,
  }) async {
    _write();
    final o = occurrence;
    if (removeCancel) uncancelled.add(o.occ);
    _save(
      AttendanceSession(
        id: Ids.sessionForOcc(o.occ),
        occ: o.occ,
        batchId: o.batchId,
        slotId: o.slotId,
        originalDate: o.originalDate,
        exceptionId: o.exceptionId,
        date: o.date,
        startMin: o.startMin,
        endMin: o.endMin,
        note: note,
      ),
      statuses,
    );
  }

  @override
  Future<String> saveAdHocRollCall({
    required String batchId,
    required LocalDate date,
    required int startMin,
    required int endMin,
    required Map<String, AttendanceStatus> statuses,
  }) async {
    _write();
    final exceptionId = Ids.v4();
    final occ = OccId.extra(exceptionId);
    _save(
      AttendanceSession(
        id: Ids.sessionForOcc(occ),
        occ: occ,
        batchId: batchId,
        exceptionId: exceptionId,
        date: date,
        startMin: startMin,
        endMin: endMin,
      ),
      statuses,
    );
    return occ;
  }

  @override
  Future<void> deleteSession(String occ) async {
    _write();
    final id = Ids.sessionForOcc(occ);
    sessions.removeWhere((s) => s.id == id);
    records.removeWhere((r) => r.sessionId == id);
    _changed();
  }

  @override
  Stream<List<SessionSummary>> watchSummaries(
          {String? batchId, LocalDate? from, LocalDate? to}) =>
      _watch(() {
        final out = <SessionSummary>[];
        for (final s in sessions) {
          if (batchId != null && s.batchId != batchId) continue;
          if (from != null && s.date.isBefore(from)) continue;
          if (to != null && s.date.isAfter(to)) continue;
          out.add(SessionSummary(
            session: s,
            tally: AttendanceStats.tally([
              for (final r in records)
                if (r.sessionId == s.id) r.status,
            ]),
          ));
        }
        out.sort((a, b) {
          final d = a.session.date.compareTo(b.session.date);
          return d != 0 ? d : a.session.startMin.compareTo(b.session.startMin);
        });
        return out;
      });

  @override
  Stream<List<AttendanceRecord>> watchRecords(
          {String? studentId, String? batchId}) =>
      _watch(() => [
            for (final r in records)
              if ((studentId == null || r.studentId == studentId) &&
                  (batchId == null || r.batchId == batchId))
                r,
          ]..sort((a, b) => a.date.compareTo(b.date)));
}

class FakeOtherIncomeRepository with _FakeBase implements OtherIncomeRepository {
  FakeOtherIncomeRepository({List<OtherIncome> items = const []})
      : items = [...items];

  final List<OtherIncome> items;

  @override
  Stream<List<OtherIncome>> watchBetween(LocalDate from, LocalDate to) =>
      _watch(() => [
            for (final i in items)
              if (!i.paidOn.isBefore(from) && !i.paidOn.isAfter(to)) i,
          ]..sort((a, b) => a.paidOn.compareTo(b.paidOn)));

  @override
  Future<String> add(OtherIncome draft) async {
    _write();
    final id = Ids.v4();
    items.add(OtherIncome(
      id: id,
      studentId: draft.studentId,
      label: draft.label.trim(),
      amount: draft.amount,
      paidOn: draft.paidOn,
      method: draft.method,
      note: draft.note,
    ));
    _changed();
    return id;
  }

  @override
  Future<void> softDelete(String id) async {
    _write();
    items.removeWhere((i) => i.id == id);
    _changed();
  }
}
