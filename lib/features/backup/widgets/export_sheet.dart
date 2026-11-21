// Export sheet (UX 2f): opens the moment the teacher taps "ব্যাকআপ নিন", builds
// the backup file, names it, says "keep this file private" and offers Save and
// Share. `lastExportAt` is recorded only after the file was really saved or
// handed to the share sheet (a cancelled save is not a backup).

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/backup/backup_files.dart';
import 'package:attendance_alamin/data/backup/backup_providers.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/sync/snapshot_codec.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/features/backup/controllers/backup_state.dart';

/// Shows the export sheet; completes when it closes.
Future<void> showExportSheet(BuildContext context) {
  return showBhorSheet<void>(
    context,
    title: context.l10n.backupExportTitle,
    builder: (BuildContext _) => const ExportSheet(),
  );
}

enum _ExportPhase { preparing, ready, busy, failed }

class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key});

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  _ExportPhase _phase = _ExportPhase.preparing;
  Snapshot? _snapshot;
  Uint8List? _bytes;
  String _fileName = '';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _phase = _ExportPhase.preparing;
      _error = null;
    });
    try {
      final String version = await ref.read(backupAppVersionProvider.future);
      final Snapshot snapshot = await ref.read(backupRepositoryProvider).buildSnapshot(appVersion: version);
      final Uint8List bytes = Uint8List.fromList(SnapshotCodec.encode(snapshot));
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _bytes = bytes;
        _fileName = backupFileName(snapshot.createdAtMs, ref.read(centerTimeProvider));
        _phase = _ExportPhase.ready;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _phase = _ExportPhase.failed;
      });
    }
  }

  /// Saves (or shares) the file; closes the sheet with a snackbar on success.
  Future<void> _deliver({required bool share}) async {
    final Uint8List? bytes = _bytes;
    final Snapshot? snapshot = _snapshot;
    if (bytes == null || snapshot == null) return;
    final l10n = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final BackupFiles files = ref.read(backupFilesProvider);
    setState(() => _phase = _ExportPhase.busy);
    try {
      if (share) {
        await files.share(bytes, fileName: _fileName);
      } else {
        final bool saved = await files.save(bytes, fileName: _fileName);
        if (!saved) {
          // Cancelled in the save dialog: not a backup, stay on the sheet.
          if (mounted) setState(() => _phase = _ExportPhase.ready);
          return;
        }
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _phase = _ExportPhase.ready);
      BhorToast.show(context, message: errorText(l10n, e), tone: BhorTone.danger);
      return;
    }
    try {
      await ref.read(settingsRepositoryProvider).set(SettingKeys.lastExportAt, snapshot.createdAtMs);
    } on Object {
      // The file is safe; only the "last backup" note could not be updated.
    }
    if (!mounted) return;
    // The toast lives on the root overlay: show it, then close the sheet.
    BhorToast.show(
      context,
      message: share ? l10n.backupExportShared : l10n.backupExportSaved,
      tone: BhorTone.ok,
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final bool busy = _phase == _ExportPhase.busy;

    final Widget content;
    switch (_phase) {
      case _ExportPhase.preparing:
        content = Padding(
          padding: const EdgeInsets.symmetric(vertical: BhorSpace.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const BhorSpinner(size: 32),
              const SizedBox(height: BhorSpace.s16),
              Text(l10n.backupExportPreparing, style: b.type.body),
            ],
          ),
        );
      case _ExportPhase.failed:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              errorText(l10n, _error ?? Object()),
              style: b.type.body.copyWith(color: b.colors.danger),
            ),
            const SizedBox(height: BhorSpace.s16),
            BhorButton(
              key: const Key('backup-export-retry'),
              label: l10n.commonRetry,
              expand: true,
              onPressed: _prepare,
            ),
          ],
        );
      case _ExportPhase.ready:
      case _ExportPhase.busy:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(l10n.backupExportReadyTitle, style: b.type.heading),
            ),
            const SizedBox(height: BhorSpace.s12),
            BhorCard(
              padding: const EdgeInsets.all(BhorSpace.s12),
              child: Row(
                children: <Widget>[
                  Icon(Icons.insert_drive_file_outlined, color: b.colors.accent),
                  const SizedBox(width: BhorSpace.s12),
                  Expanded(
                    child: Semantics(
                      label: l10n.backupExportSemantics(_fileName),
                      excludeSemantics: true,
                      child: Text(
                        _fileName,
                        key: const Key('backup-export-filename'),
                        style: b.type.body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BhorSpace.s12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: b.colors.accentTint,
                borderRadius: BorderRadius.circular(BhorRadius.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(BhorSpace.s12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.lock_outline, color: b.colors.accent),
                    const SizedBox(width: BhorSpace.s12),
                    Expanded(
                      child: Text(
                        l10n.backupExportPrivacy,
                        key: const Key('backup-export-privacy'),
                        style: b.type.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: BhorSpace.s16),
            BhorButton(
              key: const Key('backup-export-save'),
              icon: Icons.save_alt_outlined,
              label: l10n.backupExportSave,
              loading: busy,
              expand: true,
              onPressed: busy ? null : () => _deliver(share: false),
            ),
            if (!kIsWeb) ...<Widget>[
              const SizedBox(height: BhorSpace.s8),
              BhorButton(
                key: const Key('backup-export-share'),
                variant: BhorButtonVariant.secondary,
                icon: Icons.ios_share,
                label: l10n.backupExportShare,
                expand: true,
                onPressed: busy ? null : () => _deliver(share: true),
              ),
            ],
          ],
        );
    }

    return SingleChildScrollView(child: content);
  }
}
