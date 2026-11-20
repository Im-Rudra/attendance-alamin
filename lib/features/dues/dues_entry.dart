// Public surface of the dues feature (plan section 1 #32). STUB by M5-A;
// bodies by M7-C. Signatures are frozen.

import 'package:flutter/widgets.dart';

/// Builds the dues reminder from the template and shares it.
Future<void> shareDuesReminder(BuildContext context, {required String studentId}) async {}

/// Batch detail › বেতন tab.
class BatchFeesTab extends StatelessWidget {
  const BatchFeesTab({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
