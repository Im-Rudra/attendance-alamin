// Small read providers of the extras feature.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';

/// One batch by id (null when it does not exist).
final extraBatchProvider = StreamProvider.autoDispose.family<Batch?, String>(
    (Ref ref, String id) => ref.watch(batchesRepositoryProvider).watchById(id));
