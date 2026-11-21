// How the attendance widgets open a roll call: through the router (full screen
// on the root navigator) and, where no router exists (widget tests), through a
// plain page route.

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/attendance/ui/batch_roll_call_launcher.dart';
import 'package:attendance_alamin/features/attendance/ui/roll_call_screen.dart';

/// Roll call of one class occurrence.
Future<void> pushRollCallOcc(BuildContext context, String occ) async {
  final GoRouter? router = GoRouter.maybeOf(context);
  if (router != null) {
    await router.push<void>(Routes.rollCall(occ));
    return;
  }
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(builder: (BuildContext _) => RollCallScreen(occ: occ)),
  );
}

/// Roll call of a batch on a date (chooser / ad-hoc when needed).
Future<void> pushRollCallBatchDate(BuildContext context, String batchId, LocalDate date) async {
  final GoRouter? router = GoRouter.maybeOf(context);
  if (router != null) {
    await router.push<void>(Routes.batchRollCall(batchId, date));
    return;
  }
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => BatchRollCallLauncher(batchId: batchId, date: date),
    ),
  );
}
