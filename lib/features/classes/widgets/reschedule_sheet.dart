// Moves one class to another date / time ("শুধু এই তারিখ"; weekly changes live
// in the batch schedule).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/features/classes/widgets/one_off_form.dart';
import 'package:attendance_alamin/features/classes/widgets/sheet_frame.dart';

/// Opens the reschedule sheet of [occ]; true when the move was saved.
Future<bool> showRescheduleSheet(BuildContext context, {required String occ}) async {
  final bool? saved = await showClassSheet<bool>(
    context,
    (BuildContext ctx) => RescheduleSheet(occ: occ),
  );
  return saved ?? false;
}

/// The reschedule sheet body (public so the screen matrix can render it).
class RescheduleSheet extends StatelessWidget {
  const RescheduleSheet({super.key, required this.occ});

  final String occ;

  @override
  Widget build(BuildContext context) => OneOffForm(mode: OneOffMode.reschedule, occ: occ);
}
