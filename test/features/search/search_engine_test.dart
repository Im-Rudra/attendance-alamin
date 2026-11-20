// Pure search logic: digit normalisation both ways, partial phones, ranking,
// recent-search list maths and the 300-student performance budget.

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/search/controllers/search_engine.dart';

Student _stu(
  String id,
  String name, {
  String? roll,
  String? phone,
  String? gPhone,
  String? gName,
  StudentStatus status = StudentStatus.active,
}) =>
    Student(
      id: id,
      name: name,
      roll: roll,
      phone: phone,
      guardianPhone: gPhone,
      guardianName: gName,
      admissionDate: const LocalDate(2026, 1, 1),
      status: status,
    );

const Batch _physics = Batch(
  id: 'b1',
  subjectId: 'sub1',
  name: 'পদার্থ ব্যাচ ১০',
  billingType: BillingType.prepaid,
  createdOn: LocalDate(2026, 1, 1),
  sortOrder: 0,
);

SearchIndex _index(List<Student> students) => buildSearchIndex(
      students: students,
      batches: const <Batch>[_physics],
      subjects: const <Subject>[Subject(id: 'sub1', name: 'Physics', sortOrder: 0)],
      batchesOfStudent: <String, List<String>>{
        for (final Student s in students) s.id: <String>['b1'],
      },
      countOfBatch: <String, int>{'b1': students.length},
    );

List<String> _ids(SearchResults r) =>
    <String>[for (final StudentEntry e in r.students) e.id];

void main() {
  final SearchIndex idx = _index(<Student>[
    _stu('rahim', 'রহিম উদ্দিন', roll: '1', phone: '01711223344', gPhone: '01811223344'),
    _stu('karim', 'করিম হোসেন', roll: '২', phone: '01922334455'),
    _stu('sara', 'Sara Akter',
        roll: '10', gPhone: '+880 1733-445566', gName: 'Rahima Begum'),
    _stu('old', 'রহিমা (left)', roll: '3', status: StudentStatus.left),
  ]);

  group('digit normalisation (both ways)', () {
    const List<(String, String)> table = <(String, String)>[
      ('০১৭১', 'rahim'), // Bangla query, ASCII phone
      ('0171', 'rahim'), // ASCII query, ASCII phone
      ('০১৭১১২২', 'rahim'),
      ('01733', 'sara'), // phone stored with +880, space and dash
      ('০১৭৩৩-৪৪৫', 'sara'),
      ('1733445566', 'sara'),
      ('01811', 'rahim'), // guardian phone
      ('1', 'rahim'), // ASCII query vs ASCII roll
      ('২', 'karim'), // Bangla query vs Bangla roll
      ('2', 'karim'), // ASCII query vs Bangla roll
      ('১০', 'sara'), // Bangla query vs ASCII roll
    ];
    for (final (String q, String id) in table) {
      test('"$q" finds $id', () {
        expect(_ids(runSearch(idx, q)), contains(id));
      });
    }

    test('Bangla digits in a batch name match an ASCII query', () {
      expect(runSearch(idx, 'ব্যাচ 10').batches.map((BatchEntry e) => e.id),
          <String>['b1']);
      expect(runSearch(idx, 'ব্যাচ ১০').batches, hasLength(1));
    });
  });

  group('matching rules', () {
    test('a short digit string is not a phone search', () {
      expect(_ids(runSearch(idx, '17')), isEmpty);
    });

    test('exact roll ranks first', () {
      expect(_ids(runSearch(idx, '1')).first, 'rahim');
    });

    test('name match is case-insensitive and every token must match', () {
      expect(_ids(runSearch(idx, 'sara AKTER')), <String>['sara']);
      expect(_ids(runSearch(idx, 'sara karim')), isEmpty);
    });

    test('guardian name finds the student', () {
      expect(_ids(runSearch(idx, 'begum')), <String>['sara']);
    });

    test('students who left come after active ones', () {
      expect(_ids(runSearch(idx, 'রহিম')), <String>['rahim', 'old']);
    });

    test('batch matches by name or subject', () {
      expect(runSearch(idx, 'physics').batches, hasLength(1));
      expect(runSearch(idx, 'পদার্থ').batches, hasLength(1));
      expect(runSearch(idx, 'zzz').isEmpty, isTrue);
    });

    test('empty / blank query returns nothing', () {
      expect(runSearch(idx, '').isEmpty, isTrue);
      expect(runSearch(idx, '   ').isEmpty, isTrue);
    });
  });

  group('recent searches', () {
    test('newest first, de-duplicated by normalised text, capped', () {
      var r = <String>[];
      r = pushRecent(r, 'রহিম');
      r = pushRecent(r, '০১৭১');
      r = pushRecent(r, '  0171 '); // same as ০১৭১
      expect(r, <String>['0171', 'রহিম']);
      for (var i = 0; i < 12; i++) {
        r = pushRecent(r, 'q$i');
      }
      expect(r, hasLength(8));
      expect(r.first, 'q11');
    });

    test('blank queries are ignored', () {
      expect(pushRecent(<String>['a'], '  '), <String>['a']);
    });
  });

  test('300 students: 200 searches stay far below the 1 s budget', () {
    final List<Student> many = <Student>[
      for (var i = 0; i < 300; i++)
        _stu('s$i', 'শিক্ষার্থী $i নাম',
            roll: '$i',
            phone: '017${(10000000 + i * 37).toString().padLeft(8, '0')}',
            gPhone: '018${(10000000 + i * 91).toString().padLeft(8, '0')}',
            gName: 'অভিভাবক $i'),
    ];
    final SearchIndex big = _index(many);
    final Stopwatch sw = Stopwatch()..start();
    var hits = 0;
    const List<String> queries = <String>[
      'শিক্ষার্থী',
      '০১৭১',
      '0181',
      'অভিভাবক 12',
      '299',
      'xyz',
    ];
    for (var i = 0; i < 200; i++) {
      hits += runSearch(big, queries[i % queries.length]).total;
    }
    sw.stop();
    expect(hits, greaterThan(0));
    // The product budget is 1000 ms per keystroke; require an average under
    // 50 ms, loose enough for a slow CI box but failing on any O(n^2) or I/O.
    expect(sw.elapsedMilliseconds / 200, lessThan(50));
    final Stopwatch sw2 = Stopwatch()..start();
    _index(many);
    expect(sw2.elapsedMilliseconds, lessThan(500));
  });
}
