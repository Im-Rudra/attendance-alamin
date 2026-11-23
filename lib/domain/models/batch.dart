import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/domain/models/subject.dart';

class Batch {
  const Batch({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.billingType,
    required this.createdOn,
    required this.sortOrder,
    this.reminderLeadMin,
    this.archivedOn,
    this.notes,
    this.kind = BatchKind.batch,
    this.placeId = kDefaultPlaceId,
  });

  final String id;

  /// [kNoSubjectId] for a private tuition without a subject ([hasSubject]).
  final String subjectId;
  final String name;
  final BillingType billingType;

  /// `null` = use the default lead, `0` = reminders off.
  final int? reminderLeadMin;
  final LocalDate? archivedOn;
  final LocalDate createdOn;
  final int sortOrder;
  final String? notes;

  /// Batch or private tuition (schema v2).
  final BatchKind kind;

  /// The place it is taught at (schema v2; [kDefaultPlaceId] after migration).
  final String placeId;

  bool get archived => archivedOn != null;
  bool get isTuition => kind == BatchKind.tuition;
  bool get hasSubject => subjectId != kNoSubjectId;

  @override
  bool operator ==(Object other) =>
      other is Batch &&
      other.id == id &&
      other.subjectId == subjectId &&
      other.name == name &&
      other.billingType == billingType &&
      other.reminderLeadMin == reminderLeadMin &&
      other.archivedOn == archivedOn &&
      other.createdOn == createdOn &&
      other.sortOrder == sortOrder &&
      other.notes == notes &&
      other.kind == kind &&
      other.placeId == placeId;

  @override
  int get hashCode => Object.hash(id, subjectId, name, billingType,
      reminderLeadMin, archivedOn, createdOn, sortOrder, notes, kind, placeId);

  @override
  String toString() => 'Batch($id, $name)';
}
