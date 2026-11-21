// Batch detail › সময়সূচি tab: the weekly times at a glance, the class-reminder
// row (UX 2h) and the button into the slot editor. Two columns when the pane
// is wide, so a desktop detail pane is filled, not stretched.

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
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/schedule/controllers/schedule_tab_providers.dart';
import 'package:attendance_alamin/features/schedule/widgets/reminder_lead_sheet.dart';
import 'package:attendance_alamin/features/schedule/widgets/slot_editor_body.dart';
import 'package:attendance_alamin/features/schedule/widgets/week_overview.dart';

class BatchScheduleTab extends StatelessWidget {
  const BatchScheduleTab({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) =>
            _body(context, ref),
      );

  Widget _body(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<List<BatchSchedule>> async = ref.watch(schedulesProvider);
    return async.when(
      loading: () => const Center(child: BhorSpinner()),
      error: (Object e, StackTrace _) => BhorEmptyState(
        icon: Icons.error_outline,
        title: errorText(l10n, e),
      ),
      data: (List<BatchSchedule> all) {
        BatchSchedule? mine;
        for (final BatchSchedule s in all) {
          if (s.batch.id == batchId) mine = s;
        }
        if (mine == null) {
          return BhorEmptyState(
            icon: Icons.search_off,
            title: l10n.commonLoadingFailed,
          );
        }
        return _Content(schedule: mine);
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.schedule});

  final BatchSchedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final Batch batch = schedule.batch;
    final today = ref.watch(todayProvider);
    final int weekStart = ref.watch(weekStartProvider).value ?? 6;
    final List<SlotDraft> slots = currentSlotDrafts(schedule, today);
    final bool archived = batch.archived;

    void openEditor() => context.push(Routes.batchSlots(batch.id));

    if (slots.isEmpty) {
      final Widget card = BhorCard(
        padding: EdgeInsets.zero,
        child: BhorEmptyState(
          icon: Icons.event_busy_outlined,
          title: l10n.schedTabEmpty,
          action: archived ? null : BhorButton(label: l10n.schedTabAddFirst, onPressed: openEditor),
        ),
      );
      return LayoutBuilder(
        builder: (BuildContext _, BoxConstraints box) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (archived) ...<Widget>[
              _Note(text: l10n.schedArchivedReadOnly),
              const SizedBox(height: 12),
            ],
            if (box.hasBoundedHeight)
              Expanded(child: card)
            else
              SizedBox(height: 320, child: card),
          ],
        ),
      );
    }

    final Widget week = WeekOverview(slots: slots, weekStart: weekStart);
    // [fill]: wide windows put the two columns in one row of equal height; the
    // sentence card then takes the height the week card has over the rest, so
    // neither column leaves a blank area below it.
    Widget buildSide({required bool fill}) {
      final Widget sentence = SlotSentenceCard(slots: slots, weekStart: weekStart, fill: fill);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (archived) ...<Widget>[
            _Note(text: l10n.schedArchivedReadOnly),
            const SizedBox(height: 12),
          ],
          _ReminderRow(batch: batch, enabled: !archived),
          const SizedBox(height: 12),
          if (fill) Expanded(child: sentence) else sentence,
          const SizedBox(height: 12),
          BhorButton(
            onPressed: archived ? null : openEditor,
            expand: true,
            icon: Icons.edit_calendar_outlined,
            label: l10n.schedChangeWeekly,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints box) {
        if (box.maxWidth >= 720) {
          return SingleChildScrollView(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(flex: 3, child: week),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: buildSide(fill: true)),
                ],
              ),
            ),
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[buildSide(fill: false), const SizedBox(height: 12), week],
          ),
        );
      },
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: b.colors.accentTint,
        borderRadius: BorderRadius.circular(BhorRadius.control),
        border: Border.all(color: b.colors.accentLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BhorSpace.s12),
        child: Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: b.colors.accent),
            const SizedBox(width: BhorSpace.s12),
            Expanded(child: Text(text, style: b.type.body)),
          ],
        ),
      ),
    );
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow({required this.batch, required this.enabled});

  final Batch batch;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final bool masterOn = ref.watch(classRemindersOnProvider).value ?? true;
    final int defaultLead = ref.watch(defaultReminderLeadProvider).value ?? 15;
    final int? lead = batch.reminderLeadMin;

    String minutesBefore(int n) => l10n.schedMinutesBefore(fmt.digits('$n'));
    final String text;
    if (!masterOn) {
      text = l10n.schedReminderMasterOff;
    } else if (lead == null) {
      text = l10n.schedReminderRowDefault(minutesBefore(defaultLead));
    } else if (lead == 0) {
      text = l10n.schedReminderRowOff;
    } else {
      text = l10n.schedReminderRowCustom(minutesBefore(lead));
    }

    Future<void> change() async {
      final int? picked = await openReminderLeadSheet(
        context,
        current: lead,
        defaultLead: defaultLead,
      );
      if (picked == null) return;
      try {
        await ref
            .read(batchesRepositoryProvider)
            .setReminderLead(batch.id, storedLeadOf(picked));
      } on Object catch (e) {
        if (context.mounted) BhorToast.show(context, message: errorText(context.l10n, e));
      }
    }

    return BhorCard(
      padding: EdgeInsets.zero,
      onTap: !enabled
          ? null
          : masterOn
              ? change
              : () => context.go(Routes.more),
      semanticLabel: text,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s8),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                masterOn ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                color: masterOn ? b.colors.accent : b.colors.text2,
              ),
            ),
            const SizedBox(width: BhorSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    text,
                    style: b.type.body.copyWith(color: masterOn ? b.colors.text : b.colors.text2),
                  ),
                  if (lead != null && masterOn && enabled)
                    BhorButton(
                      variant: BhorButtonVariant.ghost,
                      onPressed: () async {
                        try {
                          await ref.read(batchesRepositoryProvider).setReminderLead(batch.id, null);
                        } on Object catch (e) {
                          if (context.mounted) BhorToast.show(context, message: errorText(context.l10n, e));
                        }
                      },
                      icon: Icons.restart_alt,
                      label: l10n.schedLeadReset,
                    ),
                ],
              ),
            ),
            if (enabled) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
