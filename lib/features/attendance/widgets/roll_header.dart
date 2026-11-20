// Header pieces of the roll call screen: date + session time with the day
// arrows and session chips, the coloured notes (past day, cancelled class,
// extra class...), the ad-hoc time card and the desktop summary pane.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String dateText = fmt.weekdayDate(date);
    final String timeText = fmt.timeRange(startMin, endMin);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: l10n.rollPrevDay,
              icon: const Icon(Icons.chevron_left),
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
                      style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
                    ),
                    Text(
                      timeText,
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.rollNextDay,
              icon: const Icon(Icons.chevron_right),
              onPressed: canGoNext ? onNext : null,
            ),
          ],
        ),
        if (choices.length > 1) ...<Widget>[
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              for (final SessionChoice c in choices)
                ChoiceChip(
                  selected: c.occ == selectedOcc,
                  avatar: c.taken ? const Icon(Icons.check, size: 18) : null,
                  label: Text(fmt.timeRange(c.startMin, c.endMin)),
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

/// A one-sentence note with an icon (info = accent-free container, warning =
/// the error container).
class RollBanner extends StatelessWidget {
  const RollBanner({super.key, required this.icon, required this.text, this.tone = RollBannerTone.info});

  final IconData icon;
  final String text;
  final RollBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool warn = tone == RollBannerTone.warning;
    final Color bg = warn ? tokens.errorContainer : tokens.infoContainer;
    final Color fg = warn ? tokens.onErrorContainer : tokens.textPrimary;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
          border: warn ? Border.all(color: tokens.errorContainerBorder) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: warn ? fg : tokens.info, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: tt.bodyMedium?.copyWith(color: fg))),
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
        const SizedBox(width: 8),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: context.l10n.a11yLabelValue(label, value),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: tokens.surfaceDense,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuroraMetrics.radiusField),
          side: BorderSide(color: tokens.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                        Text(label, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
                        Text(value, style: tt.bodyLarge?.copyWith(color: tokens.textPrimary)),
                      ],
                    ),
                  ),
                  Icon(Icons.schedule, color: tokens.textSecondary),
                ],
              ),
            ),
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
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    Widget tile(AttendanceStatus s, int n) =>
        StatTile(label: s.label(l10n), value: fmt.number(n));
    final List<String> legend = <String>[
      l10n.rollKeyMove,
      l10n.rollKeyToggle,
      l10n.rollKeyStatus,
      l10n.rollKeyDigits,
      l10n.rollKeySave,
      l10n.rollKeyDay,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          state,
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: tile(AttendanceStatus.present, counts.present)),
              const SizedBox(width: 8),
              Expanded(child: tile(AttendanceStatus.absent, counts.absent)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: tile(AttendanceStatus.late, counts.late)),
              const SizedBox(width: 8),
              Expanded(child: tile(AttendanceStatus.leave, counts.leave)),
            ],
          ),
          const SizedBox(height: 12),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l10n.rollNoteLabel(note!), style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
            ),
          if (onNote != null)
            OutlinedButton.icon(
              onPressed: onNote,
              icon: const Icon(Icons.edit_note),
              label: Text(l10n.rollMenuNote),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(l10n.rollShortcutsTitle, style: tt.titleSmall?.copyWith(color: tokens.textPrimary)),
            children: <Widget>[
              for (final String line in legend)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(line, style: tt.bodySmall?.copyWith(color: tokens.textSecondary)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
