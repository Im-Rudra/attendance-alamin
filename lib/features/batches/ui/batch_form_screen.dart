// Batch create / edit form (a side panel on desktop, a sheet on phones; the
// full-screen route stays for deep links). Subject is picked or
// created inline (never a destination of its own); billing is two radio cards
// in plain words, default = last used; a fee change asks "কোন মাস থেকে?".

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/widgets/digits_formatter.dart';
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
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/batches/widgets/billing_cards.dart';
import 'package:attendance_alamin/features/batches/widgets/fee_change_sheet.dart';
import 'package:attendance_alamin/features/batches/widgets/panel_footer.dart';
import 'package:attendance_alamin/features/schedule/ui/slot_editor_screen.dart';

/// Opens the batch form in the adaptive panel (bottom sheet on phones, floating
/// side panel on desktop). Returns the new batch id (String) after a create,
/// true after an edit, null when dismissed.
Future<Object?> showBatchFormPanel(BuildContext context, {String? batchId}) {
  final PanelFooterSlot slot = PanelFooterSlot();
  final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);
  final l10n = context.l10n;
  return showBhorPanel<Object>(
    context,
    title: batchId == null ? l10n.shellTitleBatchNew : l10n.shellTitleBatchEdit,
    kind: BhorPanelKind.form,
    expand: true,
    footer: slot.build,
    dirty: dirty,
    builder: (BuildContext c) =>
        BatchFormScreen(batchId: batchId, embedded: true, footerSlot: slot, dirty: dirty),
  );
}

class BatchFormScreen extends ConsumerStatefulWidget {
  const BatchFormScreen({super.key, this.batchId, this.embedded = false, this.footerSlot, this.dirty});

  /// null = create a new batch.
  final String? batchId;

  /// Hosted inside [showBhorPanel]: no scaffold; the save bar goes to [footerSlot].
  final bool embedded;
  final PanelFooterSlot? footerSlot;

  /// Set true once the user changed something, so closing the panel asks
  /// before discarding (showBhorPanel's `dirty:`).
  final ValueNotifier<bool>? dirty;

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

  /// Values the form started from (create: the defaults), to tell a change.
  String _seedName = '';
  String _seedNotes = '';
  String _seedFee = '';
  BillingType _seedBilling = BillingType.prepaid;
  late final ValueNotifier<bool> _dirty = widget.dirty ?? ValueNotifier<bool>(false);

  bool get _editing => widget.batchId != null;

  /// True once anything differs from where the form started.
  bool get _isDirty {
    if (!_loaded) return false;
    if (_name.text != _seedName || _notes.text != _seedNotes || _fee.text != _seedFee) return true;
    if (_billing != _seedBilling) return true;
    if (!_editing && (_subject.text.trim().isNotEmpty || _slots.isNotEmpty)) return true;
    return false;
  }

  void _syncDirty() {
    final bool d = _isDirty;
    if (_dirty.value == d) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dirty.value != d) _dirty.value = d;
    });
  }

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in <TextEditingController>[_subject, _name, _fee, _notes]) {
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _name.dispose();
    _fee.dispose();
    _notes.dispose();
    if (widget.dirty == null) _dirty.dispose();
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
      _seedName = _name.text;
      _seedNotes = _notes.text;
      _seedFee = _fee.text;
      _seedBilling = seed.billing;
      _loaded = true;
    });
  }

  /// Blank means "no fee yet" = 0; null when the text is not an amount.
  int? _parsedFee() {
    if (_fee.text.trim().isEmpty) return 0;
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
    // Editing: Save stays off until something changed (review B9).
    if (_editing && !_isDirty) return l10n.schedReasonNoChange;
    if (!_editing && _subject.text.trim().isEmpty) return l10n.batchReasonSubject;
    if (_name.text.trim().isEmpty) return l10n.batchReasonName;
    if (_parsedFee() == null) return l10n.batchReasonFee;
    if (!_editing && _slots.isEmpty) return l10n.batchReasonSlots;
    if (!_editing && !_check.ok) return l10n.batchReasonClash;
    return null;
  }

  void _close() {
    if (widget.embedded) {
      Navigator.of(context).maybePop();
      return;
    }
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
          if (widget.embedded) {
            await showBhorSuccess<Object>(context, result: true, toast: l10n.batchSavedToast);
            return;
          }
          BhorToast.show(context, message: l10n.batchSavedToast);
          _close();
        }
      } else {
        final String id = await _saveCreate();
        if (!mounted) return;
        if (widget.embedded) {
          await showBhorSuccess<Object>(context, result: id, toast: l10n.batchCreatedToast);
          return;
        }
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
          monthlyFee: _parsedFee() ?? 0,
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
    final int newFee = _parsedFee() ?? 0;
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
    if (widget.embedded) return _body(context);
    return BhorDirtyScope(
      dirty: _dirty,
      closeOnEscape: true,
      child: BhorScaffold(
        header: BhorHeader(
          title: _editing ? l10n.shellTitleBatchEdit : l10n.shellTitleBatchNew,
          onBack: _close,
        ),
        body: _body(context),
      ),
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
          ? BhorEmptyState(icon: BhorIcons.search, title: l10n.errNotFound)
          : _form(context);
    }
    if (seed.hasError) {
      return BhorEmptyState(
        icon: BhorIcons.warning,
        title: l10n.commonLoadingFailed,
        action: BhorButton(
          label: l10n.commonRetry,
          variant: BhorButtonVariant.secondary,
          onPressed: () => ref.invalidate(batchFormSeedProvider(widget.batchId)),
        ),
      );
    }
    return const Padding(padding: EdgeInsets.all(BhorSpace.s32), child: Center(child: BhorSpinner()));
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
    _syncDirty();

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

    final List<Widget> items = <Widget>[
                  BhorTextField(
                    key: const Key('batch-form-subject'),
                    controller: _subject,
                    readOnly: _editing,
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
                            Icon(BhorIcons.addCircle, size: 18, color: th.colors.accent),
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
                        leading: const Icon(BhorIcons.clock),
                        title: l10n.batchEditSchedule,
                        trailing: const Icon(BhorIcons.chevronRight),
                        divider: false,
                        onTap: () => widget.embedded
                            ? showSlotEditorPanel(context, batchId: widget.batchId!)
                            : context.push(Routes.batchSlots(widget.batchId!)),
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
                    inputFormatters: <TextInputFormatter>[DigitsFormatter(context.fmt)],
                    textInputAction: TextInputAction.next,
                    label: l10n.batchFeeLabel,
                    prefix: Text('৳ ', style: th.type.body.copyWith(color: th.colors.text2)),
                    error: _feeError(),
                    helper: _feeError() == null ? l10n.batchFeeBlankHelp : null,
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
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: BhorSpace.s16),
                    BatchNotice(text: _error!),
                  ],
    ];
                final Widget saveBar = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    BhorButton(
                      label: l10n.commonSave,
                      expand: true,
                      loading: _saving,
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
                );

    if (widget.embedded) {
      widget.footerSlot?.publish(saveBar, alive: () => mounted);
      return Padding(
        padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s4, BhorSpace.s16, BhorSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        ),
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: EdgeInsets.fromLTRB(g, 8, g, 24),
                children: items,
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
                child: saveBar,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
