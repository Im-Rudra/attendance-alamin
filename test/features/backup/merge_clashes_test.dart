// findMergeClashes: slot clashes a backup merge would create.

import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/features/backup/controllers/merge_clashes.dart';

import 'backup_test_support.dart';

BatchSchedule _batch(String id, List<Slot> slots) => BatchSchedule(
      batch: Batch(
        id: id,
        subjectId: 's',
        name: id,
        billingType: BillingType.prepaid,
        createdOn: const LocalDate(2026, 1, 1),
        sortOrder: 0,
      ),
      subjectName: 's',
      slots: slots,
    );

Slot _slot(String id, String batch, int weekday, int start, int end, {LocalDate? from, LocalDate? to}) =>
    Slot(id: id, batchId: batch, weekday: weekday, startMin: start, endMin: end, validFrom: from, validTo: to);

RowChange _slotChange(String id, String batch, int weekday, int start, int end,
        {int? deletedAt, String? validFrom, String? validTo}) =>
    RowChange(
      table: 'batch_slots',
      id: id,
      kind: deletedAt == null ? ChangeKind.add : ChangeKind.delete,
      incoming: row(id, del: deletedAt, data: <String, Object?>{
        'batch_id': batch,
        'weekday': weekday,
        'start_min': start,
        'end_min': end,
        'valid_from': validFrom,
        'valid_to': validTo,
      }),
    );

void main() {
  final List<BatchSchedule> local = <BatchSchedule>[
    _batch('A', <Slot>[_slot('a1', 'A', 6, 960, 1020)]),
    _batch('B', <Slot>[_slot('b1', 'B', 7, 600, 660)]),
  ];

  test('an incoming slot overlapping another batch on the same weekday clashes', () {
    final List<MergeClash> c = findMergeClashes(
      winners: <RowChange>[_slotChange('b2', 'B', 6, 990, 1050)],
      local: local,
    );
    expect(c, const <MergeClash>[
      MergeClash(weekday: 6, startMin: 990, endMin: 1020, batchAId: 'A', batchBId: 'B'),
    ]);
  });

  test('touching times, other weekdays and the same batch do not clash', () {
    expect(findMergeClashes(winners: <RowChange>[_slotChange('b2', 'B', 6, 1020, 1080)], local: local), isEmpty);
    expect(findMergeClashes(winners: <RowChange>[_slotChange('b2', 'B', 1, 960, 1020)], local: local), isEmpty);
    expect(findMergeClashes(winners: <RowChange>[_slotChange('a2', 'A', 6, 990, 1050)], local: local), isEmpty);
  });

  test('clashes that already exist locally are not reported', () {
    final List<BatchSchedule> already = <BatchSchedule>[
      _batch('A', <Slot>[_slot('a1', 'A', 6, 960, 1020)]),
      _batch('B', <Slot>[_slot('b1', 'B', 6, 960, 1020)]),
    ];
    expect(findMergeClashes(winners: const <RowChange>[], local: already), isEmpty);
  });

  test('a slot the merge deletes no longer clashes; a replaced slot uses its new time', () {
    final List<BatchSchedule> clashing = <BatchSchedule>[
      _batch('A', <Slot>[_slot('a1', 'A', 6, 960, 1020)]),
      _batch('B', <Slot>[_slot('b1', 'B', 6, 990, 1050)]),
    ];
    expect(
      findMergeClashes(winners: <RowChange>[_slotChange('b1', 'B', 6, 990, 1050, deletedAt: 9)], local: clashing),
      isEmpty,
    );
    // b1 moves to Sunday: clash gone.
    expect(
      findMergeClashes(winners: <RowChange>[_slotChange('b1', 'B', 7, 990, 1050)], local: clashing),
      isEmpty,
    );
  });

  test('slots of a batch the merge deletes are ignored', () {
    final RowChange dead = RowChange(
      table: 'batches',
      id: 'B',
      kind: ChangeKind.delete,
      incoming: row('B', del: 9),
    );
    expect(
      findMergeClashes(winners: <RowChange>[dead, _slotChange('b2', 'B', 6, 990, 1050)], local: local),
      isEmpty,
    );
  });

  test('validity windows that do not meet never clash', () {
    final List<BatchSchedule> windowed = <BatchSchedule>[
      _batch('A', <Slot>[_slot('a1', 'A', 6, 960, 1020, to: const LocalDate(2026, 12, 31))]),
    ];
    expect(
      findMergeClashes(
        winners: <RowChange>[_slotChange('b2', 'B', 6, 990, 1050, validFrom: '2027-01-01')],
        local: windowed,
      ),
      isEmpty,
    );
    expect(
      findMergeClashes(
        winners: <RowChange>[_slotChange('b2', 'B', 6, 990, 1050, validFrom: '2026-12-01')],
        local: windowed,
      ),
      hasLength(1),
    );
  });

  test('results are sorted by weekday then time', () {
    final List<MergeClash> c = findMergeClashes(
      winners: <RowChange>[
        _slotChange('b2', 'B', 7, 630, 700),
        _slotChange('b3', 'B', 6, 990, 1050),
      ],
      local: <BatchSchedule>[
        _batch('A', <Slot>[_slot('a1', 'A', 6, 960, 1020), _slot('a2', 'A', 7, 600, 660)]),
      ],
    );
    expect(c.map((MergeClash e) => e.weekday), <int>[6, 7]);
  });
}
