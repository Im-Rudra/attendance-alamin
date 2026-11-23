// "অন্য ব্যাচে ভর্তি" (UX 2e): a batch picker grouped by subject (the student's
// current batches are left out), the first billable month and an optional fee
// override. With private tuitions around, "Batch · Private tuition" chips pick
// the kind (item 1); a long list gets a filter field.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/app/providers/attendance_providers.dart';
import 'package:attendance_alamin/features/students/controllers/student_form_model.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/widgets/student_fields.dart';

Future<bool> openEnrollSheet(BuildContext context, String studentId) async {
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final bool? done = await showBhorPanel<bool>(
    context,
    title: context.l10n.stuEnrollTitle,
    kind: BhorPanelKind.form,
    dirty: dirty,
    builder: (BuildContext ctx) => EnrollSheet(studentId: studentId, dirty: dirty),
  );
  return done ?? false;
}

class EnrollSheet extends ConsumerStatefulWidget {
  const EnrollSheet({super.key, required this.studentId, this.dirty});

  /// Written true once a batch is picked (the panel then asks before closing).
  final ValueNotifier<bool>? dirty;

  final String studentId;

  @override
  ConsumerState<EnrollSheet> createState() => _EnrollSheetState();
}

class _EnrollSheetState extends ConsumerState<EnrollSheet> {
  final EnrollChoice _choice = EnrollChoice();
  final TextEditingController _query = TextEditingController();
  BatchKind _kind = BatchKind.batch;
  bool _busy = false;
  String? _error;

  void _syncDirty() {
    final ValueNotifier<bool>? n = widget.dirty;
    if (n != null && n.value != _choice.isDirty) n.value = _choice.isDirty;
  }

  @override
  void initState() {
    super.initState();
    _choice.changes.addListener(_syncDirty);
  }

  @override
  void dispose() {
    _choice.dispose();
    _query.dispose();
    super.dispose();
  }

  void _setKind(BatchKind k) {
    if (k == _kind) return;
    setState(() {
      _kind = k;
      _query.clear();
    });
    _choice.setBatch(null);
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
    final LocalDate join = _choice.joinFor(today);
    try {
      await ref.read(enrollmentsRepositoryProvider).enroll(
            studentId: widget.studentId,
            batchId: batchId,
            joinDate: join,
            startMonth: _choice.startFor(join, cutoff),
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
    final List<Batch> live = <Batch>[
      for (final Batch b in batches)
        if (!b.archived) b,
    ];
    // Only batches the student is NOT in.
    final List<Batch> openAll = <Batch>[
      for (final Batch b in live)
        if (!enrolled.contains(b.id)) b,
    ]..sort((Batch x, Batch y) => x.sortOrder.compareTo(y.sortOrder));
    final bool inEveryBatch = live.isNotEmpty && openAll.isEmpty;
    final bool hasTuitions = openAll.any((Batch b) => b.isTuition);
    final bool hasBatches = openAll.any((Batch b) => !b.isTuition);
    // Only tuitions left: show them without making the teacher switch.
    final BatchKind kind = hasTuitions && !hasBatches ? BatchKind.tuition : _kind;
    final List<Batch> ofKind = <Batch>[
      for (final Batch b in openAll)
        if (b.kind == kind) b,
    ];
    final bool searchable = ofKind.length > kBhorSelectSearchAbove;
    final String q = bhorSearchNorm(_query.text);
    final List<Batch> open = <Batch>[
      for (final Batch b in ofKind)
        if (q.isEmpty || bhorSearchNorm(b.name).contains(q)) b,
    ];

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
          groups.add(Padding(
            padding: const EdgeInsets.only(bottom: BhorSpace.s8),
            child: BhorRadioCard<String>(
              value: bt.id,
              groupValue: _choice.batchId,
              onChanged: _choice.setBatch,
              title: bt.name,
            ),
          ));
        }
      }

      if (kind == BatchKind.tuition) {
        // Tuitions are one list by name (their subject is optional).
        addGroup(l10n.stuEnrollKindTuition, open);
        return groups;
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
                if (hasTuitions && hasBatches) ...<Widget>[
                  const SizedBox(height: BhorSpace.s12),
                  Wrap(
                    spacing: BhorSpace.s8,
                    runSpacing: BhorSpace.s8,
                    children: <Widget>[
                      BhorChip(
                        key: const ValueKey<String>('stu-enroll-kind-batch'),
                        label: l10n.stuEnrollKindBatch,
                        selected: kind == BatchKind.batch,
                        onSelected: (_) => _setKind(BatchKind.batch),
                      ),
                      BhorChip(
                        key: const ValueKey<String>('stu-enroll-kind-tuition'),
                        label: l10n.stuEnrollKindTuition,
                        selected: kind == BatchKind.tuition,
                        onSelected: (_) => _setKind(BatchKind.tuition),
                      ),
                    ],
                  ),
                ],
                if (searchable) ...<Widget>[
                  const SizedBox(height: BhorSpace.s12),
                  BhorTextField(
                    key: const ValueKey<String>('stu-enroll-search'),
                    controller: _query,
                    hint: l10n.stuEnrollSearch,
                    prefix: const Icon(BhorIcons.search),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                if (groups.isEmpty && searchable)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: BhorSpace.s12),
                    child: Text(
                      context.l10n.dsNoMatch,
                      style: th.type.body.copyWith(color: th.colors.text2),
                    ),
                  )
                else if (groups.isEmpty)
                  BhorEmptyState(
                    key: const ValueKey<String>('stu-enroll-empty'),
                    icon: BhorIcons.batches,
                    size: BhorEmptySize.compact,
                    title: inEveryBatch ? l10n.stuEnrollAllJoinedTitle : l10n.stuNoBatchesToJoin,
                    message: inEveryBatch ? l10n.stuEnrollAllJoinedHint : null,
                    action: BhorButton(
                      key: const ValueKey<String>('stu-enroll-new-batch'),
                      icon: BhorIcons.add,
                      label: l10n.batchNew,
                      onPressed: () {
                        final GoRouter? router = GoRouter.maybeOf(context);
                        Navigator.of(context).pop(false);
                        router?.go(Routes.batchNew);
                      },
                    ),
                  ),
                ...groups,
                if (groups.isNotEmpty) ...<Widget>[
                  const SizedBox(height: BhorSpace.s16),
                  if (_choice.batchId != null) StartMonthFeeFields(choice: _choice, join: today, cutoff: cutoff),
                  const SizedBox(height: BhorSpace.s16),
                  BhorButton(
                    key: const ValueKey<String>('stu-enroll-confirm'),
                    label: l10n.stuEnrollConfirm,
                    expand: true,
                    onPressed: (_busy || _choice.batchId == null) ? null : () => _enroll(today, cutoff),
                  ),
                ],
                if (groups.isNotEmpty && _choice.batchId == null)
                  Padding(
                    padding: const EdgeInsets.only(top: BhorSpace.s8),
                    child: Text(
                      kind == BatchKind.tuition ? l10n.stuPickTuitionFirst : l10n.stuPickBatchFirst,
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
