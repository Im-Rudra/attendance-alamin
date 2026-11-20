// Public surface of the attendance feature (plan section 1 #32). Signatures are
// the frozen M5-A ones; the bodies live in widgets/ (M7-A).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_navigation.dart';

export 'package:attendance_alamin/features/attendance/widgets/batch_attendance_tab.dart'
    show BatchAttendanceTab;
export 'package:attendance_alamin/features/attendance/widgets/enrollment_attendance_summary.dart'
    show EnrollmentAttendanceSummary;

/// Opens the roll call of [batchId] on [date] (session chooser when needed).
Future<void> openRollCallForBatchDate(BuildContext context,
        {required String batchId, required LocalDate date}) =>
    pushRollCallBatchDate(context, batchId, date);
