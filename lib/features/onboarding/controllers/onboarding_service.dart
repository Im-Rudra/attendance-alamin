// The writes of onboarding (no widgets): first batch, quick-add students, the
// center name and the "done" flag. Validation is the same as the real forms,
// so a student or batch made here is indistinguishable from one made later.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/repositories/batches_repository.dart';
import 'package:attendance_alamin/data/repositories/enrollments_repository.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_repository.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/data/repositories/students_repository.dart';
import 'package:attendance_alamin/data/repositories/subjects_repository.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/subject.dart';

/// One student saved during onboarding.
class SavedStudent {
  const SavedStudent({required this.id, required this.name, required this.roll, this.guardianPhone});

  final String id;
  final String name;
  final String roll;

  /// Validated guardian phone, when one was given.
  final String? guardianPhone;
}

class OnboardingService {
  OnboardingService({
    required this.subjects,
    required this.batches,
    required this.students,
    required this.enrollments,
    required this.settings,
    required this.today,
  });

  final SubjectsRepository subjects;
  final BatchesRepository batches;
  final StudentsRepository students;
  final EnrollmentsRepository enrollments;
  final SettingsRepository settings;
  final LocalDate Function() today;

  /// Stores the center name (blank = leave unset).
  Future<void> saveCenterName(String raw) async {
    final String name = raw.trim();
    if (name.isEmpty) return;
    await settings.set(SettingKeys.centerName, Validators.name(name));
  }

  /// Creates the subject (or reuses one with the same name) and the batch with
  /// its slots and first fee. Returns the batch id. Throws `AppException`s.
  Future<String> createBatch({
    required String subject,
    required String batchName,
    required String fee,
    required BillingType billing,
    required List<SlotDraft> slots,
  }) async {
    final String subjectText = Validators.name(subject);
    final String name = Validators.name(batchName);
    final int monthlyFee = Validators.amount(fee);
    final Subject? existing = await subjects.findByName(subjectText);
    final String subjectId = existing?.id ?? await subjects.create(name: subjectText);
    final LocalDate d = today();
    return batches.create(BatchDraft(
      subjectId: subjectId,
      name: name,
      billingType: billing,
      monthlyFee: monthlyFee,
      feeFrom: d.yearMonth,
      slots: slots,
      slotsFrom: d,
    ));
  }

  /// Saves one student (name + optional guardian phone) with the next roll and,
  /// when [batchId] is given, enrols them. A failed enrolment removes the
  /// student again so no orphan is left.
  Future<SavedStudent> addStudent({
    required String name,
    required String guardianPhone,
    String? batchId,
  }) async {
    final String n = Validators.name(name);
    final String? phone = Validators.phone(guardianPhone);
    final LocalDate d = today();
    final String roll = await students.nextRoll();
    final String id = await students.create(StudentDraft(
      name: n,
      roll: roll,
      guardianPhone: phone,
      admissionDate: d,
    ));
    if (batchId != null) {
      try {
        // Existing students: billing starts this month (Product 3.2).
        await enrollments.enroll(
          studentId: id,
          batchId: batchId,
          joinDate: d,
          startMonth: d.yearMonth,
        );
      } catch (_) {
        await students.softDelete(id);
        rethrow;
      }
    }
    return SavedStudent(id: id, name: n, roll: roll, guardianPhone: phone);
  }

  /// Marks onboarding as finished (the app opens on Today from now on).
  Future<void> markDone() => settings.set(SettingKeys.onboardingDone, true);
}

final onboardingServiceProvider = Provider<OnboardingService>((ref) => OnboardingService(
      subjects: ref.watch(subjectsRepositoryProvider),
      batches: ref.watch(batchesRepositoryProvider),
      students: ref.watch(studentsRepositoryProvider),
      enrollments: ref.watch(enrollmentsRepositoryProvider),
      settings: ref.watch(settingsRepositoryProvider),
      today: () => ref.read(todayProvider),
    ));

/// Start of the first class slot a new center is offered: the next full hour
/// after [nowMin] (minute of day), kept to the 07:00-20:00 coaching day;
/// outside it the default is 16:00 (বিকাল ৪:০০). The slot is one hour long.
int defaultSlotStartMin(int nowMin) {
  final int next = (nowMin ~/ 60 + 1) * 60;
  return (next >= 7 * 60 && next <= 20 * 60) ? next : 16 * 60;
}
