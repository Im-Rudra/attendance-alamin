// Public surface of the attendance feature (plan section 1 #32). STUB by
// M5-A; bodies by M7-A. Signatures are frozen.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/core/time/local_date.dart';

/// Opens the roll call of [batchId] on [date] (session chooser when needed).
Future<void> openRollCallForBatchDate(BuildContext context, {required String batchId, required LocalDate date}) async {}

/// Batch detail › হাজিরা tab.
class BatchAttendanceTab extends StatelessWidget {
  const BatchAttendanceTab({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Attendance % and the last sessions of one enrolment (student profile).
class EnrollmentAttendanceSummary extends StatelessWidget {
  const EnrollmentAttendanceSummary({super.key, required this.studentId, required this.batchId});

  final String studentId, batchId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
