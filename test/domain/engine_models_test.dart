import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DueLevel', () {
    test('declaration order maps 1:1 onto Product 3.5 levels 0..6', () {
      expect(DueLevel.values, [
        DueLevel.upcoming,
        DueLevel.justDue,
        DueLevel.remind,
        DueLevel.followUp,
        DueLevel.urgent,
        DueLevel.finalDays,
        DueLevel.overdue,
      ]);
      for (final l in DueLevel.values) {
        expect(l.index, l.rank);
      }
    });

    final cases = <int, DueLevel>{
      -5: DueLevel.upcoming,
      0: DueLevel.upcoming,
      1: DueLevel.justDue,
      2: DueLevel.justDue,
      3: DueLevel.remind,
      4: DueLevel.remind,
      5: DueLevel.followUp,
      6: DueLevel.followUp,
      7: DueLevel.urgent,
      8: DueLevel.urgent,
      9: DueLevel.finalDays,
      10: DueLevel.finalDays,
      11: DueLevel.overdue,
      12: DueLevel.overdue,
      400: DueLevel.overdue,
    };
    cases.forEach((day, level) {
      test('forDay($day) = ${level.name}', () {
        expect(DueLevel.forDay(day), level);
      });
    });
  });

  group('MonthDue.isOpen', () {
    MonthDue mk(MonthState s) => MonthDue(
          month: const YearMonth(2026, 11),
          fee: 1000,
          feeMissing: false,
          paid: 0,
          remaining: 1000,
          state: s,
          dueDate: const LocalDate(2026, 11, 1),
          isDue: true,
        );
    for (final s in MonthState.values) {
      final open = s == MonthState.partial || s == MonthState.unpaid;
      test('${s.name} open=$open', () => expect(mk(s).isOpen, open));
    }
  });

  group('dues value types', () {
    test('EnrollmentTerms const with defaults and equality', () {
      const a = EnrollmentTerms(
        enrollmentId: 'e',
        studentId: 's',
        batchId: 'b',
        studentName: 'S',
        batchName: 'B',
        subjectName: 'Sub',
        billing: BillingType.prepaid,
        start: YearMonth(2026, 9),
        batchFees: [FeePeriod(effective: YearMonth(2026, 9), amount: 1000)],
      );
      const b = EnrollmentTerms(
        enrollmentId: 'e',
        studentId: 's',
        batchId: 'b',
        studentName: 'S',
        batchName: 'B',
        subjectName: 'Sub',
        billing: BillingType.prepaid,
        start: YearMonth(2026, 9),
        batchFees: [FeePeriod(effective: YearMonth(2026, 9), amount: 1000)],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.overrides, isEmpty);
      expect(a.studentLeft, isFalse);
    });

    test('FeePeriod null amount = cleared override', () {
      const p = FeePeriod(effective: YearMonth(2026, 9));
      expect(p.amount, isNull);
      expect(p == const FeePeriod(effective: YearMonth(2026, 9), amount: 0), isFalse);
    });

    test('PaymentFact equality', () {
      const a = PaymentFact(enrollmentId: 'e', month: YearMonth(2026, 9), amount: 5);
      expect(a, const PaymentFact(enrollmentId: 'e', month: YearMonth(2026, 9), amount: 5));
      expect(a.waived, isFalse);
    });

    test('DuesReport equality compares maps and lists', () {
      DuesReport mk(int n) => DuesReport(
            active: const [],
            inactive: const [],
            countByLevel: {DueLevel.overdue: n},
            totalOutstandingActive: 0,
            totalOutstandingInactive: 0,
            studentsWithDues: 0,
            overdueStudents: n,
          );
      expect(mk(1), mk(1));
      expect(mk(1).hashCode, mk(1).hashCode);
      expect(mk(1) == mk(2), isFalse);
    });
  });

  group('FreeSuggestion.primaryStartMin', () {
    test('none', () {
      expect(const FreeSuggestion(durationMin: 60).primaryStartMin, isNull);
    });
    test('only one side', () {
      expect(const FreeSuggestion(durationMin: 60, earlierStartMin: 500).primaryStartMin, 500);
      expect(const FreeSuggestion(durationMin: 60, laterStartMin: 700).primaryStartMin, 700);
    });
    test('smaller shift wins', () {
      expect(
        const FreeSuggestion(
          durationMin: 60,
          earlierStartMin: 590,
          laterStartMin: 700,
          preferredStartMin: 600,
        ).primaryStartMin,
        590,
      );
      expect(
        const FreeSuggestion(
          durationMin: 60,
          earlierStartMin: 500,
          laterStartMin: 610,
          preferredStartMin: 600,
        ).primaryStartMin,
        610,
      );
    });
    test('tie goes later; unknown preferred goes later', () {
      expect(
        const FreeSuggestion(
          durationMin: 60,
          earlierStartMin: 590,
          laterStartMin: 610,
          preferredStartMin: 600,
        ).primaryStartMin,
        610,
      );
      expect(
        const FreeSuggestion(durationMin: 60, earlierStartMin: 1, laterStartMin: 2)
            .primaryStartMin,
        2,
      );
    });
  });

  group('SlotCheckResult / ScheduleClashException', () {
    test('ok when no groups', () {
      expect(const SlotCheckResult().ok, isTrue);
      expect(
        const SlotCheckResult(groups: [
          ClashGroup(
            batchId: 'b',
            startMin: 600,
            endMin: 660,
            everyWeek: true,
            weekday: 7,
            existingKind: OccurrenceKind.regular,
            count: 3,
          ),
        ]).ok,
        isFalse,
      );
    });
    test('exception carries code and result', () {
      const r = SlotCheckResult();
      const e = ScheduleClashException(r);
      expect(e, isA<AppException>());
      expect(e.code, ErrorCodes.scheduleClash);
      expect(e.result, r);
    });
  });

  group('schedule value types', () {
    test('Occurrence equality', () {
      Occurrence mk(int s) => Occurrence(
            occ: 's.a.20261121',
            batchId: 'b',
            date: const LocalDate(2026, 11, 21),
            startMin: s,
            endMin: s + 60,
            kind: OccurrenceKind.regular,
            slotId: 'a',
          );
      expect(mk(600), mk(600));
      expect(mk(600).hashCode, mk(600).hashCode);
      expect(mk(600) == mk(601), isFalse);
      expect(Clash(candidate: mk(600), existing: mk(630)), Clash(candidate: mk(600), existing: mk(630)));
    });
    test('ExpandResult defaults empty', () {
      const r = ExpandResult();
      expect(r.occurrences, isEmpty);
      expect(r, const ExpandResult());
    });
  });

  group('ReminderPermission', () {
    test('values', () {
      expect(ReminderPermission.values.length, 4);
    });
  });

  group('synced tables', () {
    test('contract values', () {
      expect(kCurrentSchemaVersion, 2);
      expect(kSyncedTables.length, 15);
      expect(kSyncedTables.toSet().length, 15);
      expect(kSyncedTables, containsAll(['enrollment_fees', 'other_income', 'settings', 'places']));
      // Parents first: places before the batches that point at them.
      expect(kSyncedTables.indexOf('places'), lessThan(kSyncedTables.indexOf('batches')));
      expect(kBlobColumns['student_photos'], {'jpeg'});
      expect(kSyncColumns, {'id', 'created_at', 'updated_at', 'deleted_at', 'device_id', 'rev'});
    });
  });

  group('ChangeSummary', () {
    test('empty', () {
      const s = ChangeSummary();
      expect(s.isEmpty, isTrue);
      expect(s.totalChanges, 0);
    });
    test('totalChanges excludes keptLocal', () {
      const s = ChangeSummary(entities: {
        SummaryEntity.students: EntityChange(added: 3, updated: 2, keptLocal: 5),
        SummaryEntity.payments: EntityChange(deleted: 1),
      });
      expect(s.totalChanges, 6);
      expect(s.isEmpty, isFalse);
    });
    test('only keptLocal is still empty', () {
      const s = ChangeSummary(entities: {
        SummaryEntity.settings: EntityChange(keptLocal: 4),
      });
      expect(s.isEmpty, isTrue);
    });
    test('RowChange equality', () {
      const a = RowChange(table: 't', id: 'i', kind: ChangeKind.add, incoming: {'a': 1});
      const b = RowChange(table: 't', id: 'i', kind: ChangeKind.add, incoming: {'a': 1});
      expect(a, b);
      expect(a == const RowChange(table: 't', id: 'i', kind: ChangeKind.update, incoming: {'a': 1}), isFalse);
    });
    test('Snapshot equality', () {
      Snapshot mk(int n) => Snapshot(
            formatVersion: 1,
            schemaVersion: 1,
            appVersion: '1.0.0',
            snapshotId: 'x',
            deviceId: 'd',
            deviceName: 'n',
            createdAtMs: 1,
            counts: {'students': n},
            sha256: 'h',
            tables: {
              'students': [
                {'id': 'a', 'n': n},
              ],
            },
          );
      expect(mk(1), mk(1));
      expect(mk(1) == mk(2), isFalse);
    });
  });
}
