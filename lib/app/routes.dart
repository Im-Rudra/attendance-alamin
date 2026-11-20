// Route paths (plan M5-A route table). Frozen after M5-A: a new route is a
// Lead amendment. Navigate with `context.go(Routes.batch(id))` or
// `context.push(...)`; ids go in path segments, never in query strings.

import 'package:attendance_alamin/core/time/local_date.dart';

abstract final class Routes {
  // ---- shell branch 0: আজ ----
  static const today = '/today';

  // ---- shell branch 1: ব্যাচ ----
  static const batches = '/batches';
  static const batchNew = '/batches/new';
  static String batch(String batchId) => '/batches/$batchId';
  static String batchEdit(String batchId) => '/batches/$batchId/edit';
  static String batchSlots(String batchId) => '/batches/$batchId/slots';

  /// Roll call launcher for one batch on [date] (`YYYY-MM-DD` in the path).
  static String batchRollCall(String batchId, LocalDate date) =>
      '/batches/$batchId/rollcall/${date.toIso()}';
  static String batchBulkAdd(String batchId) => '/batches/$batchId/bulk-add';

  // ---- shell branch 2: শিক্ষার্থী ----
  static const students = '/students';

  /// New student. To preselect a batch, push with `extra: batchId` (a
  /// String); the id never goes into the URL query.
  static const studentNew = '/students/new';
  static String student(String studentId) => '/students/$studentId';
  static String studentEdit(String studentId) => '/students/$studentId/edit';

  // ---- shell branch 3: বেতন ----
  static const fees = '/fees';
  static String feesStudent(String studentId) => '/fees/s/$studentId';
  static const feesCollection = '/fees/collection';

  // ---- shell branch 4: আরও ----
  static const more = '/more';
  static const moreBackup = '/more/backup';
  static const moreBackupReview = '/more/backup/review';
  static const moreArchived = '/more/archived';
  static const moreLeft = '/more/left';

  /// Message template editor; [kind] is `reminder` or `receipt`.
  static String moreTemplate(String kind) => '/more/templates/$kind';
  static const morePaymentMethods = '/more/payment-methods';
  static const moreHolidays = '/more/holidays';
  static const moreDiagnostics = '/more/diagnostics';
  static const moreHelp = '/more/help';

  // ---- full-screen routes (root navigator, no navigation chrome) ----
  /// Roll call of one class occurrence (notification deep link target).
  static String rollCall(String occ) => '/rollcall/$occ';
  static const search = '/search';
  static const onboarding = '/onboarding';
  static const reminderPriming = '/reminders/priming';

  /// Root path of each shell branch, in branch order (0..4).
  static const branchRoots = <String>[today, batches, students, fees, more];
}
