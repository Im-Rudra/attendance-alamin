// The weekly slot editor UI, driven by a [SlotEditorController]: the "same time
// on every day" switch, weekday chips or per-day groups, the live sentence and
// the live clash card. Shared by `SlotEditorField` (batch form, onboarding)
// and the full-screen `SlotEditorScreen`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/schedule/controllers/slot_editor_controller.dart';
import 'package:attendance_alamin/features/schedule/widgets/sched_chip.dart';
import 'package:attendance_alamin/features/schedule/widgets/slot_clash_card.dart';
import 'package:attendance_alamin/features/schedule/widgets/time_picker_sheet.dart';

class SlotEditorBody extends ConsumerWidget {
  const SlotEditorBody({
    super.key,
    required this.controller,
    this.ownBatchId,
    this.showSentence = true,
  });

  final SlotEditorController controller;
  final String? ownBatchId;

  /// The full-screen editor shows the sentence in its side card instead.
  final bool showSentence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int weekStart = ref.watch(weekStartProvider).value ?? 6;
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) =>
          _build(context, controller, weekStart),
    );
  }

  Widget _build(BuildContext context, SlotEditorController c, int weekStart) {
    final l10n = context.l10n;
    final SlotCheckResult? result = c.check;
    final Widget clash = (result != null && !result.ok)
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SlotClashCard(
              result: result,
              ownBatchId: ownBatchId,
              onFix: (int start) {
                final FreeSuggestion? s = result.suggestion;
                if (s == null) return;
                c.applyFix(
                  s,
                  start,
                  <int>{for (final ClashGroup g in result.groups) g.weekday},
                );
              },
            ),
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SameAllRow(controller: c),
        const SizedBox(height: 12),
        if (c.sameAll)
          _SameTimeEditor(controller: c, weekStart: weekStart, clash: clash)
        else
          _PerDayEditor(controller: c, weekStart: weekStart, clash: clash),
        if (showSentence && !c.isEmpty) ...<Widget>[
          const SizedBox(height: 12),
          SlotSentenceCard(slots: c.slots, weekStart: weekStart),
        ] else if (showSentence && c.isEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            l10n.schedSentenceEmpty,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.aurora.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// "শনি, সোম — বিকাল ৪:০০–৫:০০" inside a dense card; announced when it changes.
class SlotSentenceCard extends StatelessWidget {
  const SlotSentenceCard({super.key, required this.slots, required this.weekStart});

  final List<SlotDraft> slots;
  final int weekStart;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return GlassCard(
      dense: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
              child: Icon(Icons.event_repeat, color: tokens.accent, size: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.schedSentenceTitle,
                      style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    scheduleSentence(
                      context.fmt,
                      slots,
                      weekStart: weekStart,
                      andWord: l10n.schedAnd,
                    ),
                    style: tt.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SameAllRow extends StatelessWidget {
  const _SameAllRow({required this.controller});

  final SlotEditorController controller;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final String label = context.l10n.schedSameAllDays;
    return GlassCard(
      dense: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MergeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(label, style: tt.titleMedium)),
              Switch(
                value: controller.sameAll,
                onChanged: controller.setSameAll,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Weekday chips + one shared time.
class _SameTimeEditor extends StatelessWidget {
  const _SameTimeEditor({
    required this.controller,
    required this.weekStart,
    required this.clash,
  });

  final SlotEditorController controller;
  final int weekStart;
  final Widget clash;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final tokens = context.aurora;
    final c = controller;
    final List<int> order = <int>[
      for (var i = 0; i < 7; i++) ((weekStart - 1 + i) % 7) + 1,
    ];
    return GlassCard(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.schedPickDays, style: tt.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final int d in order)
                SchedChip(
                  label: fmt.weekdayShort(d),
                  semanticLabel: fmt.weekdayName(d),
                  selected: c.days.contains(d),
                  minWidth: 56,
                  onTap: () => c.toggleDay(d),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.schedClassTime, style: tt.titleMedium),
          const SizedBox(height: 12),
          _TimePair(
            start: c.commonStart,
            end: c.commonEnd,
            onStart: c.setCommonStart,
            onEnd: c.setCommonEnd,
          ),
          if (c.commonEnd <= c.commonStart && !c.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.schedReasonBadTime,
                  style: tt.bodyMedium?.copyWith(color: tokens.error)),
            ),
          clash,
        ],
      ),
    );
  }
}

/// One group per weekday, one row per class time.
class _PerDayEditor extends StatelessWidget {
  const _PerDayEditor({
    required this.controller,
    required this.weekStart,
    required this.clash,
  });

  final SlotEditorController controller;
  final int weekStart;
  final Widget clash;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final c = controller;
    final List<int> days = c.orderedDays(weekStart);
    final List<int> missing = c.missingDays(weekStart);

    Widget groupFor(int day) {
      final List<SlotRow> rows = c.rowsOf(day);
      return GlassCard(
        dense: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(fmt.weekdayName(day), style: tt.titleMedium),
            ),
            const SizedBox(height: 8),
            for (final SlotRow r in rows) ...<Widget>[
              LayoutBuilder(
                builder: (BuildContext _, BoxConstraints rb) {
                  final Widget pair = _TimePair(
                    start: r.draft.startMin,
                    end: r.draft.endMin,
                    onStart: (int v) => c.setStart(r.index, v),
                    onEnd: (int v) => c.setEnd(r.index, v),
                  );
                  if (rb.maxWidth < 340) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        pair,
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () => c.removeAt(r.index),
                            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(l10n.schedRemoveTime),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: pair),
                      IconButton(
                        tooltip: l10n.schedRemoveTime,
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        onPressed: () => c.removeAt(r.index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  );
                },
              ),
              if (c.isBadAt(r.index))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l10n.schedReasonBadTime,
                      style: tt.bodyMedium?.copyWith(color: tokens.error)),
                ),
              const SizedBox(height: 4),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => c.addTime(day),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.add),
                label: Text(l10n.schedAddTime),
              ),
            ),
          ],
        ),
      );
    }

    final Widget addDay = missing.isEmpty
        ? const SizedBox.shrink()
        : PopupMenuButton<int>(
            tooltip: l10n.schedAddDay,
            onSelected: c.addDay,
            itemBuilder: (BuildContext _) => <PopupMenuEntry<int>>[
              for (final int d in missing)
                PopupMenuItem<int>(
                  value: d,
                  height: 48,
                  child: Text(fmt.weekdayName(d)),
                ),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
                  border: Border.all(color: tokens.hairline),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.add, color: tokens.accent),
                      const SizedBox(width: 8),
                      Text(l10n.schedAddDay,
                          style: tt.labelLarge?.copyWith(color: tokens.accent)),
                    ],
                  ),
                ),
              ),
            ),
          );

    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints box) {
        final bool twoCols = box.maxWidth >= 640 && days.length > 1;
        const double gap = 12;
        final double w = twoCols ? (box.maxWidth - gap) / 2 : box.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final int d in days) SizedBox(width: w, child: groupFor(d)),
              ],
            ),
            if (missing.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Align(alignment: AlignmentDirectional.centerStart, child: addDay),
            ],
            clash,
          ],
        );
      },
    );
  }
}

/// [start] – [end] as two tappable time buttons.
class _TimePair extends StatelessWidget {
  const _TimePair({
    required this.start,
    required this.end,
    required this.onStart,
    required this.onEnd,
  });

  final int start;
  final int end;
  final ValueChanged<int> onStart;
  final ValueChanged<int> onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: <Widget>[
        Expanded(
          child: TimeButton(
            label: l10n.schedFrom,
            minutes: start,
            onPicked: onStart,
            pickerTitle: l10n.schedPickStart,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('–'),
        ),
        Expanded(
          child: TimeButton(
            label: l10n.schedTo,
            minutes: end,
            onPicked: onEnd,
            pickerTitle: l10n.schedPickEnd,
          ),
        ),
      ],
    );
  }
}

/// A field-like button showing one time; tapping opens the time picker.
class TimeButton extends StatelessWidget {
  const TimeButton({
    super.key,
    required this.label,
    required this.minutes,
    required this.onPicked,
    this.pickerTitle,
  });

  final String label;
  final int minutes;
  final ValueChanged<int> onPicked;
  final String? pickerTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String time = context.fmt.time(minutes);
    final BorderRadius br = BorderRadius.circular(AuroraMetrics.radiusField);
    return Semantics(
      button: true,
      label: '$label: $time',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: Material(
        color: tokens.surfaceSolid,
        shape: RoundedRectangleBorder(
          borderRadius: br,
          side: BorderSide(color: tokens.hairline),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: br),
          onTap: () => _open(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelSmall?.copyWith(color: tokens.textSecondary)),
                        Text(time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium),
                      ],
                    ),
                  ),
                  if (MediaQuery.textScalerOf(context).scale(16) < 20)
                    Icon(Icons.schedule, size: 20, color: tokens.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final int? v =
        await openTimePicker(context, initialMin: minutes, title: pickerTitle);
    if (v != null) onPicked(v);
  }
}
