// Header pieces of the roll call screen: date + session time with the day
// arrows (hugging the date) and session chips, the coloured notes (one merged
// info line, warnings apart), the ad-hoc time pickers and the live count
// tags.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_parts.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_call_controller.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';

/// Date and class time (always both), day arrows right next to the date and,
/// for 2+ classes, chips. [start] left-aligns it (the desktop top bar) and
/// puts date and time on one line.
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
    this.start = false,
    this.showChips = true,
    this.onPickDate,
  });

  /// Makes the date a button; gets the context to anchor the calendar to.
  final ValueChanged<BuildContext>? onPickDate;

  final LocalDate date;
  final int startMin;
  final int endMin;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final List<SessionChoice> choices;
  final String? selectedOcc;
  final ValueChanged<String> onPick;
  final bool start;
  final bool showChips;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final String dateText = fmt.weekdayDate(date);
    final String timeText = fmt.timeRange(startMin, endMin);
    // The date is a button (calendar glyph at its end) that opens the date
    // picker under it; without [onPickDate] it is plain text.
    final Widget dateLine = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: start
              ? Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: dateText, style: b.type.bodyStrong),
                      TextSpan(text: '  ·  $timeText', style: b.type.meta),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Text(
                  dateText,
                  textAlign: TextAlign.center,
                  style: b.type.heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        if (onPickDate != null) ...<Widget>[
          const SizedBox(width: BhorSpace.s8),
          Icon(BhorIcons.calendar, size: 18, color: b.colors.text2),
        ],
      ],
    );
    final Widget labelBody = start
        ? dateLine
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              dateLine,
              Text(timeText, textAlign: TextAlign.center, style: b.type.meta),
            ],
          );
    final Widget label = onPickDate == null
        ? Semantics(
            container: true,
            label: l10n.rollA11yDate(dateText, timeText),
            excludeSemantics: true,
            child: labelBody,
          )
        : Builder(
            builder: (BuildContext anchor) => BhorPressable(
              semanticLabel: l10n.rollA11yDate(dateText, timeText),
              semanticHint: l10n.rollPickDate,
              excludeChildSemantics: true,
              radius: BhorRadius.control,
              scaleOnPress: false,
              onTap: () => onPickDate!(anchor),
              builder: (BuildContext _, BhorStates s) => DecoratedBox(
                decoration: BoxDecoration(
                  color: s.hovered || s.pressed ? b.colors.surface2 : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(BhorRadius.control),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: BhorSize.compact),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s8, vertical: BhorSpace.s4),
                    child: Center(widthFactor: 1, child: labelBody),
                  ),
                ),
              ),
            ),
          );
    return Column(
      crossAxisAlignment: start ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: start ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: start ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: <Widget>[
            BhorIconButton(
              semanticLabel: l10n.rollPrevDay,
              icon: BhorIcons.chevronLeft,
              size: start ? BhorButtonSize.sm : BhorButtonSize.md,
              onPressed: onPrev,
            ),
            Flexible(child: label),
            BhorIconButton(
              semanticLabel: l10n.rollNextDay,
              icon: BhorIcons.chevronRight,
              size: start ? BhorButtonSize.sm : BhorButtonSize.md,
              onPressed: canGoNext ? onNext : null,
            ),
          ],
        ),
        if (showChips && choices.length > 1) ...<Widget>[
          const SizedBox(height: BhorSpace.s4),
          RollSessionChips(choices: choices, selectedOcc: selectedOcc, onPick: onPick, start: start),
        ],
      ],
    );
  }
}

/// One chip per class of the day (2+), the taken ones with a check.
class RollSessionChips extends StatelessWidget {
  const RollSessionChips({
    super.key,
    required this.choices,
    required this.selectedOcc,
    required this.onPick,
    this.start = false,
  });

  final List<SessionChoice> choices;
  final String? selectedOcc;
  final ValueChanged<String> onPick;
  final bool start;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    return Wrap(
      alignment: start ? WrapAlignment.start : WrapAlignment.center,
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

/// All the quiet info notes of the screen (past day, extra class, restored
/// draft, class note, "everyone present" hint) in ONE tinted banner: the
/// icon once, then each note on its own line, so two notes never run into
/// one paragraph (review R2, b277 X2).
class RollNotice extends StatelessWidget {
  const RollNotice({super.key, required this.lines, this.icon = BhorIcons.info});

  final List<String> lines;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: b.colors.accentTint,
          borderRadius: BorderRadius.circular(BhorRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12, vertical: BhorSpace.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, color: b.colors.accent, size: 18),
              ),
              const SizedBox(width: BhorSpace.s8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (int i = 0; i < lines.length; i++)
                      Padding(
                        key: ValueKey<String>('roll-notice-line-$i'),
                        padding: EdgeInsets.only(top: i == 0 ? 0 : BhorSpace.s4),
                        child: Text(lines[i], style: b.type.body.copyWith(color: b.colors.text)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The class-note field of the note popover: multi-line, focused on open.
class RollNoteField extends StatelessWidget {
  const RollNoteField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BhorSpace.s4),
      child: BhorTextField(
        key: const ValueKey<String>('roll-note-field'),
        controller: controller,
        autofocus: true,
        maxLength: 200,
        minLines: 3,
        maxLines: 6,
        hint: context.l10n.rollNoteHint,
      ),
    );
  }
}

/// Start and end of an unscheduled (ad-hoc) class: two identical picker
/// fields (the standard [BhorPickerField], review R2).
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

  /// Called with the tapped field's context (the time popover anchors to it).
  final ValueChanged<BuildContext> onStart;
  final ValueChanged<BuildContext> onEnd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    return Row(
      children: <Widget>[
        Expanded(
          child: BhorPickerField(
            label: l10n.rollAdHocStart,
            value: fmt.time(startMin),
            icon: BhorIcons.clock,
            onTap: enabled ? onStart : null,
          ),
        ),
        const SizedBox(width: BhorSpace.s8),
        Expanded(
          child: BhorPickerField(
            label: l10n.rollAdHocEnd,
            value: fmt.time(endMin),
            icon: BhorIcons.clock,
            onTap: enabled ? onEnd : null,
          ),
        ),
      ],
    );
  }
}

/// The desktop keyboard shortcuts, one per line (the keyboard help popover).
class RollShortcutList extends StatelessWidget {
  const RollShortcutList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final List<String> lines = <String>[
      l10n.rollKeyMove,
      l10n.rollKeyToggle,
      l10n.rollKeyStatus,
      l10n.rollKeyDigits,
      l10n.rollKeySave,
      l10n.rollKeyDay,
    ];
    return Padding(
      padding: const EdgeInsets.all(BhorSpace.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: BhorSpace.s8),
              child: Text(line, style: b.type.body),
            ),
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
