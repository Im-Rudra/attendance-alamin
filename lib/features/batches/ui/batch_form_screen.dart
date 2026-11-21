// Batch create / edit form (full screen, root navigator). Subject is picked or
// created inline (never a destination of its own); billing is two radio cards
// in plain words, default = last used; a fee change asks "কোন মাস থেকে?".

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/repositories/batches_repository.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/data/repositories/subjects_repository.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/batches/batches_entry.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/batches/widgets/billing_cards.dart';
import 'package:attendance_alamin/features/batches/widgets/fee_change_sheet.dart';

class BatchFormScreen extends ConsumerStatefulWidget {
  const BatchFormScreen({super.key, this.batchId});

  /// null = create a new batch.
  final String? batchId;

  @override
  ConsumerState<BatchFormScreen> createState() => _BatchFormScreenState();
}

class _BatchFormScreenState extends ConsumerState<BatchFormScreen> {
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _fee = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  BillingType _billing = BillingType.prepaid;
  List<SlotDraft> _slots = const <SlotDraft>[];
  SlotCheckResult _check = const SlotCheckResult();

  Batch? _batch;
  int? _oldFee;
  bool _loaded = false;
  bool _notFound = false;
  bool _seeded = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.batchId != null;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in <TextEditingController>[_subject, _name, _fee]) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _name.dispose();
    _fee.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() => _error = null);
  }

  /// A callback from the slot editor may arrive while it builds.
  void _defer(VoidCallback f) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(f);
      });
    } else {
      setState(f);
    }
  }

  /// Copies the seed into the fields once, after the frame that first saw it.
  void _applySeed(BatchFormSeed seed) {
    if (!mounted) return;
    final Batch? b = seed.batch;
    if (b == null) {
      if (!seed.notFound) {
        _name.text = context.l10n.batchDefaultName(context.fmt.number(seed.batchCount + 1));
      }
    } else {
      _name.text = b.name;
      _notes.text = b.notes ?? '';
      final int? fee = seed.fee;
      _fee.text = fee == null ? '' : context.fmt.digits(fee.toString());
      _subject.text = seed.subjectName;
    }
    setState(() {
      _batch = b;
      _notFound = seed.notFound;
      _billing = seed.billing;
      _oldFee = seed.fee;
      _loaded = true;
    });
  }

  int? _parsedFee() {
    try {
      return Validators.amount(_fee.text);
    } on ValidationException {
      return null;
    }
  }

  String? _feeError() {
    if (_fee.text.trim().isEmpty) return null;
    try {
      Validators.amount(_fee.text);
      return null;
    } on ValidationException catch (e) {
      return errorText(context.l10n, e);
    }
  }

  /// Why save is disabled, or null when it is allowed.
  String? _reason() {
    final l10n = context.l10n;
    if (!_editing && _subject.text.trim().isEmpty) return l10n.batchReasonSubject;
    if (_name.text.trim().isEmpty) return l10n.batchReasonName;
    if (_parsedFee() == null) return l10n.batchReasonFee;
    if (!_editing && _slots.isEmpty) return l10n.batchReasonSlots;
    if (!_editing && !_check.ok) return l10n.batchReasonClash;
    return null;
  }

  void _close() {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.batches);
    }
  }

  Future<void> _save() async {
    if (_saving || _reason() != null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final l10n = context.l10n;
    final GoRouter? router = GoRouter.maybeOf(context);
    try {
      if (_editing) {
        final bool done = await _saveEdit();
        if (!done) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        if (mounted) {
          BhorToast.show(context, message: l10n.batchSavedToast);
          _close();
        }
      } else {
        final String id = await _saveCreate();
        if (!mounted) return;
        BhorToast.show(context, message: l10n.batchCreatedToast);
        if (router != null) {
          router.go(Routes.batch(id));
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String> _saveCreate() async {
    final SubjectsRepository subjects = ref.read(subjectsRepositoryProvider);
    final String subjectText = Validators.name(_subject.text);
    final Subject? existing = await subjects.findByName(subjectText);
    final String subjectId = existing?.id ?? await subjects.create(name: subjectText);
    final LocalDate today = ref.read(todayProvider);
    final String notes = _notes.text.trim();
    return ref.read(batchesRepositoryProvider).create(BatchDraft(
          subjectId: subjectId,
          name: Validators.name(_name.text),
          billingType: _billing,
          monthlyFee: Validators.amount(_fee.text),
          feeFrom: today.yearMonth,
          slots: _slots,
          slotsFrom: today,
          notes: notes.isEmpty ? null : notes,
        ));
  }

  /// False when the teacher backed out of the fee-month sheet.
  Future<bool> _saveEdit() async {
    final Batch batch = _batch!;
    final BatchesRepository repo = ref.read(batchesRepositoryProvider);
    final int newFee = Validators.amount(_fee.text);
    final int? oldFee = _oldFee;
    final LocalDate today = ref.read(todayProvider);
    YearMonth? from;
    if (oldFee != null && newFee != oldFee) {
      // QA-01: a migrated student's past months may carry the fee, so offer
      // months back to the earliest first billable month (at least 24 back).
      final List<Enrollment> enrolled = await ref.read(enrollmentsRepositoryProvider).watchForBatch(batch.id).first;
      if (!mounted) return false;
      YearMonth earliest = today.yearMonth.addMonths(-24);
      for (final Enrollment e in enrolled) {
        if (e.startMonth.isBefore(earliest)) earliest = e.startMonth;
      }
      from = await showFeeChangeSheet(
        context,
        oldFee: oldFee,
        newFee: newFee,
        current: today.yearMonth,
        earliest: earliest,
        previewPartial: (YearMonth m) => repo.previewPartialMonths(batch.id, newFee, m),
      );
      if (from == null) return false;
    } else if (oldFee == null) {
      from = today.yearMonth;
    }
    final String name = Validators.name(_name.text);
    if (name != batch.name) await repo.rename(batch.id, name);
    if (_billing != batch.billingType) await repo.setBillingType(batch.id, _billing);
    final String notes = _notes.text.trim();
    final String? newNotes = notes.isEmpty ? null : notes;
    if (newNotes != batch.notes) await repo.setNotes(batch.id, newNotes);
    if (from != null) await repo.setFee(batch.id, newFee, from);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BhorScaffold(
      header: BhorHeader(
        title: _editing ? l10n.shellTitleBatchEdit : l10n.shellTitleBatchNew,
        onBack: _close,
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final AsyncValue<BatchFormSeed> seed = ref.watch(batchFormSeedProvider(widget.batchId));
    if (!_seeded && seed.hasValue) {
      _seeded = true;
      final BatchFormSeed value = seed.requireValue;
      WidgetsBinding.instance.addPostFrameCallback((_) => _applySeed(value));
    }
    if (_loaded) {
      return _notFound
          ? BhorEmptyState(icon: Icons.search_off, title: l10n.errNotFound)
          : _form(context);
    }
    if (seed.hasError) {
      return BhorEmptyState(
        icon: Icons.error_outline,
        title: l10n.commonLoadingFailed,
        action: BhorButton(
          label: l10n.commonRetry,
          variant: BhorButtonVariant.secondary,
          onPressed: () => ref.invalidate(batchFormSeedProvider(widget.batchId)),
        ),
      );
    }
    return const Center(child: BhorSpinner());
  }

  Widget _form(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData th = context.bhor;
    final double g = WindowClass.of(context).gutter;
    final String? reason = _reason();
    final List<Subject> subjects = ref.watch(batchSubjectsProvider).value ?? const <Subject>[];
    final String typed = _subject.text.trim();
    final bool isNewSubject = !_editing &&
        typed.isNotEmpty &&
        !subjects.any((Subject s) => s.name.trim().toLowerCase() == typed.toLowerCase());
    final SlotEditorBuilder buildSlots = ref.watch(batchSlotEditorBuilderProvider);

    final List<String> suggestions = <String>[
      l10n.batchSuggestMath,
      l10n.batchSuggestEnglish,
      l10n.batchSuggestPhysics,
      l10n.batchSuggestChemistry,
      l10n.batchSuggestBiology,
      l10n.batchSuggestIct,
    ];

    Widget chips(List<String> names) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String n in names)
              BhorChip(
                label: n,
                selected: typed.toLowerCase() == n.toLowerCase(),
                onSelected: (_) => _subject.text = n,
              ),
          ],
        );

    return Column(
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: EdgeInsets.fromLTRB(g, 8, g, 24),
                children: <Widget>[
                  BhorTextField(
                    key: const Key('batch-form-subject'),
                    controller: _subject,
                    enabled: !_editing,
                    textInputAction: TextInputAction.next,
                    label: l10n.batchSubjectLabel,
                    hint: l10n.batchSubjectHint,
                    helper: _editing ? l10n.batchSubjectLocked : null,
                  ),
                  if (!_editing) ...<Widget>[
                    if (isNewSubject)
                      Padding(
                        padding: const EdgeInsets.only(top: BhorSpace.s8),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.add_circle_outline, size: 18, color: th.colors.accent),
                            const SizedBox(width: BhorSpace.s8),
                            Expanded(
                              child: Text(
                                l10n.batchSubjectNew(typed),
                                style: th.type.body.copyWith(color: th.colors.text2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (subjects.isNotEmpty) ...<Widget>[
                      Text(l10n.batchSubjectPick, style: th.type.label.copyWith(color: th.colors.text2)),
                      const SizedBox(height: 4),
                      chips(<String>[for (final Subject s in subjects) s.name]),
                    ] else ...<Widget>[
                      Text(l10n.batchSubjectSuggest, style: th.type.label.copyWith(color: th.colors.text2)),
                      const SizedBox(height: 4),
                      chips(suggestions),
                    ],
                  ],
                  const SizedBox(height: 16),
                  BhorTextField(
                    key: const Key('batch-form-name'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    label: l10n.batchNameLabel,
                  ),
                  const SizedBox(height: 16),
                  if (_editing)
                    BhorCard(
                      padding: EdgeInsets.zero,
                      child: BhorListRow(
                        leading: const Icon(Icons.schedule),
                        title: l10n.batchEditSchedule,
                        trailing: const Icon(Icons.chevron_right),
                        divider: false,
                        onTap: () => context.push(Routes.batchSlots(widget.batchId!)),
                      ),
                    )
                  else ...<Widget>[
                    Semantics(
                      header: true,
                      child: Text(l10n.batchScheduleLabel, style: th.type.heading),
                    ),
                    const SizedBox(height: 8),
                    buildSlots(
                      context,
                      initial: _slots,
                      onChanged: (List<SlotDraft> s) => _defer(() => _slots = s),
                      batchId: null,
                      onCheck: (SlotCheckResult r) => _defer(() => _check = r),
                    ),
                  ],
                  const SizedBox(height: 16),
                  BhorTextField(
                    key: const Key('batch-form-fee'),
                    controller: _fee,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    label: l10n.batchFeeLabel,
                    prefix: Text('৳ ', style: th.type.body.copyWith(color: th.colors.text2)),
                    error: _feeError(),
                    tabular: true,
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(l10n.batchBillingTitle, style: th.type.heading),
                  ),
                  const SizedBox(height: 8),
                  BillingCards(value: _billing, onChanged: (BillingType t) => setState(() => _billing = t)),
                  const SizedBox(height: 16),
                  BhorTextField(
                    controller: _notes,
                    minLines: 1,
                    maxLines: 3,
                    label: l10n.commonNotes,
                  ),
                  if (_editing && _batch != null && !_batch!.archived) ...<Widget>[
                    const SizedBox(height: 16),
                    BhorButton(
                      variant: BhorButtonVariant.secondary,
                      expand: true,
                      onPressed: () async {
                        final bool done = await showArchiveBatchDialog(context, batchId: _batch!.id);
                        if (done && mounted) _close();
                      },
                      icon: Icons.inventory_2_outlined,
                      label: l10n.batchMenuArchive,
                    ),
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: BhorSpace.s16),
                    BatchNotice(text: _error!),
                  ],
                ],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: th.colors.surface,
            border: Border(top: BorderSide(color: th.colors.line)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(g, BhorSpace.s12, g, BhorSpace.s12),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    BhorButton(
                      label: l10n.commonSave,
                      expand: true,
                      onPressed: reason == null && !_saving ? _save : null,
                      disabledReason: reason,
                    ),
                    if (reason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: BhorSpace.s8),
                        child: Text(
                          reason,
                          textAlign: TextAlign.center,
                          style: th.type.meta,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
