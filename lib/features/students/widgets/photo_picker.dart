// Photo picking (UX 2e): 512 px, JPEG quality 70, at most 200 KB.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';

/// The picked photo bytes, or null when cancelled or unusable (a message is
/// shown for the latter).
Future<Uint8List?> pickStudentPhoto(BuildContext context) async {
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
      if (context.mounted) BhorToast.show(context, message: tooLarge);
      return null;
    }
    return bytes;
  } catch (_) {
    if (context.mounted) BhorToast.show(context, message: failed);
    return null;
  }
}
