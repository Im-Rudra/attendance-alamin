// Add / edit a student (full-screen route). A new student can be enrolled in
// one batch at once (`initialBatchId` comes from the route `extra`); saving
// runs the duplicate guard (UX 2e).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_form_model.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/widgets/student_dialogs.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

class StudentFormScreen extends ConsumerStatefulWidget {
  const StudentFormScreen({super.key, this.studentId, this.initialBatchId});

  /// null = add a new student.
  final String? studentId;

  /// Batch to enrol the new student in (passed as route `extra`).
  final String? initialBatchId;

  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  StudentFormModel? _model;
  EnrollChoice? _choice;
  bool _missing = false;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.studentId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _model?.dispose();
    _choice?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(studentsRepositoryProvider);
    final LocalDate today = ref.read(todayProvider);
    final String? id = widget.studentId;
    if (id == null) {
      final String roll = await repo.nextRoll();
      if (!mounted) return;
      setState(() {
        _model = StudentFormModel(admissionDate: today, roll: roll);
        _choice = EnrollChoice(batchId: widget.initialBatchId);
      });
      return;
    }
    final Student? s = await repo.getById(id);
    if (!mounted) return;
    if (s == null) {
      setState(() => _missing = true);
      return;
    }
    final StudentFormModel m = StudentFormModel.from(s);
    if (s.hasPhoto) m.photo = await repo.getPhoto(id);
    if (!mounted) {
      m.dispose();
      return;
    }
    setState(() => _model = m);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final StudentFormModel model = _model!;
    final StudentDraft? draft = model.validate(l10n);
    final EnrollChoice? choice = _choice;
    final ({bool ok, int? amount}) fee = (choice != null && choice.batchId != null)
        ? choice.parseFee(l10n)
        : (ok: true, amount: null);
    if (draft == null || !fee.ok) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final students = ref.read(studentsRepositoryProvider);
      final String? editId = widget.studentId;
      if (editId != null) {
        await students.update(editId, draft);
        if (model.photoChanged) {
          await students.setPhoto(editId, model.photo);
          if (mounted) ref.invalidate(stuPhotoProvider((id: editId, has: true)));
        }
        messenger?.showSnackBar(SnackBar(content: Text(l10n.stuSaved(draft.name))));
        if (!mounted) return;
        stuClose(context, fallback: Routes.student(editId));
        return;
      }
      final String? batchId = choice?.batchId;
      final List<Student> dups = await findPhoneDuplicates(students, draft);
      if (!mounted) return;
      if (dups.isNotEmpty) {
        final DuplicateChoice? c = await showDuplicateDialog(context,
            existing: dups.first, hasBatch: batchId != null);
        if (!mounted) return;
        if (c == null) {
          setState(() => _busy = false);
          return;
        }
        if (c == DuplicateChoice.useExisting) {
          final Student existing = dups.first;
          if (batchId != null) {
            final int cutoffDay = await ref.read(stuCutoffProvider.future);
            await ref.read(enrollmentsRepositoryProvider).enroll(
                  studentId: existing.id,
                  batchId: batchId,
                  joinDate: draft.admissionDate,
                  startMonth: choice!.startFor(draft.admissionDate, cutoffDay),
                  feeOverride: fee.amount,
                );
            messenger?.showSnackBar(
                SnackBar(content: Text(l10n.stuAddedToBatch(existing.name))));
            if (!mounted) return;
            stuClose(context);
          } else {
            if (!mounted) return;
            stuGo(context, Routes.student(existing.id));
          }
          return;
        }
      }
      final int startCutoff = await ref.read(stuCutoffProvider.future);
      await createStudentAndEnroll(
        students: students,
        enrollments: ref.read(enrollmentsRepositoryProvider),
        draft: draft,
        photo: model.photo,
        batchId: batchId,
        startMonth: choice?.startFor(draft.admissionDate, startCutoff),
        feeOverride: fee.amount,
      );
      messenger?.showSnackBar(SnackBar(content: Text(l10n.stuSaved(draft.name))));
      if (!mounted) return;
      stuClose(context);
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
    final double gutter = WindowClass.of(context).gutter;
    final LocalDate today = ref.watch(todayProvider);
    final int cutoff = ref.watch(stuCutoffProvider).value ?? 15;
    final StudentFormModel? model = _model;
    final EnrollChoice? choice = _choice;
    final List<Batch> batches = <Batch>[
      for (final Batch b in ref.watch(stuBatchesProvider).value ?? const <Batch>[])
        if (!b.archived) b,
    ];
    final List<Subject> subjects =
        ref.watch(stuSubjectsProvider).value ?? const <Subject>[];
    String subjectOf(Batch b) {
      for (final Subject s in subjects) {
        if (s.id == b.subjectId) return s.name;
      }
      return '';
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonClose,
          icon: const Icon(Icons.close),
          onPressed: () => stuClose(context),
        ),
        title: Semantics(
          header: true,
          child: Text(_isNew
              ? l10n.shellTitleStudentNew
              : l10n.shellTitleStudentEdit),
        ),
      ),
      bottomNavigationBar: model == null
          ? null
          : StickyActionBar(
              label: l10n.stuSave,
              onPressed: _busy ? null : _save,
            ),
      body: SafeArea(
        top: false,
        child: _missing
            ? EmptyState(
                icon: Icons.person_off_outlined, message: l10n.stuNotFound)
            : model == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(gutter, 8, gutter, gutter),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: GlassCard(
                          dense: true,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              StudentFieldsView(
                                model: model,
                                today: today,
                                autofocusName: _isNew,
                                moreExpanded: !_isNew,
                              ),
                              if (_isNew && choice != null) ...<Widget>[
                                const SizedBox(height: 16),
                                Text(l10n.stuEnrollSection,
                                    style: tt.titleMedium),
                                const SizedBox(height: 8),
                                ListenableBuilder(
                                  listenable: choice,
                                  builder: (BuildContext context, Widget? _) {
                                    final String? chosen = choice.batchId;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        InputDecorator(
                                          decoration: InputDecoration(
                                              labelText: l10n.stuBatchOptional),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              key: const ValueKey<String>(
                                                  'stu-form-batch'),
                                              value: batches.any((Batch b) =>
                                                      b.id == chosen)
                                                  ? chosen
                                                  : '',
                                              isExpanded: true,
                                              isDense: true,
                                              items: <DropdownMenuItem<String>>[
                                                DropdownMenuItem<String>(
                                                  value: '',
                                                  child: Text(l10n.stuNoBatch),
                                                ),
                                                for (final Batch b in batches)
                                                  DropdownMenuItem<String>(
                                                    value: b.id,
                                                    child: Text(
                                                      subjectOf(b).isEmpty
                                                          ? b.name
                                                          : '${subjectOf(b)} · ${b.name}',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                              onChanged: (String? v) =>
                                                  choice.setBatch(
                                                      (v == null || v.isEmpty)
                                                          ? null
                                                          : v),
                                            ),
                                          ),
                                        ),
                                        if (chosen != null) ...<Widget>[
                                          const SizedBox(height: 12),
                                          ListenableBuilder(
                                            listenable: model,
                                            builder: (BuildContext context,
                                                    Widget? _) =>
                                                StartMonthFeeFields(
                                              choice: choice,
                                              join: model.admissionDate,
                                              cutoff: cutoff,
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ],
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(_error!,
                                        style: tt.bodyMedium
                                            ?.copyWith(color: tokens.error)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
