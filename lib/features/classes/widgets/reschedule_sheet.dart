// Moves one class to another date / time ("শুধু এই তারিখ"; weekly changes live
// in the batch schedule).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/features/classes/widgets/one_off_form.dart';
import 'package:attendance_alamin/features/classes/widgets/sheet_frame.dart';

/// Opens the reschedule sheet of [occ]; true when the move was saved.
Future<bool> showRescheduleSheet(BuildContext context, {required String occ}) async {
  // A form: the desktop side panel (a sheet on phones); closing after edits asks first.
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final ValueNotifier<OneOffFooterState?> footer = ValueNotifier<OneOffFooterState?>(null);
  final bool? saved = await showClassSheet<bool>(
    context,
    (BuildContext ctx) => RescheduleSheet(occ: occ, dirty: dirty, footerState: footer),
    kind: BhorPanelKind.form,
    title: context.l10n.clsRescheduleTitle,
    dirty: dirty,
    footer: (BuildContext ctx) => oneOffFooter(footer),
    expand: true,
    width: 480,
  );
  return saved ?? false;
}

/// The reschedule sheet body (public so the screen matrix can render it).
class RescheduleSheet extends StatelessWidget {
  const RescheduleSheet({super.key, required this.occ, this.dirty, this.footerState});

  final String occ;
  final ValueNotifier<bool>? dirty;
  final ValueNotifier<OneOffFooterState?>? footerState;

  @override
  Widget build(BuildContext context) =>
      OneOffForm(mode: OneOffMode.reschedule, occ: occ, dirty: dirty, footerState: footerState);
}
