// Plain-language text for the backup screens: when a backup was made, the
// entity names of the change table, and one readable line per sample row.

import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

const int _msPerDay = 86400000;
const int _msPerMinute = 60000;

/// "১৮ নভেম্বর ২০২৬, রাত ৯:১৫" for an epoch instant, in center time.
String backupWhenText(AppLocalizations l10n, AppFormat fmt, CenterTime center, int epochMs) {
  final LocalDate date = center.dateOfEpochMs(epochMs);
  final int local = epochMs + center.offsetMin * _msPerMinute;
  final int minute = (local % _msPerDay) ~/ _msPerMinute;
  return l10n.backupSafetyWhen(fmt.date(date), fmt.time(minute));
}

String entityLabel(AppLocalizations l10n, SummaryEntity e) => switch (e) {
      SummaryEntity.subjects => l10n.backupEntitySubjects,
      SummaryEntity.batches => l10n.backupEntityBatches,
      SummaryEntity.schedule => l10n.backupEntitySchedule,
      SummaryEntity.students => l10n.backupEntityStudents,
      SummaryEntity.enrollments => l10n.backupEntityEnrollments,
      SummaryEntity.attendance => l10n.backupEntityAttendance,
      SummaryEntity.payments => l10n.backupEntityPayments,
      SummaryEntity.settings => l10n.backupEntitySettings,
    };

/// Names of students and batches inside the backup (for sample lines whose row
/// only carries ids).
class SnapshotNames {
  const SnapshotNames({this.students = const {}, this.batches = const {}});

  factory SnapshotNames.of(Snapshot s, {Map<String, String> extraBatches = const {}}) {
    Map<String, String> names(String table) => <String, String>{
          for (final RowMap r in s.tables[table] ?? const <RowMap>[])
            if (r['id'] is String && r['name'] is String) r['id']! as String: r['name']! as String,
        };
    return SnapshotNames(
      students: names('students'),
      batches: <String, String>{...extraBatches, ...names('batches')},
    );
  }

  final Map<String, String> students;
  final Map<String, String> batches;
}

/// One readable line for a change-summary sample row (see `SyncDiff`: the row
/// plus `_table`, payments also `_receipt_total`).
String sampleText(AppLocalizations l10n, AppFormat fmt, SnapshotNames names, RowMap row) {
  final String unnamed = l10n.backupSampleUnnamed;
  String studentOf(Object? id) => (id is String ? names.students[id] : null) ?? unnamed;
  String batchOf(Object? id) => (id is String ? names.batches[id] : null) ?? unnamed;
  String dateOf(Object? iso) {
    final LocalDate? d = iso is String ? LocalDate.tryParse(iso) : null;
    return d == null ? '' : fmt.dateShort(d);
  }

  final Object? name = row['name'];
  switch (row['_table']) {
    case 'subjects':
    case 'batches':
    case 'students':
      return name is String && name.isNotEmpty ? name : unnamed;
    case 'batch_slots':
      final Object? wd = row['weekday'];
      final Object? start = row['start_min'];
      final Object? end = row['end_min'];
      if (wd is int && start is int && end is int) {
        return l10n.backupSamplePair(
          batchOf(row['batch_id']),
          '${fmt.weekdayShort(wd)} ${fmt.timeRange(start, end)}',
        );
      }
      return batchOf(row['batch_id']);
    case 'schedule_exceptions':
      return l10n.backupSamplePair(
        batchOf(row['batch_id']),
        dateOf(row['new_date'] ?? row['original_date']),
      );
    case 'enrollments':
      return l10n.backupSamplePair(studentOf(row['student_id']), batchOf(row['batch_id']));
    case 'attendance_sessions':
      return l10n.backupSamplePair(batchOf(row['batch_id']), dateOf(row['date']));
    case 'payments':
      final Object? total = row['_receipt_total'] ?? row['amount'];
      return l10n.backupSamplePayment(
        studentOf(row['student_id']),
        total is int ? fmt.money(total) : '',
        dateOf(row['paid_on']),
      );
    case 'other_income':
      final Object? label = row['label'];
      final Object? amount = row['amount'];
      return l10n.backupSamplePair(
        label is String && label.isNotEmpty ? label : unnamed,
        amount is int ? fmt.money(amount) : '',
      );
    case 'settings':
      final Object? key = row['id'];
      return key is String && key.isNotEmpty ? key : unnamed;
    case 'student_photos':
      return studentOf(row['student_id']);
    case 'batch_fees':
      return batchOf(row['batch_id']);
    default:
      return name is String && name.isNotEmpty ? name : unnamed;
  }
}
