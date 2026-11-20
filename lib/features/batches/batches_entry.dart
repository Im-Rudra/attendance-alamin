// Public surface of the batches feature (plan section 1 #32). STUB by M5-A;
// bodies by M6-C. Signatures are frozen.

import 'package:flutter/widgets.dart';

/// Archive dialog (asks the last billable month); true when archived.
Future<bool> showArchiveBatchDialog(BuildContext context, {required String batchId}) async => false;

/// Unarchive flow (clash check, gap-waive prompt); true when unarchived.
Future<bool> showUnarchiveBatchFlow(BuildContext context, {required String batchId}) async => false;
