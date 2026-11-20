import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Moving backup bytes in and out of the app (Arch 3.4). Web-safe: no
/// `dart:io`; on web [save] is a browser download.
abstract interface class BackupFiles {
  /// Lets the user save [bytes] (save dialog / Android SAF / web download).
  /// Returns false when the user cancelled.
  Future<bool> save(Uint8List bytes, {required String fileName});

  /// Opens the OS share sheet with the file (WhatsApp, Drive app, ...).
  Future<void> share(Uint8List bytes, {required String fileName});

  /// Lets the user pick a backup file; null when cancelled. The format is
  /// detected by content, so any file type can be picked.
  Future<Uint8List?> pick();
}

/// `coaching-backup-YYYY-MM-DD-HHmm.ambackup` in center wall-clock time
/// (plan section 1 #16), e.g. `coaching-backup-2026-11-20-2130.ambackup`.
String backupFileName(int createdAtMs, CenterTime c) {
  const msPerDay = 86400000;
  final date = c.dateOfEpochMs(createdAtMs);
  final localMs = createdAtMs + c.offsetMin * 60000;
  final minuteOfDay = (localMs % msPerDay) ~/ 60000;
  String two(int v) => v.toString().padLeft(2, '0');
  final hhmm = '${two(minuteOfDay ~/ 60)}${two(minuteOfDay % 60)}';
  return 'coaching-backup-${date.toIso()}-$hhmm.ambackup';
}

/// [BackupFiles] over `file_picker` (save / pick) and `share_plus` (share).
class PluginBackupFiles implements BackupFiles {
  const PluginBackupFiles();

  static const mimeType = 'application/octet-stream';

  @override
  Future<bool> save(Uint8List bytes, {required String fileName}) async {
    final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);
    // The web download path always returns null (no completion signal).
    return uri != null || kIsWeb;
  }

  @override
  Future<void> share(Uint8List bytes, {required String fileName}) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
      fileNameOverrides: [fileName],
    ));
  }

  @override
  Future<Uint8List?> pick() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    return file.readAsBytes();
  }
}
