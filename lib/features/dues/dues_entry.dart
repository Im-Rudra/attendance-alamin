// Public surface of the dues feature (plan section 1 #32). Signatures are
// frozen by M5-A; the bodies live in controllers/ and widgets/.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/features/dues/controllers/reminder_actions.dart';
import 'package:attendance_alamin/features/dues/widgets/batch_fees_tab.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';
import 'package:attendance_alamin/features/dues/widgets/take_money_picker.dart';

/// "Collect fee" in place (the flow of the Fees screen's Collect fee button):
/// the student picker, then the payment side panel. Used by Today's New… menu.
Future<void> showCollectFeeFlow(BuildContext context, {BuildContext? anchor}) =>
    showTakeMoneyPicker(context, anchor: anchor);

/// Builds the dues reminder from the template and shares it (and remembers the
/// reminder for today). Says so when the student has nothing due.
Future<void> shareDuesReminder(BuildContext context, {required String studentId}) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  await remindStudent(context, container, studentId);
}

/// "Collect fee" from anywhere (Today's New…): opens the payment panel of
/// [studentId], or the student picker (name, roll, batch, due level) when no
/// student is given. Pass the invoking control's context so the picker anchors
/// to it.
Future<void> openCollectFee(BuildContext context, {String? studentId}) =>
    studentId == null ? showTakeMoneyPicker(context) : duesCollect(context, studentId);

/// Batch detail › বেতন tab.
class BatchFeesTab extends StatelessWidget {
  const BatchFeesTab({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) => BatchFeesPanel(batchId: batchId);
}
