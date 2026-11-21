// Student photo, or the initials avatar when there is none.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';

class StudentAvatar extends ConsumerWidget {
  const StudentAvatar({super.key, required this.student, this.size = 40});

  final Student student;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!student.hasPhoto) return BhorAvatar(name: student.name, size: size);
    final Uint8List? bytes = ref.watch(stuPhotoProvider((id: student.id, has: true))).value;
    if (bytes == null || bytes.isEmpty) return BhorAvatar(name: student.name, size: size);
    return BhorAvatar(name: student.name, size: size, image: MemoryImage(bytes));
  }
}
