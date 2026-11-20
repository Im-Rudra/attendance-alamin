// Data for the search screen: one in-memory index fed by the repository
// streams (no per-keystroke DB queries), and the recent-search list stored in
// LocalMeta `search_recent`.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/search/controllers/search_engine.dart';

/// LocalMeta key of the recent searches (JSON list of strings, newest first).
const String kSearchRecentKey = 'search_recent';

/// Most recent searches kept.
const int kSearchRecentMax = 8;

final _searchStudentsProvider = StreamProvider<List<Student>>(
    (ref) => ref.watch(studentsRepositoryProvider).watchAll());

final _searchBatchesProvider = StreamProvider<List<Batch>>((ref) => ref
    .watch(batchesRepositoryProvider)
    .watchAll(includeArchived: true));

final _searchSubjectsProvider = StreamProvider<List<Subject>>(
    (ref) => ref.watch(subjectsRepositoryProvider).watchAll());

/// The live index; rebuilt only when students, batches or enrolments change.
final searchIndexProvider = Provider<AsyncValue<SearchIndex>>((ref) {
  final people = combine3(
    ref.watch(_searchStudentsProvider),
    ref.watch(allEnrollmentsProvider),
    ref.watch(_searchBatchesProvider),
    (s, e, b) => (s: s, e: e, b: b),
  );
  return combine2(
    people,
    ref.watch(_searchSubjectsProvider),
    (x, subjects) {
      final Map<String, Student> byId = <String, Student>{
        for (final Student s in x.s) s.id: s,
      };
      final Map<String, Set<String>> batchesOf = <String, Set<String>>{};
      final Map<String, int> counts = <String, int>{};
      for (final Enrollment e in x.e) {
        final Student? s = byId[e.studentId];
        if (s == null) continue;
        final bool left = s.status == StudentStatus.left;
        if (!left && e.endDate != null) continue;
        if ((batchesOf[s.id] ??= <String>{}).add(e.batchId) &&
            e.endDate == null) {
          counts[e.batchId] = (counts[e.batchId] ?? 0) + 1;
        }
      }
      return buildSearchIndex(
        students: x.s,
        batches: x.b,
        subjects: subjects,
        batchesOfStudent: <String, List<String>>{
          for (final MapEntry<String, Set<String>> m in batchesOf.entries)
            m.key: m.value.toList(growable: false),
        },
        countOfBatch: counts,
      );
    },
  );
});

List<String> decodeRecent(String? raw) {
  if (raw == null || raw.isEmpty) return const <String>[];
  try {
    final Object? v = jsonDecode(raw);
    if (v is List) {
      return <String>[
        for (final Object? s in v)
          if (s is String && s.trim().isNotEmpty) s,
      ].take(kSearchRecentMax).toList(growable: false);
    }
  } on FormatException {
    // fall through: corrupt value is treated as empty
  }
  return const <String>[];
}

/// Recent searches, newest first. Writes go straight to LocalMeta; failures
/// never reach the user (recent searches are a convenience).
class RecentSearches extends Notifier<List<String>> {
  late final LocalMetaRepository _meta = ref.read(localMetaRepositoryProvider);

  @override
  List<String> build() {
    _meta.getRaw(kSearchRecentKey).then((String? raw) {
      // Keep anything added before the first read finished.
      final List<String> stored = decodeRecent(raw);
      final List<String> merged = <String>[...state];
      for (final String s in stored) {
        if (!merged.any((String m) => searchNorm(m) == searchNorm(s))) {
          merged.add(s);
        }
      }
      state = merged.take(kSearchRecentMax).toList(growable: false);
    }, onError: (Object e) => debugPrint('recent searches read failed: $e'));
    return const <String>[];
  }

  Future<void> add(String query) async {
    state = pushRecent(state, query, max: kSearchRecentMax);
    await _save();
  }

  Future<void> clear() async {
    state = const <String>[];
    await _save();
  }

  Future<void> _save() async {
    try {
      await _meta.setRaw(
          kSearchRecentKey, state.isEmpty ? null : jsonEncode(state));
    } on Object catch (e) {
      debugPrint('recent searches write failed: $e');
    }
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);
