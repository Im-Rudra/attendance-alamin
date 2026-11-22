// The weekly slot editor UI, driven by a [SlotEditorController]: the "same time
// on every day" switch, weekday chips or per-day groups, the live sentence and
// the live clash card. Shared by `SlotEditorField` (batch form, onboarding)
// and the full-screen `SlotEditorScreen`.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
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
            style: context.bhor.type.body.copyWith(color: context.bhor.colors.text2),
          ),
        ],
      ],
    );
  }
}

/// A flat soft-filled group (no outline): one level of containment per form
/// section, never card-in-card.
class _SoftBox extends StatelessWidget {
  const _SoftBox({required this.child, this.padding = const EdgeInsets.all(BhorSpace.s16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.bhor.colors.soft,
        borderRadius: BorderRadius.circular(BhorRadius.card),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// "শনি, সোম — বিকাল ৪:০০–৫:০০" inside a dense card; announced when it changes.
class SlotSentenceCard extends StatelessWidget {
  const SlotSentenceCard({
    super.key,
    required this.slots,
    required this.weekStart,
    this.fill = false,
  });

  final List<SlotDraft> slots;
  final int weekStart;

  /// The card is stretched by its parent: centre the content vertically.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final Widget content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
              child: Icon(BhorIcons.calendar, color: b.colors.accent, size: 24)),
          const SizedBox(width: BhorSpace.s12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.schedSentenceTitle,
                      style: b.type.label.copyWith(color: b.colors.text2)),
                  const SizedBox(height: 2),
                  Text(
                    scheduleSentence(
                      context.fmt,
                      slots,
                      weekStart: weekStart,
                      andWord: l10n.schedAnd,
                    ),
                    style: b.type.body,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: b.colors.accentTint,
        borderRadius: BorderRadius.circular(BhorRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BhorSpace.s16),
        child: fill ? Align(alignment: AlignmentDirectional.centerStart, child: content) : content,
      ),
    );
  }
}

class _SameAllRow extends StatelessWidget {
  const _SameAllRow({required this.controller});

  final SlotEditorController controller;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final String label = context.l10n.schedSameAllDays;
    return _SoftBox(
      padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: b.type.heading)),
            BhorSwitch(
              value: controller.sameAll,
              semanticLabel: label,
              onChanged: controller.setSameAll,
            ),
          ],
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
    final BhorThemeData b = context.bhor;
    final c = controller;
    final List<int> order = <int>[
      for (var i = 0; i < 7; i++) ((weekStart - 1 + i) % 7) + 1,
    ];
    return _SoftBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.schedPickDays, style: b.type.heading),
          const SizedBox(height: BhorSpace.s12),
          // Seven equal columns when there is room (no orphan on line two).
          LayoutBuilder(
            builder: (BuildContext _, BoxConstraints box) {
              Widget chip(int d, double minW) => SchedChip(
                    label: fmt.weekdayShort(d),
                    semanticLabel: fmt.weekdayName(d),
                    selected: c.days.contains(d),
                    minWidth: minW,
                    onTap: () => c.toggleDay(d),
                  );
              if (box.maxWidth >= 440) {
                return Row(
                  children: <Widget>[
                    for (int i = 0; i < order.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(child: chip(order[i], 0)),
                    ],
                  ],
                );
              }
              // Narrow: chips of one minimum width that wrap 4 + 3 (never
              // 6 + 1); the selected check may widen a chip a little.
              const double gap = 8;
              final double minW = (box.maxWidth - gap * 3) / 4 - 8;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: <Widget>[for (final int d in order) chip(d, minW < 56 ? 56 : minW)],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(l10n.schedClassTime, style: b.type.heading),
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
                  style: b.type.body.copyWith(color: b.colors.danger)),
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
    final BhorThemeData b = context.bhor;
    final c = controller;
    final List<int> days = c.orderedDays(weekStart);
    final List<int> missing = c.missingDays(weekStart);

    Widget groupFor(int day) {
      final List<SlotRow> rows = c.rowsOf(day);
      return _SoftBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(fmt.weekdayName(day), style: b.type.heading),
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
                          child: BhorButton(
                            variant: BhorButtonVariant.ghost,
                            onPressed: () => c.removeAt(r.index),
                            icon: BhorIcons.delete,
                            label: l10n.schedRemoveTime,
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      Expanded(child: pair),
                      BhorIconButton(
                        semanticLabel: l10n.schedRemoveTime,
                        onPressed: () => c.removeAt(r.index),
                        icon: BhorIcons.delete,
                      ),
                    ],
                  );
                },
              ),
              if (c.isBadAt(r.index))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l10n.schedReasonBadTime,
                      style: b.type.body.copyWith(color: b.colors.danger)),
                ),
              const SizedBox(height: 4),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BhorButton(
                variant: BhorButtonVariant.ghost,
                onPressed: () => c.addTime(day),
                icon: BhorIcons.add,
                label: l10n.schedAddTime,
              ),
            ),
          ],
        ),
      );
    }

    Future<void> pickDay() async {
      final int? d = await showBhorPanel<int>(
        context,
        kind: BhorPanelKind.list,
        width: 380,
        title: l10n.schedAddDay,
        builder: (BuildContext ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < missing.length; i++)
              BhorListRow(
                title: fmt.weekdayName(missing[i]),
                divider: i != missing.length - 1,
                onTap: () => Navigator.of(ctx).pop(missing[i]),
              ),
          ],
        ),
      );
      if (d != null) c.addDay(d);
    }

    final Widget addDay = missing.isEmpty
        ? const SizedBox.shrink()
        : BhorButton(
            variant: BhorButtonVariant.secondary,
            icon: BhorIcons.add,
            label: l10n.schedAddDay,
            onPressed: pickDay,
          );

    return LayoutBuilder(
      builder: (BuildContext _, BoxConstraints box) {
        final bool twoCols = box.maxWidth >= 640 && days.length > 1;
        const double gap = BhorSpace.s12;
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

/// A standard picker field showing one time; tapping opens the time picker
/// as a popover anchored to the field.
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
    final String time = context.fmt.time(minutes);
    return BhorPickerField(
      label: label,
      value: time,
      icon: BhorIcons.clock,
      semanticLabel: '$label: $time',
      onTap: (BuildContext field) => _open(context, field),
    );
  }

  Future<void> _open(BuildContext context, BuildContext field) async {
    final int? v = await openTimePicker(
      context,
      initialMin: minutes,
      title: pickerTitle,
      anchor: field,
    );
    if (v != null) onPicked(v);
  }
}
