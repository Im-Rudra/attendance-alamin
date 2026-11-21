// "অন্য ব্যাচে ভর্তি" (UX 2e): a batch picker grouped by subject (the student's
// current batches are disabled and ticked), the first billable month and an
// optional fee override.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/app/providers/attendance_providers.dart';
import 'package:attendance_alamin/features/students/controllers/student_form_model.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

Future<bool> openEnrollSheet(BuildContext context, String studentId) async {
  final bool? done = await showBhorSheet<bool>(
    context,
    title: context.l10n.stuEnrollTitle,
    builder: (BuildContext ctx) => EnrollSheet(studentId: studentId),
  );
  return done ?? false;
}

class EnrollSheet extends ConsumerStatefulWidget {
  const EnrollSheet({super.key, required this.studentId});

  final String studentId;

  @override
  ConsumerState<EnrollSheet> createState() => _EnrollSheetState();
}

class _EnrollSheetState extends ConsumerState<EnrollSheet> {
  final EnrollChoice _choice = EnrollChoice();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _choice.dispose();
    super.dispose();
  }

  Future<void> _enroll(LocalDate today, int cutoff) async {
    final l10n = context.l10n;
    final String? batchId = _choice.batchId;
    if (batchId == null) return;
    final ({bool ok, int? amount}) fee = _choice.parseFee(l10n);
    if (!fee.ok) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(enrollmentsRepositoryProvider).enroll(
            studentId: widget.studentId,
            batchId: batchId,
            joinDate: today,
            startMonth: _choice.startFor(today, cutoff),
            feeOverride: fee.amount,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData th = context.bhor;
    final LocalDate today = ref.watch(todayProvider);
    final int cutoff = ref.watch(stuCutoffProvider).value ?? 15;
    final Student? student = ref.watch(stuStudentProvider(widget.studentId)).value;
    final List<Batch> batches = ref.watch(stuBatchesProvider).value ?? const <Batch>[];
    final List<Subject> subjects = ref.watch(stuSubjectsProvider).value ?? const <Subject>[];
    final List<Enrollment> mine =
        ref.watch(studentEnrollmentsProvider(widget.studentId)).value ??
            const <Enrollment>[];
    final Set<String> enrolled = <String>{
      for (final Enrollment e in mine)
        if (e.endDate == null) e.batchId,
    };
    final List<Batch> open = <Batch>[
      for (final Batch b in batches)
        if (!b.archived) b,
    ]..sort((Batch x, Batch y) => x.sortOrder.compareTo(y.sortOrder));

    List<Widget> buildGroups() {
      final List<Widget> groups = <Widget>[];
      final Set<String> placed = <String>{};
      void addGroup(String title, List<Batch> list) {
        if (list.isEmpty) return;
        groups.add(Padding(
          padding: const EdgeInsets.fromLTRB(BhorSpace.s4, BhorSpace.s12, BhorSpace.s4, BhorSpace.s8),
          child: Semantics(
            header: true,
            child: Text(title, style: th.type.label.copyWith(color: th.colors.accent)),
          ),
        ));
        for (final Batch bt in list) {
          placed.add(bt.id);
          final bool already = enrolled.contains(bt.id);
          groups.add(Padding(
            padding: const EdgeInsets.only(bottom: BhorSpace.s8),
            child: BhorRadioCard<String>(
              value: bt.id,
              groupValue: _choice.batchId,
              onChanged: already ? null : _choice.setBatch,
              title: bt.name,
              subtitle: already ? l10n.stuAlreadyInBatch : null,
            ),
          ));
        }
      }

      for (final Subject s in subjects) {
        addGroup(s.name, <Batch>[
          for (final Batch bt in open)
            if (bt.subjectId == s.id) bt,
        ]);
      }
      addGroup(l10n.stuBatchesOther, <Batch>[
        for (final Batch bt in open)
          if (!placed.contains(bt.id)) bt,
      ]);
      return groups;
    }

    return SingleChildScrollView(
        child: ListenableBuilder(
          listenable: _choice,
          builder: (BuildContext context, Widget? _) {
            final List<Widget> groups = buildGroups();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (student != null)
                  Text(student.name, style: th.type.body.copyWith(color: th.colors.text2)),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: BhorSpace.s24),
                    child: Text(l10n.stuNoBatchesToJoin, textAlign: TextAlign.center, style: th.type.body),
                  ),
                ...groups,
                const SizedBox(height: BhorSpace.s16),
                if (_choice.batchId != null) StartMonthFeeFields(choice: _choice, join: today, cutoff: cutoff),
                const SizedBox(height: BhorSpace.s16),
                BhorButton(
                  key: const ValueKey<String>('stu-enroll-confirm'),
                  label: l10n.stuEnrollConfirm,
                  expand: true,
                  onPressed: (_busy || _choice.batchId == null) ? null : () => _enroll(today, cutoff),
                ),
                if (_choice.batchId == null)
                  Padding(
                    padding: const EdgeInsets.only(top: BhorSpace.s8),
                    child: Text(
                      l10n.stuPickBatchFirst,
                      textAlign: TextAlign.center,
                      style: th.type.label.copyWith(color: th.colors.text2),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: BhorSpace.s8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_error!, style: th.type.body.copyWith(color: th.colors.danger)),
                    ),
                  ),
              ],
            );
          },
        ),
    );
  }
}
