// Navigation helpers shared by the Today tiles. Every route goes through the
// router when there is one (widget tests pump screens without a router).

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/features/attendance/attendance_entry.dart';

/// Roll call of one class occurrence (full screen).
void openRollCall(BuildContext context, String occ) {
  // `extra` tells the roll call to come back here on Done.
  GoRouter.maybeOf(context)?.push<void>(Routes.rollCall(occ), extra: Routes.today);
}

/// Switch to another tab (or any route) with `go`.
void goRoute(BuildContext context, String route) {
  GoRouter.maybeOf(context)?.go(route);
}

/// Open a full-screen route on top of the shell.
void pushRoute(BuildContext context, String route) {
  GoRouter.maybeOf(context)?.push<void>(route);
}

/// "Take attendance for another batch": pick a batch, then its roll call for
/// [date] (the launcher handles the session chooser and ad-hoc cases).
Future<void> showBatchPickerSheet(
  BuildContext context, {
  required LocalDate date,
  required List<Batch> batches,
}) async {
  final l10n = context.l10n;
  final List<Batch> sorted = List<Batch>.of(batches)
    ..sort((Batch a, Batch b) => a.sortOrder.compareTo(b.sortOrder));
  final String? id = await showBhorSheet<String>(
    context,
    title: l10n.todayPickBatchTitle,
    builder: (BuildContext ctx) => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < sorted.length; i++)
            BhorListRow(
              title: sorted[i].name,
              trailing: const Icon(Icons.chevron_right),
              divider: i < sorted.length - 1,
              onTap: () => Navigator.of(ctx).pop(sorted[i].id),
            ),
        ],
      ),
    ),
  );
  if (id == null || !context.mounted) return;
  await openRollCallForBatchDate(context, batchId: id, date: date);
}
