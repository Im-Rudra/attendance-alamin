// Public surface of the backup feature (plan section 1 #32). Signatures frozen
// by M5-A; bodies by M9-A.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_state.dart';
import 'package:attendance_alamin/features/backup/widgets/export_sheet.dart';

export 'package:attendance_alamin/features/backup/widgets/backup_section.dart'
    show BackupSection, showSafetyCopiesPanel;

/// One-tap export: build the snapshot, save or share the file.
Future<void> runExportBackup(BuildContext context) => showExportSheet(context);

/// Pick a backup file and open the review screen.
///
/// Nothing happens when the picker is cancelled. A bad file still opens the
/// review screen, which explains the problem and offers another file.
Future<void> runImportBackup(BuildContext context) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final ImportController controller = container.read(importControllerProvider.notifier);
  final bool picked = await controller.pickAndPreview();
  if (!picked || !context.mounted) return;
  try {
    await context.push<void>(Routes.moreBackupReview);
  } finally {
    // The big snapshot must not outlive the review.
    try {
      controller.reset();
    } on Object {
      // The app is shutting down; nothing to clean up.
    }
  }
}
