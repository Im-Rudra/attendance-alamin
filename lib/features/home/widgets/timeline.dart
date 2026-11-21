// "আজকের রুটিন" (UX 2g): the classes of one date with their states, roll call
// progress (✓ x/y), cancelled ones struck through, moved ones with "→ …" on the
// date they left, extras tagged. On a phone it sits under the day strip; in the
// bento it is a tall tile that scrolls inside with a fade edge.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/features/classes/classes_entry.dart';
import 'package:attendance_alamin/features/home/widgets/tile_frame.dart';
import 'package:attendance_alamin/features/home/widgets/today_actions.dart';

class TodayTimeline extends ConsumerWidget {
  const TodayTimeline({super.key, required this.date, this.bounded = false, this.strip});

  final LocalDate date;

  /// Bento tile: fills its tile and scrolls inside.
  final bool bounded;

  /// The day strip shown above the title (phones and mediums).
  final Widget? strip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    final LocalDate today = ref.watch(todayProvider);
    final DayPlan? plan = ref.watch(dayPlanProvider(date)).value;
    final List<BatchSchedule> schedules =
        ref.watch(schedulesProvider).value ?? const <BatchSchedule>[];

    final String title = date == today
        ? l10n.todayRoutineToday
        : l10n.todayRoutineOther(fmt.dateShort(date));

    final bool noClasses = plan != null && plan.classes.isEmpty && plan.movedAway.isEmpty;

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (strip != null) ...<Widget>[
          strip!,
          const SizedBox(height: 4),
          Divider(height: 1, color: tokens.hairline),
          const SizedBox(height: 8),
        ],
        TileHeader(
          icon: Icons.event_note_outlined,
          title: title,
          trailing: noClasses
              ? null
              : TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => showExtraClassSheet(context, date: date),
            child: Text(l10n.todayAddExtra),
          ),
        ),
      ],
    );

    final List<Widget> rows = <Widget>[
      if (plan != null) ...<Widget>[
        for (final DayClass c in plan.classes)
          _ClassRow(key: ValueKey<String>('today-class-${c.occ}'), dc: c, date: date),
        for (final MovedAway m in plan.movedAway)
          _MovedAwayRow(
            key: ValueKey<String>('today-moved-${m.occ}'),
            moved: m,
            schedules: schedules,
          ),
      ],
    ];

    if (bounded) {
      final Widget body;
      if (plan == null) {
        body = const SizedBox.shrink();
      } else if (rows.isEmpty) {
        body = _emptyDay(context, date);
      } else {
        body = _FadingList(rows: rows);
      }
      return TileFrame(header: header, scroll: false, child: body);
    }

    final Widget body;
    if (plan == null) {
      body = const SizedBox(height: 96);
    } else if (rows.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _emptyDay(context, date),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 8),
            rows[i],
          ],
        ],
      );
    }
    return TileFrame(header: header, child: body);
  }
}

/// The empty-day state: says so and offers "+ অতিরিক্ত ক্লাস" right there.
Widget _emptyDay(BuildContext context, LocalDate date) {
  final l10n = context.l10n;
  return TileMessage(
    icon: Icons.event_available_outlined,
    message: l10n.todayNoClassesDay,
    action: FilledButton.tonalIcon(
      key: const ValueKey<String>('today-empty-add-extra'),
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: () => showExtraClassSheet(context, date: date),
      icon: const Icon(Icons.add),
      label: Text(l10n.todayAddExtra),
    ),
  );
}

/// A scrolling list whose bottom edge fades out (UX 3b: the timeline scrolls
/// internally with a fade edge).
class _FadingList extends StatelessWidget {
  const _FadingList({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final Color solid = tokens.surfaceSolid;
    final Color clear = tokens.surfaceSolid.withValues(alpha: 0);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[solid, solid, clear],
        stops: const <double>[0, 0.92, 1],
      ).createShader(r),
      child: ListView.separated(
        primary: false,
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: rows.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) => rows[index],
      ),
    );
  }
}

class _ClassRow extends ConsumerWidget {
  const _ClassRow({super.key, required this.dc, required this.date});

  final DayClass dc;
  final LocalDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final LocalDate today = ref.watch(todayProvider);
    final int nowMin = ref.watch(nowMinutesProvider);

    final bool cancelled = dc.cancelled;
    final bool taken = dc.taken;
    final bool isFuture = date.isAfter(today) || (date == today && dc.startMin > nowMin);
    final bool running = !cancelled &&
        date == today &&
        dc.startMin <= nowMin &&
        nowMin < dc.endMin;
    final bool needsRoll = !cancelled && !taken && !isFuture;
    final bool dimmed = cancelled || (taken && !running);

    final TextDecoration? strike = cancelled ? TextDecoration.lineThrough : null;
    final TextStyle? titleStyle = tt.titleSmall?.copyWith(
      color: tokens.textPrimary,
      fontWeight: FontWeight.w600,
      decoration: strike,
    );
    final TextStyle? timeStyle = tt.bodyMedium?.copyWith(
      color: tokens.textSecondary,
      decoration: strike,
    );

    final present = AttendanceStatus.present.kind;
    final Color leadBg;
    final Color leadFg;
    final IconData leadIcon;
    if (taken) {
      leadBg = context.attendance.fill(present);
      leadFg = context.attendance.text(present);
      leadIcon = Icons.check;
    } else if (running) {
      leadBg = tokens.accentContainer;
      leadFg = tokens.onAccentContainer;
      leadIcon = Icons.fiber_manual_record;
    } else if (cancelled) {
      leadBg = tokens.track;
      leadFg = tokens.textSecondary;
      leadIcon = Icons.block;
    } else if (dc.state == ClassState.extra) {
      leadBg = tokens.track;
      leadFg = tokens.textSecondary;
      leadIcon = Icons.add;
    } else if (dc.state == ClassState.moved) {
      leadBg = tokens.track;
      leadFg = tokens.textSecondary;
      leadIcon = Icons.autorenew;
    } else {
      leadBg = tokens.track;
      leadFg = tokens.textSecondary;
      leadIcon = Icons.schedule;
    }

    final AttendanceTally? tally = dc.tally;
    final List<Widget> meta = <Widget>[
      Text(fmt.timeRange(dc.startMin, dc.endMin), style: timeStyle),
      if (dc.state != null) StatePill(state: dc.state!),
      if (dc.state == ClassState.moved && dc.originalStartMin != null)
        Text(l10n.todayMovedFrom(fmt.time(dc.originalStartMin!)), style: timeStyle),
      if (taken)
        _RollChip(
          text: l10n.todayRollTaken(
            fmt.number(tally == null ? 0 : tally.present + tally.late),
            fmt.number(tally?.held ?? 0),
          ),
        )
      else if (needsRoll && !running)
        _RollChip(text: l10n.todayRollPending, pending: true),
    ];

    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(color: leadBg, shape: BoxShape.circle),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(leadIcon, size: running ? 14 : 20, color: leadFg),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.clsClassLabel(dc.subjectName, dc.batch.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: meta,
                  ),
                  if (needsRoll) ...<Widget>[
                    const SizedBox(height: 6),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: () => openRollCall(context, dc.occ),
                      child: Text(l10n.todayTakeAttendance),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.todayClassOptions,
            icon: const Icon(Icons.more_vert),
            onPressed: () => showClassActionsSheet(context, occ: dc.occ, returnTo: Routes.today),
          ),
        ],
      ),
    );

    return Material(
      color: running ? tokens.accentContainer.withValues(alpha: 0.5) : Colors.transparent,
      borderRadius: BorderRadius.circular(AuroraMetrics.radiusDenseList),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (cancelled || isFuture) {
            showClassActionsSheet(context, occ: dc.occ, returnTo: Routes.today);
          } else {
            openRollCall(context, dc.occ);
          }
        },
        child: Opacity(opacity: dimmed ? 0.62 : 1, child: content),
      ),
    );
  }
}

/// "হাজিরা ২৮/৩০" with a check, or "হাজিরা বাকি" in the info tone.
class _RollChip extends StatelessWidget {
  const _RollChip({required this.text, this.pending = false});

  final String text;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final present = AttendanceStatus.present.kind;
    final Color bg = pending ? tokens.infoContainer : context.attendance.fill(present);
    final Color fg = pending ? tokens.info : context.attendance.text(present);
    return DecoratedBox(
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(pending ? Icons.pending_actions : Icons.check, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              text,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// A class that left this date: "ফিজিক্স · এ → ২৪ নভে সকাল ১১:০০".
class _MovedAwayRow extends StatelessWidget {
  const _MovedAwayRow({super.key, required this.moved, required this.schedules});

  final MovedAway moved;
  final List<BatchSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final tokens = context.aurora;
    String label = '';
    for (final BatchSchedule s in schedules) {
      if (s.batch.id == moved.batchId) {
        label = l10n.clsClassLabel(s.subjectName, s.batch.name);
        break;
      }
    }
    final String when = '${fmt.dateShort(moved.newDate)} ${fmt.time(moved.newStartMin)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Opacity(
        opacity: 0.75,
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(color: tokens.track, shape: BoxShape.circle),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.arrow_forward, size: 20, color: tokens.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.todayMovedAway(label, when),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: tokens.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
