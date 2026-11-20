// Public surface of the classes feature (plan section 1 #32). STUB by M5-A;
// bodies by M6-B. Signatures are frozen.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/core/time/local_date.dart';

/// Per-date actions of one class occurrence.
Future<void> showClassActionsSheet(BuildContext context, {required String occ}) async {}

/// Adds a one-off extra class; returns its occurrence id, or null.
Future<String?> showExtraClassSheet(BuildContext context, {String? batchId, LocalDate? date, int? startMin}) async =>
    null;

/// Moves one occurrence; true when saved.
Future<bool> showRescheduleSheet(BuildContext context, {required String occ}) async => false;

/// 7-day strip with class-count dots.
class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.selected, required this.onSelected});

  final LocalDate selected;
  final ValueChanged<LocalDate> onSelected;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Desktop week grid (7 columns × hours).
class WeekGrid extends StatelessWidget {
  const WeekGrid({super.key, required this.weekStart, this.onSelectOcc});

  final LocalDate weekStart;
  final ValueChanged<String>? onSelectOcc;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
