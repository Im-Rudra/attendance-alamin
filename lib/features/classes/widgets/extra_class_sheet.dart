// Adds a one-off extra class (UX 2g): batch, date, time, duration, live clash
// check with suggestions; allowed even when the batch already has a class that
// day (only the no-overlap rule applies).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/features/classes/widgets/one_off_form.dart';
import 'package:attendance_alamin/features/classes/widgets/sheet_frame.dart';

/// Opens the extra-class sheet; returns the new occurrence id, or null.
Future<String?> showExtraClassSheet(
  BuildContext context, {
  String? batchId,
  LocalDate? date,
  int? startMin,
}) {
  return showClassSheet<String>(
    context,
    (BuildContext ctx) => ExtraClassSheet(batchId: batchId, date: date, startMin: startMin),
    expand: true,
    width: 520,
  );
}

/// The extra-class sheet body (public so the screen matrix can render it).
class ExtraClassSheet extends StatelessWidget {
  const ExtraClassSheet({super.key, this.batchId, this.date, this.startMin});

  final String? batchId;
  final LocalDate? date;
  final int? startMin;

  @override
  Widget build(BuildContext context) =>
      OneOffForm(mode: OneOffMode.extra, batchId: batchId, date: date, startMin: startMin);
}
