// Add / edit a student (full-screen route). A new student can be enrolled in
// one batch or private tuition at once ("Enrol in: Not yet · Batch · Private
// tuition", then a searchable picker of that kind; `initialBatchId` comes from
// the route `extra`); saving runs the duplicate guard (UX 2e).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/batches/widgets/panel_footer.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_form_model.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/widgets/student_dialogs.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

/// Opens the student form in the adaptive panel (expanding sheet on phones,
/// floating side panel on desktop). True when saved, null when dismissed.
/// Closing with unsaved input asks first (`dirty:`).
Future<bool?> showStudentFormPanel(BuildContext context, {String? studentId, String? initialBatchId}) {
  final PanelFooterSlot slot = PanelFooterSlot();
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final l10n = context.l10n;
  return showBhorPanel<bool>(
    context,
    title: studentId == null ? l10n.shellTitleStudentNew : l10n.shellTitleStudentEdit,
    kind: BhorPanelKind.form,
    expand: true,
    footer: slot.build,
    dirty: dirty,
    builder: (BuildContext c) => StudentFormScreen(
      studentId: studentId,
      initialBatchId: initialBatchId,
      embedded: true,
      footerSlot: slot,
      dirty: dirty,
    ),
  );
}

class StudentFormScreen extends ConsumerStatefulWidget {
  const StudentFormScreen({
    super.key,
    this.studentId,
    this.initialBatchId,
    this.embedded = false,
    this.footerSlot,
    this.dirty,
  });

  /// Set by the hosting panel: written true while the form has unsaved input
  /// (the panel then asks before closing). Standalone pages guard themselves.
  final ValueNotifier<bool>? dirty;

  /// Hosted inside [showBhorPanel]: no scaffold; the save button goes to [footerSlot].
  final bool embedded;
  final PanelFooterSlot? footerSlot;

  /// null = add a new student.
  final String? studentId;

  /// Batch to enrol the new student in (passed as route `extra`).
  final String? initialBatchId;

  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

/// "Enrol in" of the add-student form.
enum EnrollKindChoice { none, batch, tuition }

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  StudentFormModel? _model;
  EnrollChoice? _choice;

  /// The teacher's "Enrol in" pick; null = follow the chosen batch (none
  /// until one is chosen, e.g. from the route).
  EnrollKindChoice? _kindPick;
  bool _missing = false;
  bool _busy = false;
  String? _error;

  late final ValueNotifier<bool> _dirty = widget.dirty ?? ValueNotifier<bool>(false);
  Listenable? _modelChanges;
  Listenable? _choiceChanges;
  bool _redirected = false;

  bool get _isNew => widget.studentId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Desktop route entry (`/students/new`, `/students/:id/edit`): the form is
    // a side panel over the Students page, never a page of its own.
    if (!widget.embedded && !_redirected && GoRouter.maybeOf(context) != null && context.bhorIsWide) {
      _redirected = true;
      _redirectToPanel();
    }
  }

  void _redirectToPanel() {
    final String? id = widget.studentId;
    final String? batchId = widget.initialBatchId;
    final NavigatorState root = Navigator.of(context, rootNavigator: true);
    final GoRouter router = GoRouter.of(context);
    // Never navigate during a build: leave this page for the Students page
    // (or the student's profile), then open the panel over it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go(id == null ? Routes.students : Routes.student(id));
      WidgetsBinding.instance.endOfFrame.then((_) => WidgetsBinding.instance.endOfFrame).then((_) {
        final BuildContext? host = root.overlay?.context;
        if (host == null || !host.mounted) return;
        showStudentFormPanel(host, studentId: id, initialBatchId: batchId);
      });
    });
  }

  void _attach(StudentFormModel m, EnrollChoice? c) {
    final Listenable mc = m.changes;
    mc.addListener(_syncDirty);
    _modelChanges = mc;
    final Listenable? cc = c?.changes;
    cc?.addListener(_syncDirty);
    _choiceChanges = cc;
  }

  void _syncDirty() {
    final bool d = (_model?.isDirty ?? false) || (_isNew && (_choice?.isDirty ?? false));
    if (_dirty.value != d) _dirty.value = d;
  }

  @override
  void dispose() {
    _modelChanges?.removeListener(_syncDirty);
    _choiceChanges?.removeListener(_syncDirty);
    _model?.dispose();
    _choice?.dispose();
    if (widget.dirty == null) _dirty.dispose();
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
        _attach(_model!, _choice);
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
    _attach(m, null);
  }

  /// Success: the panel's circle-check moment when embedded, else toast + close.
  Future<void> _done(String message, {String fallback = Routes.students}) async {
    _dirty.value = false;
    if (widget.embedded) {
      await showBhorSuccess<bool>(context, result: true, toast: message);
      return;
    }
    BhorToast.show(context, message: message);
    stuClose(context, fallback: fallback);
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
    try {
      final students = ref.read(studentsRepositoryProvider);
      final String? editId = widget.studentId;
      if (editId != null) {
        await students.update(editId, draft);
        if (model.photoChanged) {
          await students.setPhoto(editId, model.photo);
          if (mounted) ref.invalidate(stuPhotoProvider((id: editId, has: true)));
        }
        if (!mounted) return;
        await _done(l10n.stuSaved(draft.name), fallback: Routes.student(editId));
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
          if (batchId != null && choice != null) {
            final int cutoffDay = await ref.read(stuCutoffProvider.future);
            final LocalDate join = choice.joinFor(draft.admissionDate);
            await ref.read(enrollmentsRepositoryProvider).enroll(
                  studentId: existing.id,
                  batchId: batchId,
                  joinDate: join,
                  startMonth: choice.startFor(join, cutoffDay),
                  feeOverride: fee.amount,
                );
            if (!mounted) return;
            await _done(l10n.stuAddedToBatch(existing.name));
          } else {
            if (!mounted) return;
            stuGo(context, Routes.student(existing.id));
            if (widget.embedded) Navigator.of(context).maybePop();
          }
          return;
        }
      }
      final int startCutoff = await ref.read(stuCutoffProvider.future);
      final LocalDate? join = choice?.joinFor(draft.admissionDate);
      await createStudentAndEnroll(
        students: students,
        enrollments: ref.read(enrollmentsRepositoryProvider),
        draft: draft,
        photo: model.photo,
        batchId: batchId,
        startMonth: (choice == null || join == null) ? null : choice.startFor(join, startCutoff),
        feeOverride: fee.amount,
        joinDate: join,
      );
      if (!mounted) return;
      await _done(l10n.stuSaved(draft.name));
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
    // The panel opens over the Students page (see didChangeDependencies).
    if (_redirected) return const SizedBox.shrink();
    final l10n = context.l10n;
    final BhorThemeData th = context.bhor;
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

    EnrollKindChoice kindOf(String? batchId) {
      if (_kindPick != null) return _kindPick!;
      for (final Batch b in batches) {
        if (b.id == batchId) return b.isTuition ? EnrollKindChoice.tuition : EnrollKindChoice.batch;
      }
      return EnrollKindChoice.none;
    }

    final Widget form = model == null ? const SizedBox.shrink() : Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudentFieldsView(
          model: model,
          today: today,
          autofocusName: _isNew,
          moreExpanded: !_isNew,
        ),
        if (_isNew && choice != null) ...<Widget>[
          const SizedBox(height: BhorSpace.s16),
          Text(l10n.stuEnrollIn, style: th.type.heading),
          const SizedBox(height: BhorSpace.s8),
          ListenableBuilder(
            listenable: choice,
            builder: (BuildContext context, Widget? _) {
              final EnrollKindChoice kind = kindOf(choice.batchId);
              final List<Batch> ofKind = <Batch>[
                for (final Batch b in batches)
                  if (b.isTuition == (kind == EnrollKindChoice.tuition)) b,
              ];
              final String? chosen =
                  ofKind.any((Batch b) => b.id == choice.batchId) ? choice.batchId : null;
              void pickKind(EnrollKindChoice k) {
                // A batch of the other kind (or "Not yet") is no longer chosen.
                final bool keep = k != EnrollKindChoice.none &&
                    batches.any((Batch b) =>
                        b.id == choice.batchId && b.isTuition == (k == EnrollKindChoice.tuition));
                setState(() => _kindPick = k);
                if (!keep && choice.batchId != null) choice.setBatch(null);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    key: const ValueKey<String>('stu-form-enroll-kind'),
                    spacing: BhorSpace.s8,
                    runSpacing: BhorSpace.s8,
                    children: <Widget>[
                      for (final (EnrollKindChoice k, String label) in <(EnrollKindChoice, String)>[
                        (EnrollKindChoice.none, l10n.stuEnrollKindNone),
                        (EnrollKindChoice.batch, l10n.stuEnrollKindBatch),
                        (EnrollKindChoice.tuition, l10n.stuEnrollKindTuition),
                      ])
                        BhorChip(
                          key: ValueKey<String>('stu-enroll-kind-${k.name}'),
                          label: label,
                          selected: kind == k,
                          onSelected: (_) => pickKind(k),
                        ),
                    ],
                  ),
                  if (kind != EnrollKindChoice.none) ...<Widget>[
                    const SizedBox(height: BhorSpace.s12),
                    if (ofKind.isEmpty)
                      Text(
                        kind == EnrollKindChoice.tuition ? l10n.stuNoTuitionsYet : l10n.stuNoBatchesYet,
                        style: th.type.body.copyWith(color: th.colors.text2),
                      )
                    else
                      BhorSelect<String>(
                        key: const ValueKey<String>('stu-form-batch'),
                        label: kind == EnrollKindChoice.tuition ? l10n.stuPickTuition : l10n.stuBatchOptional,
                        hint: l10n.stuPickHint,
                        value: chosen,
                        options: <BhorOption<String>>[
                          for (final Batch b in ofKind)
                            BhorOption<String>(
                              b.id,
                              subjectOf(b).isEmpty ? b.name : '${subjectOf(b)} · ${b.name}',
                            ),
                        ],
                        onChanged: choice.setBatch,
                      ),
                  ],
                  if (chosen != null) ...<Widget>[
                    const SizedBox(height: BhorSpace.s12),
                    ListenableBuilder(
                      listenable: model,
                      builder: (BuildContext context, Widget? _) => StartMonthFeeFields(
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
            padding: const EdgeInsets.only(top: BhorSpace.s12),
            child: Semantics(
              liveRegion: true,
              child: Text(_error!, style: th.type.body.copyWith(color: th.colors.danger)),
            ),
          ),
      ],
    );
    final Widget saveButton = BhorButton(
      label: l10n.stuSave,
      expand: true,
      onPressed: _busy ? null : _save,
    );

    if (widget.embedded) {
      if (_missing || model == null) {
        return Padding(
          padding: const EdgeInsets.all(BhorSpace.s32),
          child: _missing
              ? BhorEmptyState(icon: BhorIcons.leftStudents, title: l10n.stuNotFound)
              : const Center(child: BhorSpinner()),
        );
      }
      widget.footerSlot?.publish(saveButton, alive: () => mounted);
      return Padding(
        padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s4, BhorSpace.s16, BhorSpace.s16),
        child: form,
      );
    }

    return BhorDirtyScope(
      dirty: _dirty,
      child: BhorScaffold(
      header: BhorHeader(
        title: _isNew ? l10n.shellTitleStudentNew : l10n.shellTitleStudentEdit,
        onBack: () => stuClose(context),
      ),
      bottomNav: model == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: th.colors.surface,
                border: Border(top: BorderSide(color: th.colors.line)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(gutter, BhorSpace.s12, gutter, BhorSpace.s12),
                  child: saveButton,
                ),
              ),
            ),
      body: _missing
          ? BhorEmptyState(icon: BhorIcons.leftStudents, title: l10n.stuNotFound)
          : model == null
              ? const Center(child: BhorSpinner())
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, BhorSpace.s8, gutter, gutter),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: BhorCard(
                        padding: const EdgeInsets.all(BhorSpace.s16),
                        child: form,
                      ),
                    ),
                  ),
                ),
      ),
    );
  }
}
