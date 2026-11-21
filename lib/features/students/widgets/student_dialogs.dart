// Small text dialogs of the students feature: duplicate guard, rejoin gap
// waiver, delete. Text only.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
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
  return showBhorDialog<DuplicateChoice>(
    context,
    builder: (BuildContext ctx) {
      final l10n = ctx.l10n;
      return BhorDialog(
        title: l10n.stuDuplicateTitle,
        message: l10n.stuDuplicateBody(existing.name),
        actions: <Widget>[
          BhorButton(
            label: l10n.stuDuplicateNew,
            variant: BhorButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(DuplicateChoice.createNew),
          ),
          BhorButton(
            label: hasBatch ? l10n.stuDuplicateUse : l10n.stuDuplicateOpen,
            onPressed: () => Navigator.of(ctx).pop(DuplicateChoice.useExisting),
          ),
        ],
      );
    },
  );
}

/// "মাঝের {n} মাস মাফ করবেন?" Returns true to waive, false to keep the months
/// owed, null when cancelled.
Future<bool?> showRejoinGapDialog(BuildContext context, {required int months}) {
  return showBhorDialog<bool>(
    context,
    builder: (BuildContext ctx) {
      final l10n = ctx.l10n;
      return BhorDialog(
        title: l10n.stuRejoinTitle,
        message: l10n.stuRejoinGapBody(ctx.fmt.number(months)),
        actions: <Widget>[
          BhorButton(
            label: l10n.commonCancel,
            variant: BhorButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          BhorButton(
            label: l10n.stuRejoinKeepDues,
            variant: BhorButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          BhorButton(
            label: l10n.stuRejoinWaive,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      );
    },
  );
}
