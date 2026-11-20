// Public surface of the dues feature (plan section 1 #32). Signatures are
// frozen by M5-A; the bodies live in controllers/ and widgets/.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/features/dues/controllers/reminder_actions.dart';
import 'package:attendance_alamin/features/dues/widgets/batch_fees_tab.dart';

/// Builds the dues reminder from the template and shares it (and remembers the
/// reminder for today). Says so when the student has nothing due.
Future<void> shareDuesReminder(BuildContext context, {required String studentId}) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  await remindStudent(context, container, studentId);
}

/// Batch detail › বেতন tab.
class BatchFeesTab extends StatelessWidget {
  const BatchFeesTab({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) => BatchFeesPanel(batchId: batchId);
}
