// Backup on its own page: phones only (More > Backup). On desktop Backup is a
// section of the settings column (review M3), which shows the very same
// BackupSection: a primary "create backup" card, then restore, safety copies,
// CSV export, the backup reminder and the device name.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/features/backup/widgets/backup_section.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final bool embedded = PaneScope.isEmbedded(context);
    return BhorScaffold(
      header: BhorHeader(
        title: l10n.shellTitleBackup,
        large: true,
        showBack: embedded ? false : null,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(g, BhorSpace.s8, g, g),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const BackupSection(),
          ),
        ),
      ),
    );
  }
}
