// Small confirmations of the students feature: duplicate guard. It goes
// through showBhorPanel (kind confirm): a dialog on desktop,
// a sheet on phones.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/domain/models/student.dart';

enum DuplicateChoice { useExisting, createNew }

Widget _message(BuildContext context, String text) =>
    Text(text, style: context.bhor.type.body.copyWith(color: context.bhor.colors.text2));

Widget _actions(List<Widget> buttons) => Wrap(
      alignment: WrapAlignment.end,
      spacing: BhorSpace.s8,
      runSpacing: BhorSpace.s8,
      children: buttons,
    );

/// UX 2e duplicate guard: "এই নম্বরে আগে থেকে '{name}' আছে। তাকেই এই ব্যাচে
/// যোগ করবেন?" Returns null when dismissed. [hasBatch] false (no batch chosen)
/// turns the primary button into "open that student".
Future<DuplicateChoice?> showDuplicateDialog(
  BuildContext context, {
  required Student existing,
  required bool hasBatch,
}) {
  final l10n = context.l10n;
  return showBhorPanel<DuplicateChoice>(
    context,
    kind: BhorPanelKind.confirm,
    title: l10n.stuDuplicateTitle,
    scroll: false,
    builder: (BuildContext ctx) => _message(ctx, l10n.stuDuplicateBody(existing.name)),
    footer: (BuildContext ctx) => _actions(<Widget>[
      BhorButton(
        label: l10n.stuDuplicateNew,
        variant: BhorButtonVariant.ghost,
        onPressed: () => Navigator.of(ctx).pop(DuplicateChoice.createNew),
      ),
      BhorButton(
        label: hasBatch ? l10n.stuDuplicateUse : l10n.stuDuplicateOpen,
        onPressed: () => Navigator.of(ctx).pop(DuplicateChoice.useExisting),
      ),
    ]),
  );
}
