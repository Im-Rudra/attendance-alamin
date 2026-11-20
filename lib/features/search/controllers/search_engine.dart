// Pure in-memory search over students and batches (M8-B). No I/O, no Flutter:
// the index is built once per data change and every keystroke is a linear scan
// (300 students take well under a millisecond).
//
// Digits are normalised to ASCII on BOTH sides, so "০১৭১" finds "0171" and
// "0171" finds a roll or batch name typed with Bangla digits.

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';

/// Lower-cased, ASCII-digit, single-spaced form used for all comparisons.
String searchNorm(String s) => AppFormat.toAsciiDigits(s)
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Digits only (phones may be typed with spaces, dashes, +88).
String searchDigits(String s) =>
    AppFormat.toAsciiDigits(s).replaceAll(RegExp(r'[^0-9]'), '');

/// One student, pre-normalised.
class StudentEntry {
  StudentEntry({required this.student, required this.batchNames})
      : name = searchNorm(student.name),
        guardianName = searchNorm(student.guardianName ?? ''),
        roll = searchNorm(student.roll ?? ''),
        phones = <String>[
          for (final String? p in <String?>[student.phone, student.guardianPhone])
            if (p != null && searchDigits(p).isNotEmpty) searchDigits(p),
        ];

  final Student student;

  /// Display names of the batches the student is (or was) in.
  final List<String> batchNames;
  final String name;
  final String guardianName;
  final String roll;
  final List<String> phones;

  String get id => student.id;
  bool get left => student.status == StudentStatus.left;
}

/// One batch, pre-normalised.
class BatchEntry {
  BatchEntry({
    required this.batch,
    required this.subjectName,
    required this.studentCount,
  })  : name = searchNorm(batch.name),
        subject = searchNorm(subjectName);

  final Batch batch;
  final String subjectName;
  final int studentCount;
  final String name;
  final String subject;

  String get id => batch.id;
}

class SearchIndex {
  const SearchIndex({
    this.students = const <StudentEntry>[],
    this.batches = const <BatchEntry>[],
  });

  final List<StudentEntry> students;
  final List<BatchEntry> batches;

  bool get isEmpty => students.isEmpty && batches.isEmpty;
}

/// Builds the index. [batchesOfStudent] maps a student id to its batch ids
/// (open enrolments for active students, all for students who left).
SearchIndex buildSearchIndex({
  required List<Student> students,
  required List<Batch> batches,
  required List<Subject> subjects,
  required Map<String, List<String>> batchesOfStudent,
  Map<String, int> countOfBatch = const <String, int>{},
}) {
  final Map<String, Batch> byId = <String, Batch>{
    for (final Batch b in batches) b.id: b,
  };
  final Map<String, String> subjectName = <String, String>{
    for (final Subject s in subjects) s.id: s.name,
  };
  return SearchIndex(
    students: <StudentEntry>[
      for (final Student s in students)
        StudentEntry(
          student: s,
          batchNames: <String>[
            for (final String id in batchesOfStudent[s.id] ?? const <String>[])
              if (byId[id] != null) byId[id]!.name,
          ],
        ),
    ],
    batches: <BatchEntry>[
      for (final Batch b in batches)
        if (!b.archived)
          BatchEntry(
            batch: b,
            subjectName: subjectName[b.subjectId] ?? '',
            studentCount: countOfBatch[b.id] ?? 0,
          ),
    ],
  );
}

class SearchResults {
  const SearchResults({
    this.students = const <StudentEntry>[],
    this.batches = const <BatchEntry>[],
  });

  final List<StudentEntry> students;
  final List<BatchEntry> batches;

  bool get isEmpty => students.isEmpty && batches.isEmpty;
  int get total => students.length + batches.length;
}

/// Minimum digits before a phone substring counts (avoids "1" matching all).
const int kSearchMinPhoneDigits = 3;

final RegExp _phoneLike = RegExp(r'^[0-9+\-\s]+$');

/// Higher is better; 0 = no match.
int _scoreStudent(StudentEntry e, List<String> tokens, String q, String digits) {
  if (e.roll.isNotEmpty && e.roll == q) return 100;
  var best = 0;
  if (tokens.every(e.name.contains)) {
    if (e.name.startsWith(q)) {
      best = 90;
    } else if (e.name.split(' ').any((String w) => w.startsWith(tokens.first))) {
      best = 80;
    } else {
      best = 60;
    }
  } else if (e.guardianName.isNotEmpty && tokens.every(e.guardianName.contains)) {
    best = 30;
  }
  if (digits.length >= kSearchMinPhoneDigits && _phoneLike.hasMatch(q)) {
    for (final String p in e.phones) {
      if (p.endsWith(digits)) {
        if (best < 85) best = 85;
      } else if (p.contains(digits)) {
        if (best < 70) best = 70;
      }
    }
  }
  if (best == 0 && e.roll.isNotEmpty && e.roll.startsWith(q)) best = 40;
  return best;
}

int _scoreBatch(BatchEntry e, List<String> tokens, String q) {
  if (tokens.every(e.name.contains)) return e.name.startsWith(q) ? 90 : 70;
  if (tokens.every((String t) => e.name.contains(t) || e.subject.contains(t))) {
    return 50;
  }
  return 0;
}

/// Filters [index] by [rawQuery]. Active students first, then left ones;
/// within each, best score first (stable, so roll/name order is kept).
SearchResults runSearch(SearchIndex index, String rawQuery) {
  final String q = searchNorm(rawQuery);
  if (q.isEmpty) return const SearchResults();
  final List<String> tokens = q.split(' ');
  final String digits = searchDigits(q);

  final List<(StudentEntry, int)> hits = <(StudentEntry, int)>[];
  for (final StudentEntry e in index.students) {
    final int s = _scoreStudent(e, tokens, q, digits);
    if (s > 0) hits.add((e, s));
  }
  // Dart's List.sort is not stable: tie-break on the original position.
  final Map<String, int> pos = <String, int>{
    for (var i = 0; i < hits.length; i++) hits[i].$1.id: i,
  };
  hits.sort(((StudentEntry, int) a, (StudentEntry, int) b) {
    if (a.$1.left != b.$1.left) return a.$1.left ? 1 : -1;
    final int c = b.$2.compareTo(a.$2);
    return c != 0 ? c : pos[a.$1.id]!.compareTo(pos[b.$1.id]!);
  });

  final List<(BatchEntry, int)> bHits = <(BatchEntry, int)>[];
  for (final BatchEntry e in index.batches) {
    final int s = _scoreBatch(e, tokens, q);
    if (s > 0) bHits.add((e, s));
  }
  final Map<String, int> bpos = <String, int>{
    for (var i = 0; i < bHits.length; i++) bHits[i].$1.id: i,
  };
  bHits.sort(((BatchEntry, int) a, (BatchEntry, int) b) {
    final int c = b.$2.compareTo(a.$2);
    return c != 0 ? c : bpos[a.$1.id]!.compareTo(bpos[b.$1.id]!);
  });

  return SearchResults(
    students: <StudentEntry>[for (final h in hits) h.$1],
    batches: <BatchEntry>[for (final h in bHits) h.$1],
  );
}

/// Recent-search list maths: newest first, no duplicates, at most [max].
List<String> pushRecent(List<String> current, String query, {int max = 8}) {
  final String t = query.trim();
  if (t.isEmpty) return current;
  final String key = searchNorm(t);
  return <String>[
    t,
    for (final String r in current)
      if (searchNorm(r) != key) r,
  ].take(max).toList(growable: false);
}
