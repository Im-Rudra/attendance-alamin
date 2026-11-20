// Public surface of the extras feature (plan section 1 #32). STUB by M5-A;
// bodies by M9-B. Signatures are frozen.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/core/time/year_month.dart';

/// Other-income sheet (F22); true when saved.
Future<bool> showOtherIncomeSheet(BuildContext context, {String? studentId}) async => false;

/// CSV export of one month (F23).
Future<void> runCsvExport(BuildContext context, {required YearMonth month}) async {}
