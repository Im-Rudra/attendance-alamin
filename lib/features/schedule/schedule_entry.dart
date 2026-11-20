// Public surface of the schedule feature (plan section 1 #32). STUB by M5-A;
// bodies by M6-A. Signatures are frozen.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

/// Period-first time picker; returns minutes of day, or null when dismissed.
Future<int?> showTimePickerSheet(BuildContext context, {required int initialMin, String? title}) async =>
    null;

/// Reminder lead sheet; returns null (dismissed), 0 (off) or 1..180 minutes.
Future<int?> showReminderLeadSheet(BuildContext context, {required int? current, required int defaultLead}) async =>
    null;

/// Weekly slot editor used by the batch form and onboarding.
class SlotEditorField extends StatefulWidget {
  const SlotEditorField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.batchId,
    this.onCheck,
  });

  final List<SlotDraft> initial;
  final ValueChanged<List<SlotDraft>> onChanged;
  final String? batchId;
  final ValueChanged<SlotCheckResult>? onCheck;

  @override
  State<SlotEditorField> createState() => _SlotEditorFieldState();
}

class _SlotEditorFieldState extends State<SlotEditorField> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Batch detail › সময়সূচি tab.
class BatchScheduleTab extends StatelessWidget {
  const BatchScheduleTab({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
