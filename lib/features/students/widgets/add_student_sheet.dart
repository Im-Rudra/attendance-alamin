// Search-first "add student to this batch" sheet (UX 2e): type a name or phone;
// existing students are offered first ("এই ব্যাচে যোগ করুন"), so nobody is added
// twice. A new student needs only a name and a guardian phone.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/students/controllers/student_actions.dart';
import 'package:attendance_alamin/features/students/controllers/student_form_model.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/widgets/student_avatar.dart';
import 'package:attendance_alamin/features/students/widgets/student_dialogs.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

Future<String?> openAddStudentSheet(BuildContext context, String batchId) {
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  return showBhorPanel<String>(
    context,
    title: context.l10n.stuAddTitle,
    kind: BhorPanelKind.form,
    expand: true,
    width: 520,
    dirty: dirty,
    builder: (BuildContext ctx) => AddStudentSheet(batchId: batchId, dirty: dirty),
  );
}

/// "০১৭১…৫৬৭" (first three and last three digits).
String maskPhone(AppFormat fmt, String phone) {
  if (phone.length < 7) return fmt.digits(phone);
  return '${fmt.digits(phone.substring(0, 3))}…${fmt.digits(phone.substring(phone.length - 3))}';
}

class AddStudentSheet extends ConsumerStatefulWidget {
  const AddStudentSheet({super.key, required this.batchId, this.dirty});

  /// Written true while a new student's form holds unsaved input (the
  /// hosting panel then asks before closing).
  final ValueNotifier<bool>? dirty;

  final String batchId;

  @override
  ConsumerState<AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends ConsumerState<AddStudentSheet> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode(debugLabel: 'student search');
  StudentFormModel? _model;
  EnrollChoice? _choice;
  final List<StudentFormModel> _retired = <StudentFormModel>[];
  bool _busy = false;
  String? _error;

  Listenable? _changes;

  void _syncDirty() {
    final bool d = _model?.isDirty ?? false;
    final ValueNotifier<bool>? n = widget.dirty;
    if (n != null && n.value != d) n.value = d;
  }

  void _watch(StudentFormModel? m) {
    _changes?.removeListener(_syncDirty);
    _changes = m?.changes;
    _changes?.addListener(_syncDirty);
  }

  @override
  void initState() {
    super.initState();
    focusAfterOpen(this, _queryFocus);
  }

  @override
  void dispose() {
    _changes?.removeListener(_syncDirty);
    _query.dispose();
    _queryFocus.dispose();
    _model?.dispose();
    _choice?.dispose();
    for (final StudentFormModel m in _retired) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _startCreating() async {
    final LocalDate today = ref.read(todayProvider);
    final String q = _query.text.trim();
    final String ascii = AppFormat.toAsciiDigits(q).replaceAll(RegExp(r'[\s\-+]'), '');
    final bool looksLikePhone = RegExp(r'^\d{6,}$').hasMatch(ascii);
    final String roll = await ref.read(studentsRepositoryProvider).nextRoll();
    if (!mounted) return;
    setState(() {
      final StudentFormModel m = StudentFormModel(
        admissionDate: today,
        name: looksLikePhone ? '' : q,
        guardianPhone: looksLikePhone ? ascii : '',
        roll: roll,
      );
      final StudentFormModel? old = _model;
      if (old != null) _retired.add(old);
      _model = m;
      _choice ??= EnrollChoice(batchId: widget.batchId);
      _error = null;
      _watch(m);
    });
  }

  void _stopCreating() {
    setState(() {
      final StudentFormModel? old = _model;
      if (old != null) _retired.add(old);
      _model = null;
      _error = null;
      _watch(null);
    });
    _syncDirty();
  }

  Future<void> _enrollExisting(Student s) async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final LocalDate today = ref.read(todayProvider);
      final int cutoff = await ref.read(stuCutoffProvider.future);
      await ref.read(enrollmentsRepositoryProvider).enroll(
            studentId: s.id,
            batchId: widget.batchId,
            joinDate: today,
            startMonth: DuesEngine.defaultFirstBillableMonth(today, cutoff),
          );
      if (!mounted) return;
      Navigator.of(context).pop(s.id);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(l10n, e);
      });
    }
  }

  Future<void> _saveNew() async {
    final l10n = context.l10n;
    final StudentFormModel model = _model!;
    final EnrollChoice choice = _choice!;
    final StudentDraft? draft = model.validate(l10n);
    final ({bool ok, int? amount}) fee = choice.parseFee(l10n);
    if (draft == null || !fee.ok) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final students = ref.read(studentsRepositoryProvider);
      final List<Student> dups = await findPhoneDuplicates(students, draft);
      if (!mounted) return;
      if (dups.isNotEmpty) {
        final DuplicateChoice? c = await showDuplicateDialog(context,
            existing: dups.first, hasBatch: true);
        if (!mounted) return;
        if (c == null) {
          setState(() => _busy = false);
          return;
        }
        if (c == DuplicateChoice.useExisting) {
          await _enrollExisting(dups.first);
          return;
        }
      }
      final int cutoff = await ref.read(stuCutoffProvider.future);
      final String id = await createStudentAndEnroll(
        students: students,
        enrollments: ref.read(enrollmentsRepositoryProvider),
        draft: draft,
        photo: model.photo,
        batchId: widget.batchId,
        startMonth: choice.startFor(draft.admissionDate, cutoff),
        feeOverride: fee.amount,
      );
      if (!mounted) return;
      Navigator.of(context).pop(id);
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
    final AppFormat fmt = context.fmt;
    final List<Student> roster = ref.watch(stuRosterProvider).value ?? const <Student>[];
    final List<Enrollment> enrollments =
        ref.watch(allEnrollmentsProvider).value ?? const <Enrollment>[];
    final List<Batch> batches = ref.watch(stuBatchesProvider).value ?? const <Batch>[];
    final Map<String, String> subjectNames = <String, String>{
      for (final Subject sub in ref.watch(stuSubjectsProvider).value ?? const <Subject>[]) sub.id: sub.name,
    };
    final String q = _query.text.trim();
    final StudentFormModel? model = _model;
    final EnrollChoice? choice = _choice;
    final LocalDate today = ref.watch(todayProvider);
    final int cutoff = ref.watch(stuCutoffProvider).value ?? 15;

    final Set<String> inThisBatch = <String>{
      for (final Enrollment e in enrollments)
        if (e.batchId == widget.batchId && e.endDate == null) e.studentId,
    };
    String batchesOf(String studentId) {
      final List<String> names = <String>[];
      for (final Enrollment e in enrollments) {
        if (e.studentId != studentId || e.endDate != null) continue;
        for (final Batch b in batches) {
          if (b.id == e.batchId) names.add(batchLabel(l10n, subjectNames[b.subjectId] ?? '', b.name));
        }
      }
      return names.join(' · ');
    }

    final List<Student> matches = <Student>[
      if (q.isNotEmpty && model == null)
        for (final Student s in roster)
          if (s.status == StudentStatus.active && studentMatchesQuery(s, q)) s,
    ].take(6).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (model == null) ...<Widget>[
            BhorTextField(
              key: const ValueKey<String>('stu-add-search'),
              controller: _query,
              focusNode: _queryFocus,
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
              prefix: const Icon(BhorIcons.search),
              label: l10n.stuSearchFirstHint,
            ),
            const SizedBox(height: BhorSpace.s8),
            if (q.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: BhorSpace.s12),
                child: Text(l10n.stuAddSearchHelp, style: th.type.body.copyWith(color: th.colors.text2)),
              ),
            for (final Student s in matches)
              Padding(
                padding: const EdgeInsets.only(bottom: BhorSpace.s8),
                child: BhorCard(
                  padding: const EdgeInsets.all(BhorSpace.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          StudentAvatar(student: s, size: 40),
                          const SizedBox(width: BhorSpace.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: th.type.heading),
                                Text(
                                  <String>[
                                    if (s.callNumber != null) maskPhone(fmt, s.callNumber!),
                                    batchesOf(s.id),
                                  ].where((String t) => t.isNotEmpty).join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: th.type.label.copyWith(color: th.colors.text2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: BhorSpace.s8),
                      if (inThisBatch.contains(s.id))
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Icon(BhorIcons.checkCircleFill, size: 18, color: th.colors.text2),
                            const SizedBox(width: BhorSpace.s8),
                            Text(l10n.stuAlreadyInBatch, style: th.type.label.copyWith(color: th.colors.text2)),
                          ],
                        )
                      else
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: BhorButton(
                            variant: BhorButtonVariant.secondary,
                            label: l10n.stuAddToThisBatch,
                            onPressed: _busy ? null : () => _enrollExisting(s),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (q.isNotEmpty)
              BhorButton(
                key: const ValueKey<String>('stu-add-new'),
                variant: BhorButtonVariant.secondary,
                expand: true,
                icon: BhorIcons.add,
                label: l10n.stuNewStudentNamed(q),
                onPressed: _busy ? null : _startCreating,
              ),
          ] else ...<Widget>[
            Row(
              children: <Widget>[
                BhorIconButton(
                  semanticLabel: l10n.commonBack,
                  icon: BhorIcons.back,
                  onPressed: _busy ? null : _stopCreating,
                ),
                const SizedBox(width: BhorSpace.s8),
                Expanded(child: Text(l10n.stuNewStudent, style: th.type.heading)),
              ],
            ),
            StudentFieldsView(model: model, today: today, autofocusName: true),
            const SizedBox(height: BhorSpace.s8),
            if (choice != null)
              ListenableBuilder(
                listenable: model,
                builder: (BuildContext context, Widget? _) => StartMonthFeeFields(
                  choice: choice,
                  join: model.admissionDate,
                  cutoff: cutoff,
                ),
              ),
            const SizedBox(height: BhorSpace.s16),
            BhorButton(
              key: const ValueKey<String>('stu-add-save'),
              label: l10n.stuSave,
              expand: true,
              onPressed: _busy ? null : _saveNew,
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: BhorSpace.s8),
              child: Semantics(
                liveRegion: true,
                child: Text(_error!, style: th.type.body.copyWith(color: th.colors.danger)),
              ),
            ),
        ],
      ),
    );
  }
}
