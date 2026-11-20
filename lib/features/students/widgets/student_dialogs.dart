// Small text dialogs of the students feature: duplicate guard, rejoin gap
// waiver, delete. Text only, so AlertDialog is safe.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/domain/models/student.dart';

enum DuplicateChoice { useExisting, createNew }

/// UX 2e duplicate guard: "এই নম্বরে আগে থেকে '{name}' আছে। তাকেই এই ব্যাচে
/// যোগ করবেন?" Returns null when dismissed. [hasBatch] false (no batch chosen)
/// turns the primary button into "open that student".
Future<DuplicateChoice?> showDuplicateDialog(
  BuildContext context, {
  required Student existing,
  required bool hasBatch,
}) {
  return showDialog<DuplicateChoice>(
    context: context,
    builder: (BuildContext ctx) {
      final l10n = ctx.l10n;
      return AlertDialog(
        title: Text(l10n.stuDuplicateTitle),
        content: Text(l10n.stuDuplicateBody(existing.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(DuplicateChoice.createNew),
            child: Text(l10n.stuDuplicateNew),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(DuplicateChoice.useExisting),
            child: Text(
                hasBatch ? l10n.stuDuplicateUse : l10n.stuDuplicateOpen),
          ),
        ],
      );
    },
  );
}

/// "মাঝের {n} মাস মাফ করবেন?" Returns true to waive, false to keep the months
/// owed, null when cancelled.
Future<bool?> showRejoinGapDialog(BuildContext context, {required int months}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      final l10n = ctx.l10n;
      return AlertDialog(
        title: Text(l10n.stuRejoinTitle),
        content: Text(l10n.stuRejoinGapBody(ctx.fmt.number(months))),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.stuRejoinKeepDues),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.stuRejoinWaive),
          ),
        ],
      );
    },
  );
}
