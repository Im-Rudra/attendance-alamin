// Public surface of the extras feature (plan section 1 #32). Signatures are
// frozen; bodies by M9-B. BulkAddScreen and HolidayScreen are routed
// (`/batches/:id/bulk-add`, `/more/holidays`).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/features/extras/widgets/csv_export_sheet.dart';
import 'package:attendance_alamin/features/extras/widgets/other_income_sheet.dart';

/// Other-income sheet (F22); true when saved.
Future<bool> showOtherIncomeSheet(BuildContext context, {String? studentId}) =>
    openOtherIncomeSheet(context, studentId: studentId);

/// CSV export of one month (F23).
Future<void> runCsvExport(BuildContext context, {required YearMonth month}) =>
    openCsvExportSheet(context, month: month);
