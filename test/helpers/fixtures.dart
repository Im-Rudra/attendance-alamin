// Realistic Bangladeshi sample data (Product 6 seed) as domain objects, and
// `seedFakes` which loads it into the fake repositories of test/helpers/fakes.
//
// Seed: subject "Physics" -> batch "Physics A" (prepaid, 1000, Sat/Mon/Wed
// 16:00-17:00), subject "Chemistry" -> batch "Chem B" (postpaid, 800, Sun/Tue
// 10:00-11:00, reminder lead 30). Rahim and Nila are in Physics A, Karim in
// Chem B, Sara in both. "Today" is 2026-11-21, a Saturday.

import 'package:flutter_riverpod/misc.dart';

import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/attendance.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/fee_period.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/domain/schedule/occ_id.dart';

import 'fakes/fake_people_repos.dart';
import 'fakes/fake_settings_repos.dart';
import 'fakes/fake_structure_repos.dart';

export 'pump_app.dart' show at, kTestNowUtc;

// ---- ids -------------------------------------------------------------------

const String kSubPhysics = 'sub-physics';
const String kSubChemistry = 'sub-chemistry';
const String kBatPhysA = 'bat-physics-a';
const String kBatChemB = 'bat-chem-b';

const String kSlotPhysSat = 'slot-phys-sat';
const String kSlotPhysMon = 'slot-phys-mon';
const String kSlotPhysWed = 'slot-phys-wed';
const String kSlotChemSun = 'slot-chem-sun';
const String kSlotChemTue = 'slot-chem-tue';

const String kStuRahim = 'stu-rahim';
const String kStuKarim = 'stu-karim';
const String kStuSara = 'stu-sara';
const String kStuNila = 'stu-nila';

const String kEnrRahimPhys = 'enr-rahim-phys';
const String kEnrKarimChem = 'enr-karim-chem';
const String kEnrSaraPhys = 'enr-sara-phys';
const String kEnrSaraChem = 'enr-sara-chem';
const String kEnrNilaPhys = 'enr-nila-phys';

/// The seed's "today" (a Saturday).
const LocalDate kToday = LocalDate(2026, 11, 21);

/// Physics A class time 16:00-17:00 and Chem B 10:00-11:00 (minutes).
const int kPhysStart = 960, kPhysEnd = 1020;
const int kChemStart = 600, kChemEnd = 660;

// ---- structure -------------------------------------------------------------

const List<Subject> kSubjects = <Subject>[
  Subject(id: kSubPhysics, name: 'পদার্থবিজ্ঞান', sortOrder: 0),
  Subject(id: kSubChemistry, name: 'রসায়ন', sortOrder: 1),
];

const List<Batch> kBatches = <Batch>[
  Batch(
    id: kBatPhysA,
    subjectId: kSubPhysics,
    name: 'ফিজিক্স এ',
    billingType: BillingType.prepaid,
    createdOn: LocalDate(2026, 1, 1),
    sortOrder: 0,
  ),
  Batch(
    id: kBatChemB,
    subjectId: kSubChemistry,
    name: 'কেমিস্ট্রি বি',
    billingType: BillingType.postpaid,
    createdOn: LocalDate(2026, 1, 1),
    sortOrder: 1,
    reminderLeadMin: 30,
  ),
];

/// Weekdays are ISO: Mon 1 .. Sun 7.
const List<Slot> kSlots = <Slot>[
  Slot(id: kSlotPhysSat, batchId: kBatPhysA, weekday: 6, startMin: kPhysStart, endMin: kPhysEnd),
  Slot(id: kSlotPhysMon, batchId: kBatPhysA, weekday: 1, startMin: kPhysStart, endMin: kPhysEnd),
  Slot(id: kSlotPhysWed, batchId: kBatPhysA, weekday: 3, startMin: kPhysStart, endMin: kPhysEnd),
  Slot(id: kSlotChemSun, batchId: kBatChemB, weekday: 7, startMin: kChemStart, endMin: kChemEnd),
  Slot(id: kSlotChemTue, batchId: kBatChemB, weekday: 2, startMin: kChemStart, endMin: kChemEnd),
];

/// Batch monthly fees from January 2026.
const Map<String, int> kBatchFee = <String, int>{kBatPhysA: 1000, kBatChemB: 800};

// ---- people ----------------------------------------------------------------

const List<Student> kStudents = <Student>[
  Student(
    id: kStuRahim,
    name: 'রহিম উদ্দিন',
    roll: '1',
    phone: '01711223344',
    guardianName: 'আব্দুল উদ্দিন',
    guardianPhone: '01811223344',
    admissionDate: LocalDate(2026, 9, 5),
    status: StudentStatus.active,
  ),
  Student(
    id: kStuKarim,
    name: 'করিম হোসেন',
    roll: '2',
    phone: '01922334455',
    guardianName: 'জাহাঙ্গীর হোসেন',
    guardianPhone: '01822334455',
    admissionDate: LocalDate(2026, 11, 2),
    status: StudentStatus.active,
  ),
  Student(
    id: kStuSara,
    name: 'সারা আক্তার',
    roll: '3',
    phone: '01633445566',
    guardianName: 'রহিমা বেগম',
    guardianPhone: '01733445566',
    admissionDate: LocalDate(2026, 10, 3),
    status: StudentStatus.active,
  ),
  Student(
    id: kStuNila,
    name: 'নীলা বেগম',
    roll: '4',
    guardianName: 'কামাল আহমেদ',
    guardianPhone: '01544556677',
    admissionDate: LocalDate(2026, 11, 10),
    status: StudentStatus.active,
  ),
];

const List<Enrollment> kEnrollments = <Enrollment>[
  Enrollment(
    id: kEnrRahimPhys,
    studentId: kStuRahim,
    batchId: kBatPhysA,
    joinDate: LocalDate(2026, 9, 5),
    startMonth: YearMonth(2026, 9),
  ),
  Enrollment(
    id: kEnrKarimChem,
    studentId: kStuKarim,
    batchId: kBatChemB,
    joinDate: LocalDate(2026, 11, 2),
    startMonth: YearMonth(2026, 11),
  ),
  Enrollment(
    id: kEnrSaraPhys,
    studentId: kStuSara,
    batchId: kBatPhysA,
    joinDate: LocalDate(2026, 10, 3),
    startMonth: YearMonth(2026, 10),
  ),
  Enrollment(
    id: kEnrSaraChem,
    studentId: kStuSara,
    batchId: kBatChemB,
    joinDate: LocalDate(2026, 10, 3),
    startMonth: YearMonth(2026, 10),
  ),
  Enrollment(
    id: kEnrNilaPhys,
    studentId: kStuNila,
    batchId: kBatPhysA,
    joinDate: LocalDate(2026, 11, 10),
    startMonth: YearMonth(2026, 11),
  ),
];

/// The dues-engine view of [kEnrollments] (what `watchTerms` returns).
List<EnrollmentTerms> termsFor(List<Enrollment> enrollments) {
  final students = {for (final s in kStudents) s.id: s};
  final batches = {for (final b in kBatches) b.id: b};
  final subjects = {for (final s in kSubjects) s.id: s};
  return <EnrollmentTerms>[
    for (final e in enrollments)
      EnrollmentTerms(
        enrollmentId: e.id,
        studentId: e.studentId,
        batchId: e.batchId,
        studentName: students[e.studentId]?.name ?? '',
        batchName: batches[e.batchId]?.name ?? '',
        subjectName: subjects[batches[e.batchId]?.subjectId]?.name ?? '',
        billing: batches[e.batchId]?.billingType ?? BillingType.prepaid,
        start: e.startMonth,
        end: e.endMonth,
        batchFees: <FeePeriod>[
          FeePeriod(
              effective: const YearMonth(2026, 1),
              amount: kBatchFee[e.batchId]),
        ],
      ),
  ];
}

// ---- money -----------------------------------------------------------------

Payment _payment(String id, String student, String enrollment, String batch,
        YearMonth month, int amount, LocalDate paidOn,
        {PaymentMethod method = PaymentMethod.cash}) =>
    Payment(
      id: 'pay-$id',
      receiptId: 'rcp-$id',
      studentId: student,
      enrollmentId: enrollment,
      batchId: batch,
      billingMonth: month,
      amount: amount,
      paidOn: paidOn,
      method: method,
    );

/// Rahim paid September and October; Sara paid October and November of
/// Physics A (bKash). Nobody paid anything else.
final List<Payment> kPayments = <Payment>[
  _payment('1', kStuRahim, kEnrRahimPhys, kBatPhysA, const YearMonth(2026, 9),
      1000, const LocalDate(2026, 9, 5)),
  _payment('2', kStuRahim, kEnrRahimPhys, kBatPhysA, const YearMonth(2026, 10),
      1000, const LocalDate(2026, 10, 4)),
  _payment('3', kStuSara, kEnrSaraPhys, kBatPhysA, const YearMonth(2026, 10),
      1000, const LocalDate(2026, 10, 3),
      method: PaymentMethod.bkash),
  _payment('4', kStuSara, kEnrSaraPhys, kBatPhysA, const YearMonth(2026, 11),
      1000, const LocalDate(2026, 11, 2),
      method: PaymentMethod.bkash),
];

/// Enrollment id -> batch id (the payments fake fills `Payment.batchId`).
final Map<String, String> kBatchOfEnrollment = <String, String>{
  for (final e in kEnrollments) e.id: e.batchId,
};

// ---- attendance ------------------------------------------------------------

/// Physics A class days with a saved roll call (Sat/Mon/Wed, 7-18 Nov).
const List<String> kRollCallDays = <String>[
  '2026-11-07',
  '2026-11-09',
  '2026-11-11',
  '2026-11-14',
  '2026-11-16',
  '2026-11-18',
];

const Map<String, String> _slotOfWeekday = <String, String>{
  '6': kSlotPhysSat,
  '1': kSlotPhysMon,
  '3': kSlotPhysWed,
};

/// The occurrence id of the Physics A class on [date] (a seeded class day).
String physOcc(String date) {
  final d = LocalDate.parse(date);
  return OccId.regular(_slotOfWeekday['${d.isoWeekday}']!, d);
}

/// Physics A roll calls on [kRollCallDays]. Rahim is absent the last three
/// (absence streak), Sara is late once and on leave once, Nila (joined 10 Nov)
/// is marked from 11 Nov on.
List<AttendanceSession> seedSessions() => <AttendanceSession>[
      for (final day in kRollCallDays)
        AttendanceSession(
          id: Ids.sessionForOcc(physOcc(day)),
          occ: physOcc(day),
          batchId: kBatPhysA,
          slotId: _slotOfWeekday['${LocalDate.parse(day).isoWeekday}'],
          date: LocalDate.parse(day),
          startMin: kPhysStart,
          endMin: kPhysEnd,
        ),
    ];

List<AttendanceRecord> seedRecords() {
  const pr = AttendanceStatus.present;
  const ab = AttendanceStatus.absent;
  const lt = AttendanceStatus.late;
  const lv = AttendanceStatus.leave;
  // Rows follow [kRollCallDays]; null = not enrolled yet.
  const marks = <String, List<AttendanceStatus?>>{
    kStuRahim: [pr, pr, pr, ab, ab, ab],
    kStuSara: [pr, pr, lt, pr, lv, pr],
    kStuNila: [null, null, pr, ab, pr, pr],
  };
  return <AttendanceRecord>[
    for (final entry in marks.entries)
      for (var i = 0; i < kRollCallDays.length; i++)
        if (entry.value[i] case final status?)
          AttendanceRecord(
            id: Ids.record(physOcc(kRollCallDays[i]), entry.key),
            sessionId: Ids.sessionForOcc(physOcc(kRollCallDays[i])),
            batchId: kBatPhysA,
            studentId: entry.key,
            date: LocalDate.parse(kRollCallDays[i]),
            status: status,
          ),
  ];
}

// ---- the fakes -------------------------------------------------------------

/// The M4 fake repositories filled with the seed. Mutate their public lists /
/// call their methods, then (for list edits) `store.notify()`.
class SeededFakes {
  SeededFakes({
    required this.store,
    required this.subjects,
    required this.batches,
    required this.schedule,
    required this.students,
    required this.enrollments,
    required this.payments,
    required this.attendance,
    required this.otherIncome,
    required this.settings,
    required this.localMeta,
  });

  final FakeStructureStore store;
  final FakeSubjectsRepository subjects;
  final FakeBatchesRepository batches;
  final FakeScheduleRepository schedule;
  final FakeStudentsRepository students;
  final FakeEnrollmentsRepository enrollments;
  final FakePaymentsRepository payments;
  final FakeAttendanceRepository attendance;
  final FakeOtherIncomeRepository otherIncome;
  final FakeSettingsRepository settings;
  final FakeLocalMetaRepository localMeta;

  /// Provider overrides wiring every fake in (pass to `pumpApp` /
  /// `makeContainer`).
  List<Override> get overrides => <Override>[
        subjectsRepositoryProvider.overrideWithValue(subjects),
        batchesRepositoryProvider.overrideWithValue(batches),
        scheduleRepositoryProvider.overrideWithValue(schedule),
        studentsRepositoryProvider.overrideWithValue(students),
        enrollmentsRepositoryProvider.overrideWithValue(enrollments),
        paymentsRepositoryProvider.overrideWithValue(payments),
        attendanceRepositoryProvider.overrideWithValue(attendance),
        otherIncomeRepositoryProvider.overrideWithValue(otherIncome),
        settingsRepositoryProvider.overrideWithValue(settings),
        localMetaRepositoryProvider.overrideWithValue(localMeta),
      ];
}

/// Fresh fakes holding the seed. [withAttendance] false leaves no roll calls;
/// [withPayments] false leaves every month unpaid. [today] is the fakes' own
/// "today" (batch creation, waivers); the clock is set by `pumpApp` /
/// `makeContainer`.
SeededFakes seedFakes({
  LocalDate today = kToday,
  bool withAttendance = true,
  bool withPayments = true,
  Map<String, Object?>? encodedSettings,
}) {
  final store = FakeStructureStore(today: today)
    ..subjects.addAll(kSubjects)
    ..batches.addAll(kBatches)
    ..slots.addAll(kSlots);
  for (final b in kBatches) {
    store.fees[b.id] = <FeePeriod>[
      FeePeriod(effective: const YearMonth(2026, 1), amount: kBatchFee[b.id]),
    ];
  }
  final students = FakeStudentsRepository(students: kStudents)..today = today;
  final payments = FakePaymentsRepository(
    payments: withPayments ? kPayments : const <Payment>[],
    batchOfEnrollment: kBatchOfEnrollment,
  )..today = today;
  return SeededFakes(
    store: store,
    subjects: FakeSubjectsRepository(store),
    batches: FakeBatchesRepository(store),
    schedule: FakeScheduleRepository(store),
    students: students,
    enrollments: FakeEnrollmentsRepository(
      enrollments: kEnrollments,
      terms: termsFor(kEnrollments),
      students: kStudents,
    ),
    payments: payments,
    attendance: FakeAttendanceRepository(
      sessions: withAttendance ? seedSessions() : const <AttendanceSession>[],
      records: withAttendance ? seedRecords() : const <AttendanceRecord>[],
    ),
    otherIncome: FakeOtherIncomeRepository(),
    settings: FakeSettingsRepository(encodedSettings),
    localMeta: FakeLocalMetaRepository(),
  );
}
