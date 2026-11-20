// Student photo, or the initials avatar when there is none.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';

class StudentAvatar extends ConsumerWidget {
  const StudentAvatar({super.key, required this.student, this.size = 40});

  final Student student;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget initials = InitialsAvatar(name: student.name, size: size);
    if (!student.hasPhoto) return initials;
    final Uint8List? bytes =
        ref.watch(stuPhotoProvider((id: student.id, has: true))).value;
    if (bytes == null || bytes.isEmpty) return initials;
    return ExcludeSemantics(
      child: ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (BuildContext c, Object e, StackTrace? s) => initials,
        ),
      ),
    );
  }
}
