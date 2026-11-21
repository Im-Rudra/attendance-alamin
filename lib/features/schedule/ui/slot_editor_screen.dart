// SlotEditorScreen (route /batches/:batchId/slots, root navigator): the weekly
// schedule of one batch. One column on phones; on wide windows the editor sits
// beside a live preview (sentence + the seven-day overview), so no pane is
// ever a lonely card in a sea of space. Save is blocked, with the reason under
// the button, until the live check is clear; saving asks "কবে থেকে নতুন সময়?".

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/schedule/controllers/schedule_tab_providers.dart';
import 'package:attendance_alamin/features/schedule/controllers/slot_editor_controller.dart';
import 'package:attendance_alamin/features/schedule/widgets/effective_from_sheet.dart';
import 'package:attendance_alamin/features/schedule/widgets/slot_clash_card.dart';
import 'package:attendance_alamin/features/schedule/widgets/slot_editor_body.dart';
import 'package:attendance_alamin/features/schedule/widgets/week_overview.dart';

class SlotEditorScreen extends ConsumerStatefulWidget {
  const SlotEditorScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<SlotEditorScreen> createState() => _SlotEditorScreenState();
}

class _SlotEditorScreenState extends ConsumerState<SlotEditorScreen> {
  SlotEditorController? _controller;
  bool _saving = false;
  bool _leaving = false;

  /// A clash reported by the repository at save time (the chosen start date
  /// can reach further than the live check, which runs from today).
  SlotCheckResult? _saveClash;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  SlotEditorController _ensureController(BatchSchedule schedule) {
    final SlotEditorController? existing = _controller;
    if (existing != null) return existing;
    final repo = ref.read(scheduleRepositoryProvider);
    final LocalDate today = ref.read(todayProvider);
    final SlotEditorController c = SlotEditorController(
      initial: currentSlotDrafts(schedule, today),
      checker: (List<SlotDraft> slots) =>
          repo.checkSlots(widget.batchId, slots, from: today),
    )..addListener(_onEdited);
    _controller = c;
    c.start();
    return c;
  }

  void _onEdited() {
    if (_saveClash != null && mounted) setState(() => _saveClash = null);
  }

  void _close() {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.batch(widget.batchId));
    }
  }

  Future<void> _confirmLeave() async {
    final bool discard = await showBhorConfirm(
      context,
      title: context.l10n.schedDiscardTitle,
      message: context.l10n.schedDiscardBody,
      confirmLabel: context.l10n.schedDiscardConfirm,
      destructive: true,
    );
    if (!discard || !mounted) return;
    setState(() => _leaving = true);
    _close();
  }

  Future<void> _save(SlotEditorController c) async {
    final LocalDate today = ref.read(todayProvider);
    final LocalDate? from = await askEffectiveFrom(context, today: today);
    if (from == null || !mounted) return;
    setState(() {
      _saving = true;
      _saveClash = null;
    });
    final l10n = context.l10n;
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .replaceSlots(widget.batchId, c.slots, from: from);
      if (!mounted) return;
      setState(() => _leaving = true);
      BhorToast.show(context, message: l10n.schedSaved);
      _close();
    } on ScheduleClashException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveClash = e.result;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      BhorToast.show(context, message: errorText(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AsyncValue<List<BatchSchedule>> async = ref.watch(schedulesProvider);
    BatchSchedule? schedule;
    for (final BatchSchedule s in async.value ?? const <BatchSchedule>[]) {
      if (s.batch.id == widget.batchId) schedule = s;
    }

    if (schedule == null) {
      // Loading, or no such batch: the shell's plain chrome.
      return BhorScaffold(
        header: BhorHeader(title: l10n.shellTitleSlotEditor, onBack: _close),
        body: async.isLoading
            ? const Center(child: BhorSpinner())
            : BhorEmptyState(icon: Icons.schedule, title: l10n.errNotFound),
      );
    }

    final BatchSchedule found = schedule;
    final SlotEditorController c = _ensureController(found);
    final double gutter = WindowClass.of(context).gutter;
    final bool wide = WindowClass.of(context).isWide;
    final bool archived = found.batch.archived;
    final int weekStart = ref.watch(weekStartProvider).value ?? 6;

    return ListenableBuilder(
      listenable: c,
      builder: (BuildContext context, _) {
        final SlotBlocker blocker = archived
            ? SlotBlocker.noChange
            : c.blocker(requireChange: true);
        final bool canSave = blocker == SlotBlocker.none && !_saving && !archived;
        final String? reason = switch (blocker) {
          _ when archived => l10n.schedArchivedReadOnly,
          SlotBlocker.none => null,
          SlotBlocker.noDays => l10n.schedReasonNoDays,
          SlotBlocker.badTime => l10n.schedReasonBadTime,
          SlotBlocker.checking => l10n.schedReasonChecking,
          SlotBlocker.clash => l10n.schedReasonFixClash,
          SlotBlocker.noChange => l10n.schedReasonNoChange,
        };

        final Widget title = Padding(
          padding: const EdgeInsets.only(bottom: BhorSpace.s12),
          child: Text(
            '${found.subjectName} · ${found.batch.name}',
            style: context.bhor.type.heading,
          ),
        );
        final SlotCheckResult? saveClash = _saveClash;
        final Widget saveClashCard = saveClash == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SlotClashCard(result: saveClash, ownBatchId: widget.batchId),
              );

        final Widget editor = IgnorePointer(
          ignoring: archived,
          child: Opacity(
            opacity: archived ? 0.6 : 1,
            child: SlotEditorBody(
              controller: c,
              ownBatchId: widget.batchId,
              showSentence: !wide,
            ),
          ),
        );

        final Widget bar = DecoratedBox(
          decoration: BoxDecoration(
            color: context.bhor.colors.surface,
            border: Border(top: BorderSide(color: context.bhor.colors.line)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, BhorSpace.s12, gutter, BhorSpace.s12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                BhorButton(
                  label: l10n.commonSave,
                  expand: true,
                  loading: _saving,
                  onPressed: canSave ? () => _save(c) : null,
                  disabledReason: reason,
                ),
                if (reason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: BhorSpace.s8),
                    child: Text(reason, textAlign: TextAlign.center, style: context.bhor.type.meta),
                  ),
              ],
            ),
          ),
        );

        final Widget body;
        if (wide) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(gutter, 4, gutter / 2, gutter),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[title, editor, saveClashCard],
                        ),
                      ),
                    ),
                    bar,
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter / 2, 4, gutter, gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (!c.isEmpty) SlotSentenceCard(slots: c.slots, weekStart: weekStart),
                      if (!c.isEmpty) const SizedBox(height: 12),
                      WeekOverview(slots: c.slots, weekStart: weekStart),
                    ],
                  ),
                ),
              ),
            ],
          );
        } else {
          body = SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, 4, gutter, gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[title, editor, saveClashCard],
            ),
          );
        }

        return PopScope(
          canPop: _leaving || !c.changed,
          onPopInvokedWithResult: (bool didPop, Object? _) {
            if (!didPop) _confirmLeave();
          },
          child: BhorScaffold(
            header: BhorHeader(title: l10n.shellTitleSlotEditor, onBack: _close),
            body: wide
                ? body
                : Column(
                    children: <Widget>[
                      Expanded(child: body),
                      bar,
                    ],
                  ),
          ),
        );
      },
    );
  }
}
