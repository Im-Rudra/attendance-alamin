import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/other_income.dart';
import 'package:attendance_alamin/domain/models/payment.dart' as pay;
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('enum parse', () {
    test('BillingType', () {
      for (final v in BillingType.values) {
        expect(BillingType.parse(v.name), v);
      }
      expect(() => BillingType.parse('x'), throwsFormatException);
    });
    test('StudentStatus', () {
      for (final v in StudentStatus.values) {
        expect(StudentStatus.parse(v.name), v);
      }
      expect(() => StudentStatus.parse('gone'), throwsFormatException);
    });
    test('ExceptionKind', () {
      for (final v in ExceptionKind.values) {
        expect(ExceptionKind.parse(v.name), v);
      }
      expect(() => ExceptionKind.parse(''), throwsFormatException);
    });
    test('AttendanceStatus codes P A L E', () {
      expect(AttendanceStatus.parse('P'), AttendanceStatus.present);
      expect(AttendanceStatus.parse('A'), AttendanceStatus.absent);
      expect(AttendanceStatus.parse('L'), AttendanceStatus.late);
      expect(AttendanceStatus.parse('E'), AttendanceStatus.leave);
      for (final v in AttendanceStatus.values) {
        expect(AttendanceStatus.parse(v.code), v);
      }
      expect(() => AttendanceStatus.parse('X'), throwsFormatException);
      expect(() => AttendanceStatus.parse('p'), throwsFormatException);
    });
    test('AttendanceStatus declaration order is binding for the theme', () {
      expect(AttendanceStatus.values, [
        AttendanceStatus.present,
        AttendanceStatus.absent,
        AttendanceStatus.late,
        AttendanceStatus.leave,
      ]);
      expect(AttendanceStatus.present.index, 0);
      expect(AttendanceStatus.absent.index, 1);
      expect(AttendanceStatus.late.index, 2);
      expect(AttendanceStatus.leave.index, 3);
    });
    test('AttendanceStatus.attended', () {
      expect(AttendanceStatus.present.attended, isTrue);
      expect(AttendanceStatus.late.attended, isTrue);
      expect(AttendanceStatus.absent.attended, isFalse);
      expect(AttendanceStatus.leave.attended, isFalse);
    });
  });

  group('PaymentMethod', () {
    test('built-ins', () {
      expect(pay.PaymentMethod.builtIns.map((m) => m.code),
          ['cash', 'bkash', 'nagad', 'rocket', 'bank', 'other']);
      for (final m in pay.PaymentMethod.builtIns) {
        expect(m.isCustom, isFalse);
        expect(m.customLabel, isNull);
        expect(pay.PaymentMethod.parse(m.code), m);
      }
    });
    test('custom', () {
      final m = pay.PaymentMethod.custom('  Upay ');
      expect(m.code, 'custom:Upay');
      expect(m.isCustom, isTrue);
      expect(m.customLabel, 'Upay');
      expect(pay.PaymentMethod.parse('custom:Upay'), m);
      expect(m.hashCode, pay.PaymentMethod.parse('custom:Upay').hashCode);
    });
    test('custom label bounds', () {
      expect(pay.PaymentMethod.custom('a' * 20).customLabel, 'a' * 20);
      expect(
        () => pay.PaymentMethod.custom('a' * 21),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCodes.nameTooLong)),
      );
      expect(
        () => pay.PaymentMethod.custom('   '),
        throwsA(isA<ValidationException>()
            .having((e) => e.code, 'code', ErrorCodes.nameRequired)),
      );
    });
    test('parse rejects junk', () {
      expect(() => pay.PaymentMethod.parse('paypal'), throwsFormatException);
      expect(() => pay.PaymentMethod.parse('custom:'), throwsFormatException);
      expect(() => pay.PaymentMethod.parse('custom:${'a' * 21}'),
          throwsFormatException);
    });
  });

  group('Slot', () {
    Slot slot({LocalDate? from, LocalDate? to}) => Slot(
          id: 's1',
          batchId: 'b1',
          weekday: 6,
          startMin: 600,
          endMin: 660,
          validFrom: from,
          validTo: to,
        );
    test('durationMin', () => expect(slot().durationMin, 60));
    test('null bounds are always active', () {
      expect(slot().activeOn(const LocalDate(1999, 1, 1)), isTrue);
      expect(slot().activeOn(const LocalDate(2099, 12, 31)), isTrue);
    });
    test('inclusive bounds', () {
      final s = slot(
        from: const LocalDate(2026, 11, 1),
        to: const LocalDate(2026, 11, 30),
      );
      expect(s.activeOn(const LocalDate(2026, 10, 31)), isFalse);
      expect(s.activeOn(const LocalDate(2026, 11, 1)), isTrue);
      expect(s.activeOn(const LocalDate(2026, 11, 30)), isTrue);
      expect(s.activeOn(const LocalDate(2026, 12, 1)), isFalse);
    });
    test('only validFrom / only validTo', () {
      expect(slot(from: const LocalDate(2026, 11, 1)).activeOn(const LocalDate(2030, 1, 1)),
          isTrue);
      expect(slot(to: const LocalDate(2026, 11, 1)).activeOn(const LocalDate(2020, 1, 1)),
          isTrue);
      expect(slot(to: const LocalDate(2026, 11, 1)).activeOn(const LocalDate(2026, 11, 2)),
          isFalse);
    });
  });

  group('Enrollment.coversDate', () {
    Enrollment e({LocalDate? end}) => Enrollment(
          id: 'e',
          studentId: 's',
          batchId: 'b',
          joinDate: const LocalDate(2026, 9, 10),
          startMonth: const YearMonth(2026, 9),
          endDate: end,
        );
    test('before join', () => expect(e().coversDate(const LocalDate(2026, 9, 9)), isFalse));
    test('on join', () => expect(e().coversDate(const LocalDate(2026, 9, 10)), isTrue));
    test('open ended', () => expect(e().coversDate(const LocalDate(2040, 1, 1)), isTrue));
    test('on end date', () {
      expect(e(end: const LocalDate(2026, 11, 5)).coversDate(const LocalDate(2026, 11, 5)),
          isTrue);
    });
    test('after end date', () {
      expect(e(end: const LocalDate(2026, 11, 5)).coversDate(const LocalDate(2026, 11, 6)),
          isFalse);
    });
  });

  group('Student.callNumber', () {
    Student s({String? phone, String? guardian}) => Student(
          id: 'x',
          name: 'N',
          admissionDate: const LocalDate(2026, 1, 1),
          status: StudentStatus.active,
          phone: phone,
          guardianPhone: guardian,
        );
    test('guardian first', () => expect(s(phone: '017', guardian: '018').callNumber, '018'));
    test('falls back to student', () => expect(s(phone: '017').callNumber, '017'));
    test('none', () => expect(s().callNumber, isNull));
  });

  group('Batch', () {
    test('archived flag', () {
      const b = Batch(
        id: 'b',
        subjectId: 's',
        name: 'N',
        billingType: BillingType.prepaid,
        createdOn: LocalDate(2026, 1, 1),
        sortOrder: 0,
      );
      expect(b.archived, isFalse);
      const a = Batch(
        id: 'b',
        subjectId: 's',
        name: 'N',
        billingType: BillingType.prepaid,
        createdOn: LocalDate(2026, 1, 1),
        sortOrder: 0,
        archivedOn: LocalDate(2026, 6, 1),
      );
      expect(a.archived, isTrue);
      expect(a == b, isFalse);
    });
  });

  group('value equality', () {
    test('Subject', () {
      const a = Subject(id: '1', name: 'Math', sortOrder: 0);
      const b = Subject(id: '1', name: 'Math', sortOrder: 0);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const Subject(id: '1', name: 'Math', sortOrder: 0, archived: true), isFalse);
    });
    test('Payment', () {
      pay.Payment mk(int amount) => pay.Payment(
            id: 'p',
            receiptId: 'r',
            studentId: 's',
            enrollmentId: 'e',
            batchId: 'b',
            billingMonth: const YearMonth(2026, 11),
            amount: amount,
            paidOn: const LocalDate(2026, 11, 5),
            method: pay.PaymentMethod.cash,
          );
      expect(mk(500), mk(500));
      expect(mk(500).hashCode, mk(500).hashCode);
      expect(mk(500) == mk(501), isFalse);
      expect(mk(1).waived, isFalse);
    });
    test('OtherIncome', () {
      const a = OtherIncome(
        id: 'o',
        label: 'Exam',
        amount: 100,
        paidOn: LocalDate(2026, 11, 5),
        method: PaymentMethod.cash,
      );
      expect(a.studentId, isNull);
      expect(
          a,
          const OtherIncome(
            id: 'o',
            label: 'Exam',
            amount: 100,
            paidOn: LocalDate(2026, 11, 5),
            method: PaymentMethod.cash,
          ));
    });
    test('Attendance', () {
      const r = AttendanceRecord(
        id: 'r',
        sessionId: 's',
        batchId: 'b',
        studentId: 'st',
        date: LocalDate(2026, 11, 5),
        status: AttendanceStatus.leave,
      );
      expect(
          r,
          const AttendanceRecord(
            id: 'r',
            sessionId: 's',
            batchId: 'b',
            studentId: 'st',
            date: LocalDate(2026, 11, 5),
            status: AttendanceStatus.leave,
          ));
      const s1 = AttendanceSession(
        id: 'a',
        occ: 's.x.20261105',
        batchId: 'b',
        date: LocalDate(2026, 11, 5),
        startMin: 600,
        endMin: 660,
      );
      expect(s1 == s1, isTrue);
      expect(s1.slotId, isNull);
    });
    test('ScheduleException', () {
      const e = ScheduleException(id: 'e', batchId: 'b', kind: ExceptionKind.cancel);
      expect(e, const ScheduleException(id: 'e', batchId: 'b', kind: ExceptionKind.cancel));
    });
  });

  group('drafts', () {
    test('PaymentDraft.total sums allocations', () {
      const d = PaymentDraft(
        studentId: 's',
        enrollmentId: 'e',
        allocations: [
          Allocation(month: YearMonth(2026, 10), amount: 700),
          Allocation(month: YearMonth(2026, 11), amount: 300),
        ],
        paidOn: LocalDate(2026, 11, 5),
        method: PaymentMethod.bkash,
      );
      expect(d.total, 1000);
    });
    test('BatchDraft equality compares slot lists', () {
      BatchDraft mk(int start) => BatchDraft(
            subjectId: 's',
            name: 'n',
            billingType: BillingType.postpaid,
            monthlyFee: 1000,
            feeFrom: const YearMonth(2026, 11),
            slots: [SlotDraft(weekday: 6, startMin: start, endMin: start + 60)],
            slotsFrom: const LocalDate(2026, 11, 1),
          );
      expect(mk(600), mk(600));
      expect(mk(600).hashCode, mk(600).hashCode);
      expect(mk(600) == mk(660), isFalse);
    });
  });
}
