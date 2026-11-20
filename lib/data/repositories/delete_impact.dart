/// What a soft delete takes with it, shown in the confirm dialog
/// ("১২০টি হাজিরা ও ৩০টি পেমেন্ট সহ মুছে যাবে", Product 3.8).
///
/// Plan M4-A declares this class in `batches_repository.dart`; it lives here so
/// the people repositories (built in parallel) can use it without importing
/// M4-A. `batches_repository.dart` should export this file instead of
/// declaring its own copy.
class DeleteImpact {
  const DeleteImpact({
    required this.sessions,
    required this.payments,
    required this.students,
  });

  /// Attendance rows that go with it (sessions for a batch, marks for a student).
  final int sessions;

  /// Payment records (receipts) that go with it.
  final int payments;

  /// Students affected (enrollments for a batch, 1 for a student).
  final int students;

  @override
  bool operator ==(Object other) =>
      other is DeleteImpact &&
      other.sessions == sessions &&
      other.payments == payments &&
      other.students == students;

  @override
  int get hashCode => Object.hash(sessions, payments, students);

  @override
  String toString() => 'DeleteImpact($sessions, $payments, $students)';
}
