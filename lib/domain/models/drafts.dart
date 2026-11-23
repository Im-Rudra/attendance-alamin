import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/value_equality.dart';

class SlotDraft {
  const SlotDraft({
    required this.weekday,
    required this.startMin,
    required this.endMin,
    this.id,
  });

  /// `null` for a new slot.
  final String? id;
  final int weekday;
  final int startMin;
  final int endMin;

  @override
  bool operator ==(Object other) =>
      other is SlotDraft &&
      other.id == id &&
      other.weekday == weekday &&
      other.startMin == startMin &&
      other.endMin == endMin;

  @override
  int get hashCode => Object.hash(id, weekday, startMin, endMin);
}

class BatchDraft {
  const BatchDraft({
    required this.subjectId,
    required this.name,
    required this.billingType,
    required this.monthlyFee,
    required this.feeFrom,
    required this.slots,
    required this.slotsFrom,
    this.reminderLeadMin,
    this.notes,
    this.kind = BatchKind.batch,
    this.placeId,
  });

  /// `kNoSubjectId` (domain/models/subject.dart) = a tuition without subject.
  final String subjectId;
  final String name;
  final BillingType billingType;
  final int? reminderLeadMin;
  final int monthlyFee;
  final YearMonth feeFrom;
  final List<SlotDraft> slots;
  final LocalDate slotsFrom;
  final String? notes;

  /// Batch or private tuition (schema v2).
  final BatchKind kind;

  /// The place; null = the default place (`kDefaultPlaceId`).
  final String? placeId;

  @override
  bool operator ==(Object other) =>
      other is BatchDraft &&
      other.subjectId == subjectId &&
      other.name == name &&
      other.billingType == billingType &&
      other.reminderLeadMin == reminderLeadMin &&
      other.monthlyFee == monthlyFee &&
      other.feeFrom == feeFrom &&
      listEq(other.slots, slots) &&
      other.slotsFrom == slotsFrom &&
      other.notes == notes &&
      other.kind == kind &&
      other.placeId == placeId;

  @override
  int get hashCode => Object.hash(subjectId, name, billingType, reminderLeadMin,
      monthlyFee, feeFrom, Object.hashAll(slots), slotsFrom, notes, kind, placeId);
}

class StudentDraft {
  const StudentDraft({
    required this.name,
    required this.admissionDate,
    this.roll,
    this.phone,
    this.guardianName,
    this.guardianPhone,
    this.notes,
  });

  final String name;
  final String? roll;
  final String? phone;
  final String? guardianName;
  final String? guardianPhone;
  final LocalDate admissionDate;
  final String? notes;

  @override
  bool operator ==(Object other) =>
      other is StudentDraft &&
      other.name == name &&
      other.roll == roll &&
      other.phone == phone &&
      other.guardianName == guardianName &&
      other.guardianPhone == guardianPhone &&
      other.admissionDate == admissionDate &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
      name, roll, phone, guardianName, guardianPhone, admissionDate, notes);
}

/// Part of a payment placed on one billing month.
class Allocation {
  const Allocation({required this.month, required this.amount});

  final YearMonth month;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is Allocation && other.month == month && other.amount == amount;

  @override
  int get hashCode => Object.hash(month, amount);

  @override
  String toString() => 'Allocation($month, $amount)';
}

class PaymentDraft {
  const PaymentDraft({
    required this.studentId,
    required this.enrollmentId,
    required this.allocations,
    required this.paidOn,
    required this.method,
    this.note,
  });

  final String studentId;
  final String enrollmentId;
  final List<Allocation> allocations;
  final LocalDate paidOn;
  final PaymentMethod method;
  final String? note;

  int get total => allocations.fold(0, (s, a) => s + a.amount);

  @override
  bool operator ==(Object other) =>
      other is PaymentDraft &&
      other.studentId == studentId &&
      other.enrollmentId == enrollmentId &&
      listEq(other.allocations, allocations) &&
      other.paidOn == paidOn &&
      other.method == method &&
      other.note == note;

  @override
  int get hashCode => Object.hash(studentId, enrollmentId,
      Object.hashAll(allocations), paidOn, method, note);
}
