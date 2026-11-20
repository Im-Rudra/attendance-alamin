// "অন্য ব্যাচে ভর্তি" (UX 2e): a batch picker grouped by subject (the student's
// current batches are disabled and ticked), the first billable month and an
// optional fee override.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
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
  final bool? done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
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
    ]..sort((Batch a, Batch b) => a.sortOrder.compareTo(b.sortOrder));

    List<Widget> buildGroups() {
    final List<Widget> groups = <Widget>[];
    final Set<String> placed = <String>{};
    void addGroup(String title, List<Batch> list) {
      if (list.isEmpty) return;
      groups.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Semantics(
          header: true,
          child: Text(title,
              style: tt.labelLarge?.copyWith(color: tokens.accent)),
        ),
      ));
      for (final Batch b in list) {
        placed.add(b.id);
        final bool already = enrolled.contains(b.id);
        final bool selected = _choice.batchId == b.id;
        groups.add(Semantics(
          button: true,
          selected: selected,
          enabled: !already,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: already ? null : () => _choice.setBatch(b.id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: <Widget>[
                    Icon(
                      already
                          ? Icons.check_circle
                          : (selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked),
                      color: already
                          ? tokens.textDisabled
                          : (selected ? tokens.accent : tokens.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        b.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyLarge?.copyWith(
                          color: already
                              ? tokens.textDisabled
                              : tokens.textPrimary,
                        ),
                      ),
                    ),
                    if (already)
                      Text(l10n.stuAlreadyInBatch,
                          style: tt.labelMedium
                              ?.copyWith(color: tokens.textDisabled)),
                  ],
                ),
              ),
            ),
          ),
        ));
      }
    }

    for (final Subject s in subjects) {
      addGroup(s.name, <Batch>[
        for (final Batch b in open)
          if (b.subjectId == s.id) b,
      ]);
    }
    addGroup(l10n.stuBatchesOther, <Batch>[
      for (final Batch b in open)
        if (!placed.contains(b.id)) b,
    ]);
    return groups;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: ListenableBuilder(
          listenable: _choice,
          builder: (BuildContext context, Widget? _) {
            final List<Widget> groups = buildGroups();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(l10n.stuEnrollTitle, style: tt.titleLarge),
                ),
                if (student != null)
                  Text(student.name,
                      style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(l10n.stuNoBatchesToJoin,
                        textAlign: TextAlign.center, style: tt.bodyLarge),
                  ),
                ...groups,
                const SizedBox(height: 16),
                if (_choice.batchId != null)
                  StartMonthFeeFields(
                      choice: _choice, join: today, cutoff: cutoff),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey<String>('stu-enroll-confirm'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  onPressed: (_busy || _choice.batchId == null)
                      ? null
                      : () => _enroll(today, cutoff),
                  child: Text(l10n.stuEnrollConfirm),
                ),
                if (_choice.batchId == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l10n.stuPickBatchFirst,
                        textAlign: TextAlign.center,
                        style:
                            tt.labelMedium?.copyWith(color: tokens.textSecondary)),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_error!,
                          style: tt.bodyMedium?.copyWith(color: tokens.error)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
