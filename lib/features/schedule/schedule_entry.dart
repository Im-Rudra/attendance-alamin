// Public surface of the schedule feature (plan section 1 #32). Signatures are
// the frozen M5-A ones; the bodies live in widgets/ (M6-A).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/features/schedule/widgets/reminder_lead_sheet.dart';
import 'package:attendance_alamin/features/schedule/widgets/time_picker_sheet.dart';

export 'package:attendance_alamin/features/schedule/controllers/time_input_parser.dart'
    show parseTimeInput;
export 'package:attendance_alamin/features/schedule/widgets/batch_schedule_tab.dart'
    show BatchScheduleTab;
export 'package:attendance_alamin/features/schedule/widgets/reminder_lead_sheet.dart'
    show kReminderLeadUseDefault, storedLeadOf;
export 'package:attendance_alamin/features/schedule/widgets/slot_editor_field.dart'
    show SlotEditorField;

/// Period-first time picker; returns minutes of day, or null when dismissed.
Future<int?> showTimePickerSheet(BuildContext context,
        {required int initialMin, String? title}) =>
    openTimePicker(context, initialMin: initialMin, title: title);

/// Reminder lead sheet; returns null (dismissed), [kReminderLeadUseDefault]
/// (-1: "use the default", the batch stores null), 0 (off) or 1..180 minutes.
/// [storedLeadOf] maps a result to the value to store.
Future<int?> showReminderLeadSheet(BuildContext context,
        {required int? current, required int defaultLead}) =>
    openReminderLeadSheet(context, current: current, defaultLead: defaultLead);
