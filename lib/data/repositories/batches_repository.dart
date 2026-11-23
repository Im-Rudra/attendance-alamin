export 'package:attendance_alamin/data/repositories/delete_impact.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/delete_impact.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';


/// Batches and their fee history (Product F2, 3.1, 3.2).
abstract interface class BatchesRepository {
  /// Live batches (sort order, name, id); archived ones only when asked.
  Stream<List<Batch>> watchAll({bool includeArchived = false});
  Stream<Batch?> watchById(String id);
  Future<Batch?> getById(String id);

  /// Batch + first fee row + slots in one transaction, clash-checked
  /// (throws `ScheduleClashException`). Remembers the billing type as the
  /// device's `last_billing_type`. Returns the new batch id.
  Future<String> create(BatchDraft draft);

  Future<void> rename(String id, String name);
  Future<void> setBillingType(String id, BillingType t);

  /// `null` = default lead, `0` = off, otherwise 1..720.
  Future<void> setReminderLead(String id, int? minutes);
  Future<void> setNotes(String id, String? notes);

  /// Fee history, ascending by effective month.
  Stream<List<FeePeriod>> watchFees(String batchId);

  /// How many (enrollment, month) pairs that are fully paid now would turn
  /// partial if the fee became [amount] from [from] ("N টি মাস আংশিক হয়ে যাবে").
  Future<int> previewPartialMonths(String batchId, int amount, YearMonth from);

  /// Adds or replaces the fee row effective from [from]; earlier months keep
  /// their fee.
  Future<void> setFee(String batchId, int amount, YearMonth from);

  /// Archives the batch on [on]; every open enrollment (no end month) gets
  /// [lastBillableMonth] as its last billable month.
  Future<void> archive(String id,
      {required LocalDate on, required YearMonth lastBillableMonth});

  /// The save-time clash check of an un-archive (the batch's slots against
  /// every live batch, from today).
  Future<SlotCheckResult> previewUnarchive(String id);

  /// Un-archives. Throws `ScheduleClashException` on clashes unless
  /// [acceptClashes]. Enrollments that were ended by the archive (end month
  /// set, no end date) reopen. Returns the number of gap months (largest
  /// per-enrollment count of months between the old last billable month and
  /// last month); with [waiveGap] those months get waived rows.
  ///
  /// [on] is the day classes started again (default today). Billing restarts
  /// from that month, so the gap ends the month before it. When given it must
  /// lie between the day after the batch was finished and today (throws
  /// `dateInvalid` / `dateInFuture`).
  Future<int> unarchive(String id,
      {bool acceptClashes = false, bool waiveGap = true, LocalDate? on});

  Future<DeleteImpact> deleteImpact(String id);

  /// Tombstones the batch with its slots, exceptions, fees, enrollments,
  /// attendance and payments.
  Future<void> softDelete(String id);
}
