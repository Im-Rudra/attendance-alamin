import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.admissionDate,
    required this.status,
    this.roll,
    this.phone,
    this.guardianName,
    this.guardianPhone,
    this.leftDate,
    this.notes,
    this.hasPhoto = false,
  });

  final String id;
  final String name;
  final String? roll;
  final String? phone;
  final String? guardianName;
  final String? guardianPhone;
  final LocalDate admissionDate;
  final StudentStatus status;
  final LocalDate? leftDate;
  final String? notes;
  final bool hasPhoto;

  /// Who to call: the guardian when known, else the student.
  String? get callNumber => guardianPhone ?? phone;

  @override
  bool operator ==(Object other) =>
      other is Student &&
      other.id == id &&
      other.name == name &&
      other.roll == roll &&
      other.phone == phone &&
      other.guardianName == guardianName &&
      other.guardianPhone == guardianPhone &&
      other.admissionDate == admissionDate &&
      other.status == status &&
      other.leftDate == leftDate &&
      other.notes == notes &&
      other.hasPhoto == hasPhoto;

  @override
  int get hashCode => Object.hash(id, name, roll, phone, guardianName,
      guardianPhone, admissionDate, status, leftDate, notes, hasPhoto);

  @override
  String toString() => 'Student($id, $name)';
}
