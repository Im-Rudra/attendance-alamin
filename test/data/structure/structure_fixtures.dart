// Shared harness for test/data/structure (not a test file itself).

import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/db_queries.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/repositories/drift/batches_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/schedule_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/subjects_repository_drift.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../db/db_fixtures.dart' show center, dev, openMemoryDb, t0;

export '../db/db_fixtures.dart' show center, dev, t0;

/// A clock the test can move.
class TestClock implements Clock {
  TestClock(this.now);

  DateTime now;

  @override
  DateTime nowUtc() => now;
}

/// In-memory database + the three drift repositories on a movable clock
/// (starts at 2026-11-20 15:00 Dhaka = [t0]).
class Harness {
  Harness._(this.db, this.clock, this.stamper)
      : subjects = DriftSubjectsRepository(db, stamper),
        batches = DriftBatchesRepository(db, stamper),
        schedule = DriftScheduleRepository(db, stamper);

  factory Harness() {
    final db = openMemoryDb();
    final clock =
        TestClock(DateTime.fromMillisecondsSinceEpoch(t0, isUtc: true));
    return Harness._(db, clock, SyncStamper(clock: clock, deviceId: dev));
  }

  final AppDatabase db;
  final TestClock clock;
  final SyncStamper stamper;
  final DriftSubjectsRepository subjects;
  final DriftBatchesRepository batches;
  final DriftScheduleRepository schedule;

  int get nowMs => clock.now.millisecondsSinceEpoch;

  /// Moves the clock to [utc].
  void setNow(DateTime utc) => clock.now = utc;

  Future<String> subject(String name) => subjects.create(name: name);

  /// Creates a batch (fee from Nov 2026, slots from [today]).
  Future<String> batch(
    String subjectId,
    String name, {
    required List<SlotDraft> slots,
    BillingType billing = BillingType.prepaid,
    int fee = 1000,
    int? lead,
    LocalDate? slotsFrom,
  }) =>
      batches.create(BatchDraft(
        subjectId: subjectId,
        name: name,
        billingType: billing,
        reminderLeadMin: lead,
        monthlyFee: fee,
        feeFrom: const YearMonth(2026, 11),
        slots: slots,
        slotsFrom: slotsFrom ?? today,
      ));

  /// Physics A: prepaid 1000, Sat / Mon / Wed 16:00-17:00.
  Future<String> physicsA() async => batch(
        await subject('Physics'),
        'Physics A',
        slots: [slot(sat, 960, 1020), slot(mon, 960, 1020), slot(wed, 960, 1020)],
      );

  /// Chem B: postpaid 800, lead 30, Sun / Tue 10:00-11:00.
  Future<String> chemB() async => batch(
        await subject('Chemistry'),
        'Chem B',
        slots: [slot(sun, 600, 660), slot(tue, 600, 660)],
        billing: BillingType.postpaid,
        fee: 800,
        lead: 30,
      );

  Future<List<BatchSchedule>> loaded() => loadAllSchedules(db, center);

  Future<BatchSchedule> scheduleOf(String batchId) async =>
      (await loaded()).firstWhere((b) => b.batch.id == batchId);

  /// The id of the live slot of [batchId] on [weekday] (first by start).
  Future<String> slotId(String batchId, int weekday) async {
    final bs = await scheduleOf(batchId);
    return bs.slots.firstWhere((s) => s.weekday == weekday).id;
  }

  /// Drafts mirroring the batch's current live slots (ids kept).
  Future<List<SlotDraft>> draftsOf(String batchId) async {
    final bs = await scheduleOf(batchId);
    return [
      for (final s in bs.slots)
        SlotDraft(
            id: s.id,
            weekday: s.weekday,
            startMin: s.startMin,
            endMin: s.endMin),
    ];
  }

  // ---- raw rows (tombstoned ones included)

  Future<SubjectRow> subjectRow(String id) =>
      (db.select(db.subjects)..where((t) => t.id.equals(id))).getSingle();

  Future<BatchRow> batchRow(String id) =>
      (db.select(db.batches)..where((t) => t.id.equals(id))).getSingle();

  Future<SlotRow> slotRow(String id) =>
      (db.select(db.batchSlots)..where((t) => t.id.equals(id))).getSingle();

  Future<List<SlotRow>> slotRows(String batchId) =>
      (db.select(db.batchSlots)..where((t) => t.batchId.equals(batchId)))
          .get();

  Future<ExceptionRow> exceptionRow(String id) =>
      (db.select(db.scheduleExceptions)..where((t) => t.id.equals(id)))
          .getSingle();

  Future<List<ExceptionRow>> exceptionRows(String batchId) =>
      (db.select(db.scheduleExceptions)
            ..where((t) => t.batchId.equals(batchId)))
          .get();

  Future<EnrollmentRow> enrollmentRow(String id) =>
      (db.select(db.enrollments)..where((t) => t.id.equals(id))).getSingle();
}

// ---- weekdays (ISO) and small builders

const mon = 1, tue = 2, wed = 3, thu = 4, fri = 5, sat = 6, sun = 7;

SlotDraft slot(int weekday, int startMin, int endMin) =>
    SlotDraft(weekday: weekday, startMin: startMin, endMin: endMin);

LocalDate d(int y, int m, int day) => LocalDate(y, m, day);

/// 2026-11-20, a Friday.
const today = LocalDate(2026, 11, 20);

/// Runs [f] and returns the clash exception it throws (fails otherwise).
Future<ScheduleClashException> expectClash(Future<void> Function() f) async {
  try {
    await f();
  } on ScheduleClashException catch (e) {
    return e;
  }
  fail('expected a ScheduleClashException');
}

/// Asserts the sync stamp of a freshly inserted row.
void expectInserted(
    {required int createdAt,
    required int updatedAt,
    required int rev,
    required String deviceId,
    int? deletedAt,
    int? at}) {
  final t = at ?? t0;
  expect(createdAt, t, reason: 'createdAt');
  expect(updatedAt, t, reason: 'updatedAt');
  expect(rev, 1, reason: 'rev');
  expect(deviceId, dev, reason: 'deviceId');
  expect(deletedAt, isNull, reason: 'deletedAt');
}

/// Fills the sync columns of an insert (created = updated = [t0], rev 1).
T stamped<T>(
        T Function(
                {Value<int> createdAt,
                Value<int> updatedAt,
                Value<String> deviceId})
            copy) =>
    copy(
        createdAt: const Value(t0),
        updatedAt: const Value(t0),
        deviceId: const Value(dev));
