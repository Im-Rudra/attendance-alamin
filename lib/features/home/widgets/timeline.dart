// "আজকের রুটিন" (UX 2g): the classes of one date with their states, roll call
// progress (✓ x/y), cancelled ones struck through, moved ones with "→ …" on the
// date they left, extras tagged. On a phone it sits under the day strip; in the
// bento it is a tall tile that scrolls inside with a fade edge.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/widgets/state_pill.dart' show ClassState;
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/attendance_stats/attendance_stats.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/features/batches/widgets/batch_format.dart';
import 'package:attendance_alamin/features/classes/classes_entry.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
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
    final BhorThemeData b = context.bhor;
    final LocalDate today = ref.watch(todayProvider);
    final DayPlan? plan = ref.watch(todayDayPlanProvider(date)).value;
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
          const SizedBox(height: BhorSpace.s4),
          Container(height: 1, color: b.colors.line),
          const SizedBox(height: BhorSpace.s8),
        ],
        TileHeader(
          icon: BhorIcons.calendar,
          title: title,
          trailing: noClasses
              ? null
              : BhorButton(
                  label: l10n.todayAddExtra,
                  icon: BhorIcons.add,
                  variant: BhorButtonVariant.ghost,
                  size: BhorButtonSize.sm,
                  onPressed: () => showExtraClassSheet(context, date: date),
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
      body = const BhorSkeleton(height: 96, radius: 12);
    } else if (rows.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: BhorSpace.s16),
        child: _emptyDay(context, date),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: BhorSpace.s8),
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
    icon: BhorIcons.calendar,
    message: l10n.todayNoClassesDay,
    action: BhorButton(
      key: const ValueKey<String>('today-empty-add-extra'),
      label: l10n.todayAddExtra,
      icon: BhorIcons.add,
      variant: BhorButtonVariant.secondary,
      onPressed: () => showExtraClassSheet(context, date: date),
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
    final Color solid = context.bhor.colors.surface;
    final Color clear = solid.withValues(alpha: 0);
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
        padding: const EdgeInsets.only(bottom: BhorSpace.s16),
        itemCount: rows.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(height: BhorSpace.s8),
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
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
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
    final TextStyle titleStyle = b.type.heading.copyWith(decoration: strike);
    final TextStyle timeStyle = b.type.meta.copyWith(decoration: strike);

    final Color leadBg;
    final Color leadFg;
    final IconData leadIcon;
    if (taken) {
      leadBg = c.okBg;
      leadFg = c.ok;
      leadIcon = BhorIcons.check;
    } else if (running) {
      leadBg = c.accentTint;
      leadFg = c.accent;
      leadIcon = BhorIcons.clock;
    } else if (cancelled) {
      leadBg = c.surface2;
      leadFg = c.text2;
      leadIcon = BhorIcons.absent;
    } else if (dc.state == ClassState.extra) {
      leadBg = c.surface2;
      leadFg = c.text2;
      leadIcon = BhorIcons.add;
    } else if (dc.state == ClassState.moved) {
      leadBg = c.surface2;
      leadFg = c.text2;
      leadIcon = BhorIcons.refresh;
    } else {
      leadBg = c.surface2;
      leadFg = c.text2;
      leadIcon = BhorIcons.clock;
    }

    final AttendanceTally? tally = dc.tally;
    final List<Widget> meta = <Widget>[
      Text(fmt.timeRange(dc.startMin, dc.endMin), style: timeStyle),
      if (dc.batch.isTuition) const PrivateTag(),
      if (dc.state != null) _classStateTag(context, dc.state!),
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
      padding: const EdgeInsets.fromLTRB(BhorSpace.s12, BhorSpace.s8, BhorSpace.s4, BhorSpace.s8),
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
          const SizedBox(width: BhorSpace.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: BhorSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    batchLabel(l10n, dc.subjectName, dc.batch.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  const SizedBox(height: BhorSpace.s4),
                  Wrap(
                    spacing: BhorSpace.s8,
                    runSpacing: BhorSpace.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: meta,
                  ),
                  if (needsRoll) ...<Widget>[
                    const SizedBox(height: BhorSpace.s8),
                    BhorButton(
                      label: l10n.todayTakeAttendance,
                      variant: BhorButtonVariant.secondary,
                      size: BhorButtonSize.sm,
                      onPressed: () => openRollCall(context, dc.occ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Builder(
            builder: (BuildContext bc) => BhorIconButton(
              semanticLabel: l10n.todayClassOptions,
              icon: BhorIcons.overflowVertical,
              onPressed: () => showClassActionsSheet(context, occ: dc.occ, returnTo: Routes.today, anchor: bc),
            ),
          ),
        ],
      ),
    );

    return BhorPressable(
      onTap: () {
        if (cancelled || isFuture) {
          showClassActionsSheet(context, occ: dc.occ, returnTo: Routes.today);
        } else {
          openRollCall(context, dc.occ);
        }
      },
      semanticLabel: batchLabel(l10n, dc.subjectName, dc.batch.name),
      radius: BhorRadius.card,
      scaleOnPress: false,
      builder: (BuildContext context, BhorStates s) => Container(
        decoration: BoxDecoration(
          color: running ? c.accentTint : (s.hovered ? c.surface2 : null),
          borderRadius: BorderRadius.circular(BhorRadius.card),
        ),
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
    return BhorTag(
      label: text,
      tone: pending ? BhorTone.accent : BhorTone.ok,
      icon: pending ? BhorIcons.clock : BhorIcons.check,
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
    final BhorThemeData b = context.bhor;
    String label = '';
    for (final BatchSchedule s in schedules) {
      if (s.batch.id == moved.batchId) {
        label = batchLabel(l10n, s.subjectName, s.batch.name);
        break;
      }
    }
    final String when = '${fmt.dateShort(moved.newDate)} ${fmt.time(moved.newStartMin)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(BhorSpace.s12, BhorSpace.s8, BhorSpace.s12, BhorSpace.s8),
      child: Opacity(
        opacity: 0.75,
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(color: b.colors.surface2, shape: BoxShape.circle),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(BhorIcons.arrowRight, size: 20, color: b.colors.text2),
                ),
              ),
            ),
            const SizedBox(width: BhorSpace.s12),
            Expanded(
              child: Text(
                l10n.todayMovedAway(label, when),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: b.type.meta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Class state as a Bhor tag (icon + word, never colour alone).
Widget _classStateTag(BuildContext context, ClassState state) {
  final l10n = context.l10n;
  switch (state) {
    case ClassState.now:
      return BhorTag(label: l10n.uiClassNow, tone: BhorTone.accent, icon: BhorIcons.clock);
    case ClassState.moved:
      return BhorTag(label: l10n.uiClassMoved, tone: BhorTone.late, icon: BhorIcons.refresh);
    case ClassState.cancelled:
      return BhorTag(label: l10n.uiClassCancelled, tone: BhorTone.danger, icon: BhorIcons.absent);
    case ClassState.extra:
      return BhorTag(label: l10n.uiClassExtra, tone: BhorTone.neutral, icon: BhorIcons.add);
  }
}
