// "টাকা নিন" on the Fees tab: a fast student picker (search by name, roll or
// phone in Bangla or ASCII digits; most-owing first) that hands the chosen
// student to the existing collect-payment sheet.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';

/// One line of the picker.
class PickerStudent {
  const PickerStudent({required this.student, required this.owed});

  final Student student;

  /// Outstanding taka over all live enrollments.
  final int owed;
}

/// Live students that have an enrollment, most owing first, then by name.
List<PickerStudent> buildPickerRows({
  required List<Student> students,
  required List<EnrollmentTerms> terms,
  required DuesReport? report,
}) {
  final Set<String> enrolled = <String>{
    for (final EnrollmentTerms t in terms)
      if (!t.studentLeft && !t.batchArchived && !t.enrollmentEnded) t.studentId,
  };
  final Map<String, int> owed = <String, int>{
    if (report != null)
      for (final StudentDues d in report.active) d.studentId: d.totalOutstanding,
  };
  final List<PickerStudent> rows = <PickerStudent>[
    for (final Student s in students)
      if (s.status == StudentStatus.active && enrolled.contains(s.id))
        PickerStudent(student: s, owed: owed[s.id] ?? 0),
  ];
  rows.sort((PickerStudent a, PickerStudent b) {
    final int byOwed = b.owed.compareTo(a.owed);
    if (byOwed != 0) return byOwed;
    return a.student.name.toLowerCase().compareTo(b.student.name.toLowerCase());
  });
  return rows;
}

/// Name, roll or phone contains [query] (Bangla and ASCII digits alike).
bool pickerMatches(Student s, String query) {
  final String q = AppFormat.toAsciiDigits(query.trim().toLowerCase());
  if (q.isEmpty) return true;
  bool has(String? v) => v != null && AppFormat.toAsciiDigits(v.toLowerCase()).contains(q);
  return has(s.name) || has(s.roll) || has(s.phone) || has(s.guardianPhone);
}


/// Opens the picker (sheet on phones, centred dialog on desktop), then the
/// collect-payment sheet / side panel of the chosen student.
Future<void> showTakeMoneyPicker(BuildContext context, {BuildContext? anchor}) async {
  final String? id = await showBhorPanel<String>(
    context,
    anchor: anchor,
    title: context.l10n.duesPickerTitle,
    kind: BhorPanelKind.list,
    scroll: false,
    builder: (BuildContext ctx) => const TakeMoneyPicker(),
  );
  if (id == null || !context.mounted) return;
  await showCollectPaymentSheet(context, studentId: id);
}

class TakeMoneyPicker extends ConsumerStatefulWidget {
  const TakeMoneyPicker({super.key});

  @override
  ConsumerState<TakeMoneyPicker> createState() => _TakeMoneyPickerState();
}

class _TakeMoneyPickerState extends ConsumerState<TakeMoneyPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final List<Student> students = ref.watch(duesStudentsProvider).value ?? const <Student>[];
    final List<EnrollmentTerms> terms = ref.watch(enrollmentTermsProvider).value ?? const <EnrollmentTerms>[];
    final DuesReport? report = ref.watch(duesReportProvider).value;
    final List<PickerStudent> rows = <PickerStudent>[
      for (final PickerStudent r in buildPickerRows(students: students, terms: terms, report: report))
        if (pickerMatches(r.student, _query)) r,
    ];
    final double height = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BhorTextField(
            key: const ValueKey<String>('picker-search'),
            semanticLabel: l10n.duesPickerSearch,
            textInputAction: TextInputAction.search,
            prefix: const Icon(BhorIcons.search),
            hint: l10n.duesPickerSearch,
            onChanged: (String v) => setState(() => _query = v),
          ),
          const SizedBox(height: BhorSpace.s8),
          Expanded(
            child: rows.isEmpty
                ? BhorEmptyState(icon: BhorIcons.search, title: l10n.duesPickerNone)
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (BuildContext ctx, int i) {
                      final PickerStudent r = rows[i];
                      final List<String> sub = <String>[
                        if (r.student.roll != null && r.student.roll!.isNotEmpty) fmt.digits(r.student.roll!),
                        if (r.student.phone != null && r.student.phone!.isNotEmpty) fmt.digits(r.student.phone!),
                      ];
                      return BhorListRow(
                        key: ValueKey<String>('picker-${r.student.id}'),
                        leading: BhorAvatar(name: r.student.name, size: 40),
                        title: r.student.name,
                        subtitle: sub.isEmpty ? null : sub.join(' · '),
                        divider: i < rows.length - 1,
                        trailing: r.owed > 0
                            ? Text(l10n.duesPickerOwes(fmt.money(r.owed)), style: b.type.label)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(r.student.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
