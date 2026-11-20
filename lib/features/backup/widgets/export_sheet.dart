// Export sheet (UX 2f): opens the moment the teacher taps "ব্যাকআপ নিন", builds
// the backup file, names it, says "keep this file private" and offers Save and
// Share. `lastExportAt` is recorded only after the file was really saved or
// handed to the share sheet (a cancelled save is not a backup).

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
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
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
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
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
      return;
    }
    try {
      await ref.read(settingsRepositoryProvider).set(SettingKeys.lastExportAt, snapshot.createdAtMs);
    } on Object {
      // The file is safe; only the "last backup" note could not be updated.
    }
    if (mounted) navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(share ? l10n.backupExportShared : l10n.backupExportSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool busy = _phase == _ExportPhase.busy;

    final Widget content;
    switch (_phase) {
      case _ExportPhase.preparing:
        content = Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.backupExportPreparing, style: tt.bodyLarge),
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
              style: tt.bodyLarge?.copyWith(color: tokens.error),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('backup-export-retry'),
              onPressed: _prepare,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              child: Text(l10n.commonRetry),
            ),
          ],
        );
      case _ExportPhase.ready:
      case _ExportPhase.busy:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.surfaceDense,
                borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
                border: Border.all(color: tokens.hairline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.insert_drive_file_outlined, color: tokens.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: l10n.backupExportSemantics(_fileName),
                        excludeSemantics: true,
                        child: Text(
                          _fileName,
                          key: const Key('backup-export-filename'),
                          style: tt.bodyLarge?.copyWith(color: tokens.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.infoContainer,
                borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.lock_outline, color: tokens.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.backupExportPrivacy,
                        key: const Key('backup-export-privacy'),
                        style: tt.bodyMedium?.copyWith(color: tokens.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('backup-export-save'),
              onPressed: busy ? null : () => _deliver(share: false),
              icon: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_alt_outlined),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              label: Text(l10n.backupExportSave),
            ),
            if (!kIsWeb) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('backup-export-share'),
                onPressed: busy ? null : () => _deliver(share: true),
                icon: const Icon(Icons.ios_share),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                label: Text(l10n.backupExportShare),
              ),
            ],
          ],
        );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                _phase == _ExportPhase.preparing || _phase == _ExportPhase.failed
                    ? l10n.backupExportTitle
                    : l10n.backupExportReadyTitle,
                style: tt.titleLarge?.copyWith(color: tokens.textPrimary),
              ),
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }
}
