// BatchRollCallLauncher (route /batches/:batchId/rollcall/:date): roll call of a
// batch on a chosen date, opened from the batch screen, the attendance history
// or the date arrows. One class that day opens directly, 2+ show the chooser
// sheet, none becomes an ad-hoc extra class (Product 3.6).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/attendance/ui/roll_call_screen.dart';

class BatchRollCallLauncher extends StatelessWidget {
  const BatchRollCallLauncher({super.key, required this.batchId, required this.date});

  final String batchId;
  final LocalDate date;

  @override
  Widget build(BuildContext context) => RollCallPage(batchId: batchId, date: date);
}
