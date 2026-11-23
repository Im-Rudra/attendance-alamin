import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/student.dart';

/// Student <-> batch links, their fee overrides and roll-call rosters
/// (plan M4-B, Product 3.1/3.2/3.6).
/// The earliest join date the app accepts.
const LocalDate kEarliestJoinDate = LocalDate(2015, 1, 1);

abstract interface class EnrollmentsRepository {
  Stream<List<Enrollment>> watchAll();
  Stream<List<Enrollment>> watchForStudent(String studentId);
  Stream<List<Enrollment>> watchForBatch(String batchId);

  /// Dues-engine input (`loadEnrollmentTerms` + `watchComposite`).
  Stream<List<EnrollmentTerms>> watchTerms();

  /// New enrollment; [feeOverride] is stored effective from [startMonth].
  /// Throws `duplicateOpenEnrollment` when the student already has an open
  /// enrollment in the batch, `batchArchived` for an archived batch.
  Future<String> enroll({
    required String studentId,
    required String batchId,
    required LocalDate joinDate,
    required YearMonth startMonth,
    int? feeOverride,
  });

  /// Changes the FBM. An override that started at the old FBM moves with it
  /// when the FBM moves earlier.
  Future<void> setStartMonth(String enrollmentId, YearMonth m);

  /// Fee override from [from] (`null` clears the override from that month).
  Future<void> setOverride(String enrollmentId, int? amount,
      {required YearMonth from});

  /// Live override history, ascending by month.
  Stream<List<FeePeriod>> watchOverrides(String enrollmentId);

  /// Moves the roll-call join date of one enrollment to [joinDate] (its
  /// calendar day; the time of day is ignored). The first billable month is
  /// not touched. Throws `dateInvalid` (field `joinDate`) when the date is
  /// before [kEarliestJoinDate] or after the enrollment's end date, and
  /// `dateInvalid` (field `overlap`) when the enrollment would then overlap
  /// another enrollment of the same student in the same batch. The same date
  /// again is a no-op.
  Future<void> updateJoinDate(String enrollmentId, DateTime joinDate);

  /// Removes the student from this batch only: end date + LBM.
  Future<void> end(String enrollmentId,
      {required LocalDate on, required YearMonth lastBillableMonth});

  /// Product 3.6 listing: students whose enrollment covers [date] and who
  /// were active on [date]; sorted by roll then name.
  Future<List<Student>> rosterOn(String batchId, LocalDate date);
}
