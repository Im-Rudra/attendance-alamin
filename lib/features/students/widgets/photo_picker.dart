// Photo picking (UX 2e): 512 px, JPEG quality 70, at most 200 KB.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';

/// The picked photo bytes, or null when cancelled or unusable (a message is
/// shown for the latter).
Future<Uint8List?> pickStudentPhoto(BuildContext context) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final String tooLarge = context.l10n.errPhotoTooLarge;
  final String failed = context.l10n.stuPhotoFailed;
  try {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (file == null) return null;
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.length > kMaxPhotoBytes) {
      messenger?.showSnackBar(SnackBar(content: Text(tooLarge)));
      return null;
    }
    return bytes;
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
    return null;
  }
}
