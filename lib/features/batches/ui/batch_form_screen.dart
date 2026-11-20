// Batch create / edit form (full screen, root navigator). Subject is picked or
// created inline (never a destination of its own); billing is two radio cards
// in plain words, default = last used; a fee change asks "কোন মাস থেকে?".

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/data/repositories/batches_repository.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/data/repositories/subjects_repository.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/subject.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/batches/batches_entry.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';
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
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    final GoRouter? router = GoRouter.maybeOf(context);
    try {
      if (_editing) {
        final bool done = await _saveEdit();
        if (!done) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        messenger?.showSnackBar(SnackBar(content: Text(l10n.batchSavedToast)));
        if (mounted) _close();
      } else {
        final String id = await _saveCreate();
        messenger?.showSnackBar(SnackBar(content: Text(l10n.batchCreatedToast)));
        if (!mounted) return;
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
      from = await showFeeChangeSheet(
        context,
        oldFee: oldFee,
        newFee: newFee,
        current: today.yearMonth,
        earliest: batch.createdOn.yearMonth,
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonClose,
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
        title: Semantics(
          header: true,
          child: Text(_editing ? l10n.shellTitleBatchEdit : l10n.shellTitleBatchNew),
        ),
      ),
      body: SafeArea(top: false, child: _body(context)),
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
          ? EmptyState(icon: Icons.search_off, message: l10n.errNotFound)
          : _form(context);
    }
    if (seed.hasError) {
      return EmptyState(
        icon: Icons.error_outline,
        message: l10n.commonLoadingFailed,
        actionLabel: l10n.commonRetry,
        onAction: () => ref.invalidate(batchFormSeedProvider(widget.batchId)),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _form(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
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
              ChoiceChip(
                label: Text(n),
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
                  TextField(
                    key: const Key('batch-form-subject'),
                    controller: _subject,
                    enabled: !_editing,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.batchSubjectLabel,
                      hintText: l10n.batchSubjectHint,
                      helperText: _editing ? l10n.batchSubjectLocked : null,
                    ),
                  ),
                  if (!_editing) ...<Widget>[
                    if (isNewSubject)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.add_circle_outline, size: 18, color: tokens.accent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.batchSubjectNew(typed),
                                style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (subjects.isNotEmpty) ...<Widget>[
                      Text(l10n.batchSubjectPick, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
                      const SizedBox(height: 4),
                      chips(<String>[for (final Subject s in subjects) s.name]),
                    ] else ...<Widget>[
                      Text(l10n.batchSubjectSuggest, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
                      const SizedBox(height: 4),
                      chips(suggestions),
                    ],
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('batch-form-name'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l10n.batchNameLabel),
                  ),
                  const SizedBox(height: 16),
                  if (_editing)
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        minVerticalPadding: 12,
                        leading: const Icon(Icons.schedule),
                        title: Text(l10n.batchEditSchedule),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(Routes.batchSlots(widget.batchId!)),
                      ),
                    )
                  else ...<Widget>[
                    Semantics(
                      header: true,
                      child: Text(l10n.batchScheduleLabel, style: tt.titleMedium?.copyWith(color: tokens.textPrimary)),
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
                  TextField(
                    key: const Key('batch-form-fee'),
                    controller: _fee,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.batchFeeLabel,
                      prefixText: '৳ ',
                      errorText: _feeError(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(l10n.batchBillingTitle, style: tt.titleMedium?.copyWith(color: tokens.textPrimary)),
                  ),
                  const SizedBox(height: 8),
                  BillingCards(value: _billing, onChanged: (BillingType t) => setState(() => _billing = t)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notes,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: l10n.commonNotes),
                  ),
                  if (_editing && _batch != null && !_batch!.archived) ...<Widget>[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final bool done = await showArchiveBatchDialog(context, batchId: _batch!.id);
                        if (done && mounted) _close();
                      },
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text(l10n.batchMenuArchive),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      container: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.errorContainer,
                          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
                          border: Border.all(color: tokens.errorContainerBorder),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.error_outline, color: tokens.onErrorContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: tt.bodyLarge?.copyWith(color: tokens.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        StickyActionBar(
          label: l10n.commonSave,
          onPressed: reason == null && !_saving ? _save : null,
          disabledReason: reason,
        ),
      ],
    );
  }
}
