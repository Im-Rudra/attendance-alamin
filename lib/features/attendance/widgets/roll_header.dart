// Header pieces of the roll call screen: date + session time with the day
// arrows and session chips, the coloured notes (past day, cancelled class,
// extra class...), the ad-hoc time card and the desktop summary pane.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_parts.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_call_controller.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';

/// Date and class time (always both), day arrows and, for 2+ classes, chips.
class RollDateHeader extends StatelessWidget {
  const RollDateHeader({
    super.key,
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.choices,
    required this.selectedOcc,
    required this.onPick,
  });

  final LocalDate date;
  final int startMin;
  final int endMin;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final List<SessionChoice> choices;
  final String? selectedOcc;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final String dateText = fmt.weekdayDate(date);
    final String timeText = fmt.timeRange(startMin, endMin);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            BhorIconButton(
              semanticLabel: l10n.rollPrevDay,
              icon: BhorIcons.chevronLeft,
              onPressed: onPrev,
            ),
            Expanded(
              child: Semantics(
                container: true,
                label: l10n.rollA11yDate(dateText, timeText),
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      dateText,
                      textAlign: TextAlign.center,
                      style: b.type.heading,
                    ),
                    Text(
                      timeText,
                      textAlign: TextAlign.center,
                      style: b.type.meta,
                    ),
                  ],
                ),
              ),
            ),
            BhorIconButton(
              semanticLabel: l10n.rollNextDay,
              icon: BhorIcons.chevronRight,
              onPressed: canGoNext ? onNext : null,
            ),
          ],
        ),
        if (choices.length > 1) ...<Widget>[
          const SizedBox(height: BhorSpace.s4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s4,
            children: <Widget>[
              for (final SessionChoice c in choices)
                BhorChip(
                  label: fmt.timeRange(c.startMin, c.endMin),
                  selected: c.occ == selectedOcc,
                  icon: c.taken ? BhorIcons.check : null,
                  onSelected: (bool _) => onPick(c.occ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

enum RollBannerTone { info, warning }

/// A one-sentence note with an icon (info = accent tint, warning = the danger
/// tint).
class RollBanner extends StatelessWidget {
  const RollBanner({super.key, required this.icon, required this.text, this.tone = RollBannerTone.info});

  final IconData icon;
  final String text;
  final RollBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final bool warn = tone == RollBannerTone.warning;
    final Color bg = warn ? b.colors.dangerBg : b.colors.accentTint;
    final Color fg = warn ? b.colors.danger : b.colors.text;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(BhorRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12, vertical: BhorSpace.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: warn ? fg : b.colors.accent, size: 22),
              const SizedBox(width: BhorSpace.s8),
              Expanded(child: Text(text, style: b.type.body.copyWith(color: fg))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Start and end of an unscheduled (ad-hoc) class: two big tappable tiles.
class AdHocTimeCard extends StatelessWidget {
  const AdHocTimeCard({
    super.key,
    required this.startMin,
    required this.endMin,
    required this.onStart,
    required this.onEnd,
    required this.enabled,
  });

  final int startMin;
  final int endMin;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    return Row(
      children: <Widget>[
        Expanded(
          child: _TimeTile(
            label: l10n.rollAdHocStart,
            value: fmt.time(startMin),
            onTap: enabled ? onStart : null,
          ),
        ),
        const SizedBox(width: BhorSpace.s8),
        Expanded(
          child: _TimeTile(
            label: l10n.rollAdHocEnd,
            value: fmt.time(endMin),
            onTap: enabled ? onEnd : null,
          ),
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Semantics(
      button: onTap != null,
      label: context.l10n.a11yLabelValue(label, value),
      excludeSemantics: true,
      onTap: onTap,
      child: BhorPressable(
        onTap: onTap,
        radius: BhorRadius.control,
        builder: (BuildContext context, BhorStates s) => Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12, vertical: BhorSpace.s8),
          decoration: BoxDecoration(
            color: s.hovered ? c.surface2 : c.surface,
            borderRadius: BorderRadius.circular(BhorRadius.control),
            border: Border.all(color: s.hovered ? c.accentLine : c.line),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(label, style: b.type.meta),
                    Text(value, style: BhorType.tabular(b.type.bodyStrong)),
                  ],
                ),
              ),
              Icon(BhorIcons.clock, color: c.text2),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 300dp right pane of wide windows: live counts as stat tiles, the class
/// note and the collapsible shortcut legend. The save bar sits below it.
class RollSummaryPane extends StatelessWidget {
  const RollSummaryPane({super.key, required this.counts, required this.state, this.note, this.onNote});

  final RollCounts counts;

  /// "Saved" / "Saving…" / "Not saved yet" with its icon.
  final Widget state;
  final String? note;
  final VoidCallback? onNote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final List<String> legend = <String>[
      l10n.rollKeyMove,
      l10n.rollKeyToggle,
      l10n.rollKeyStatus,
      l10n.rollKeyDigits,
      l10n.rollKeySave,
      l10n.rollKeyDay,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(BhorSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          state,
          const SizedBox(height: BhorSpace.s12),
          RollCountsBar(counts: counts),
          const SizedBox(height: BhorSpace.s12),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: BhorSpace.s8),
              child: Text(l10n.rollNoteLabel(note!), style: b.type.meta),
            ),
          if (onNote != null)
            BhorButton(
              label: l10n.rollMenuNote,
              icon: BhorIcons.notes,
              variant: BhorButtonVariant.secondary,
              expand: true,
              onPressed: onNote,
            ),
          const SizedBox(height: BhorSpace.s8),
          _ShortcutLegend(title: l10n.rollShortcutsTitle, lines: legend),
        ],
      ),
    );
  }
}

/// Live count tags (present / absent / late, excused when any) shown above
/// the roster on phones; each number rolls when a mark changes.
class RollCountTags extends StatelessWidget {
  const RollCountTags({super.key, required this.counts});

  final RollCounts counts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    Widget tag(AttendanceStatus s, int n) {
      final (Color bg, Color fg) = BhorTag.colorsOf(b.colors, attendanceTone(s));
      return Semantics(
        container: true,
        label: '${s.label(l10n)} ${context.fmt.number(n)}',
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: BhorMotion.of(context, BhorMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BhorRadius.pill)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(statusIcon(s), size: BhorIconSize.inline, color: fg),
              const SizedBox(width: BhorSpace.s4),
              Text(s.label(l10n), maxLines: 1, style: b.type.caption.copyWith(color: fg, fontWeight: FontWeight.w600)),
              const SizedBox(width: BhorSpace.s4),
              BhorCountUp(
                value: n,
                from: n,
                style: b.type.caption.copyWith(color: fg, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: BhorSpace.s8,
      runSpacing: BhorSpace.s8,
      children: <Widget>[
        tag(AttendanceStatus.present, counts.present),
        tag(AttendanceStatus.absent, counts.absent),
        tag(AttendanceStatus.late, counts.late),
        if (counts.leave > 0) tag(AttendanceStatus.leave, counts.leave),
      ],
    );
  }
}

/// Colour of an attendance status in the counts bar and dots.
Color _statusColor(BhorColors c, AttendanceStatus s) => switch (s) {
      AttendanceStatus.present => c.ok,
      AttendanceStatus.absent => c.absentText,
      AttendanceStatus.late => c.late,
      AttendanceStatus.leave => c.text3,
    };

/// One stacked bar (present / absent / late / excused) whose segments glide as
/// marks change, with a legend of live counts under it.
class RollCountsBar extends StatelessWidget {
  const RollCountsBar({super.key, required this.counts});

  final RollCounts counts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final Duration slow = BhorMotion.of(context, BhorMotion.slow);
    final int total = counts.total == 0 ? 1 : counts.total;
    final List<(AttendanceStatus, int)> parts = <(AttendanceStatus, int)>[
      (AttendanceStatus.present, counts.present),
      (AttendanceStatus.absent, counts.absent),
      (AttendanceStatus.late, counts.late),
      (AttendanceStatus.leave, counts.leave),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(BhorRadius.pill),
          child: ColoredBox(
            color: c.soft,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) => Row(
                children: <Widget>[
                  for (final (AttendanceStatus, int) p in parts)
                    AnimatedContainer(
                      duration: slow,
                      curve: BhorMotion.ease,
                      height: 10,
                      width: box.maxWidth * p.$2 / total,
                      color: _statusColor(c, p.$1),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: BhorSpace.s12),
        for (final (AttendanceStatus, int) p in parts)
          if (p.$1 != AttendanceStatus.leave || p.$2 > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
              child: Row(
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(color: _statusColor(c, p.$1), shape: BoxShape.circle),
                    child: const SizedBox(width: 10, height: 10),
                  ),
                  const SizedBox(width: BhorSpace.s8),
                  Expanded(child: Text(p.$1.label(l10n), style: b.type.body)),
                  BhorCountUp(value: p.$2, from: p.$2, style: b.type.bodyStrong),
                ],
              ),
            ),
      ],
    );
  }
}

/// A collapsible list of the desktop shortcuts (closed by default).
class _ShortcutLegend extends StatefulWidget {
  const _ShortcutLegend({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  State<_ShortcutLegend> createState() => _ShortcutLegendState();
}

class _ShortcutLegendState extends State<_ShortcutLegend> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorPressable(
          onTap: () => setState(() => _open = !_open),
          semanticLabel: widget.title,
          semanticHint: null,
          radius: BhorRadius.control,
          builder: (BuildContext context, BhorStates s) => Container(
            constraints: const BoxConstraints(minHeight: BhorSize.minTap),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(widget.title, style: b.type.heading)),
                Icon(_open ? BhorIcons.chevronUp : BhorIcons.chevronDown, color: b.colors.text2),
              ],
            ),
          ),
        ),
        if (_open)
          for (final String line in widget.lines)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.only(bottom: BhorSpace.s8),
                child: Text(line, style: b.type.meta),
              ),
            ),
      ],
    );
  }
}
