// Desktop week grid (UX 2g, 3b): 7 day columns x an hour range that auto-fits
// the classes (1 h before the earliest, 1 h after the latest), faint 15-minute
// lines, hour lines, an accent now-line. Cancelled blocks are dashed and struck
// through, extras carry a "+", moved-in classes a "↻", and a moved class leaves
// a ghost outline at its old time. Two classes of one batch on a day are two
// blocks, each with its own time. Keyboard: arrows move between blocks, Enter
// opens the actions, N starts an extra class, [ and ] change the week.

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/widgets/dashed_border.dart';
import 'package:attendance_alamin/app/widgets/state_pill.dart' show ClassState;
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/classes/widgets/class_actions_sheet.dart';
import 'package:attendance_alamin/features/classes/widgets/extra_class_sheet.dart';

const double _kLabelWidth = 64;

/// Desktop week grid (7 columns x hours).
class WeekGrid extends StatefulWidget {
  const WeekGrid({super.key, required this.weekStart, this.onSelectOcc});

  final LocalDate weekStart;

  /// Called with the occurrence id of a clicked / Enter-ed block. When null the
  /// class-actions sheet opens instead.
  final ValueChanged<String>? onSelectOcc;

  @override
  State<WeekGrid> createState() => _WeekGridState();
}

class _Block {
  const _Block(this.dc, this.day, this.date);

  final DayClass dc;
  final int day;
  final LocalDate date;
}

class _Ghost {
  const _Ghost(this.moved, this.day, this.durationMin);

  final MovedAway moved;
  final int day;
  final int durationMin;
}

class _WeekGridState extends State<WeekGrid> {
  int _offset = 0;
  String? _selectedOcc;
  final FocusNode _focus = FocusNode(debugLabel: 'WeekGrid');
  List<_Block> _blocks = const <_Block>[];
  LocalDate _today = const LocalDate(2000, 1, 1);

  LocalDate get _start => widget.weekStart.addDays(_offset * 7);

  @override
  void didUpdateWidget(WeekGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart) {
      _offset = 0;
      _selectedOcc = null;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _shiftWeek(int by) {
    setState(() {
      _offset += by;
      _selectedOcc = null;
    });
  }

  void _open(String occ) {
    final ValueChanged<String>? cb = widget.onSelectOcc;
    if (cb != null) {
      cb(occ);
    } else {
      showClassActionsSheet(context, occ: occ);
    }
  }

  _Block? get _selectedBlock {
    for (final _Block b in _blocks) {
      if (b.dc.occ == _selectedOcc) return b;
    }
    return null;
  }

  void _newExtra() {
    final _Block? sel = _selectedBlock;
    final LocalDate today = _today;
    final LocalDate date = sel?.date ?? ((today.isBefore(_start) || today.isAfter(_start.addDays(6))) ? _start : today);
    showExtraClassSheet(context, date: date, startMin: sel?.dc.startMin);
  }

  void _select(String occ) => setState(() => _selectedOcc = occ);

  void _move(int dx, int dy) {
    if (_blocks.isEmpty) return;
    final _Block? cur = _selectedBlock;
    if (cur == null) {
      _select(_blocks.first.dc.occ);
      return;
    }
    if (dy != 0) {
      final List<_Block> col = <_Block>[for (final _Block b in _blocks) if (b.day == cur.day) b];
      final int i = col.indexWhere((_Block b) => b.dc.occ == cur.dc.occ);
      final int j = i + dy;
      if (j >= 0 && j < col.length) _select(col[j].dc.occ);
      return;
    }
    for (int d = cur.day + dx; d >= 0 && d < 7; d += dx) {
      final List<_Block> col = <_Block>[for (final _Block b in _blocks) if (b.day == d) b];
      if (col.isEmpty) continue;
      _Block best = col.first;
      for (final _Block b in col) {
        if ((b.dc.startMin - cur.dc.startMin).abs() < (best.dc.startMin - cur.dc.startMin).abs()) best = b;
      }
      _select(best.dc.occ);
      return;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey k = event.logicalKey;
    if (k == LogicalKeyboardKey.bracketLeft) {
      _shiftWeek(-1);
    } else if (k == LogicalKeyboardKey.bracketRight) {
      _shiftWeek(1);
    } else if (k == LogicalKeyboardKey.keyN) {
      _newExtra();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _move(-1, 0);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _move(1, 0);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _move(0, -1);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _move(0, 1);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      final String? occ = _selectedOcc;
      if (occ == null) return KeyEventResult.ignored;
      _open(occ);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _emptyCellTap(TapUpDetails details, LocalDate date, int startMin) async {
    _focus.requestFocus();
    final String label = context.l10n.clsEmptyCellAction;
    final bool? choice = await showBhorPanel<bool>(
      context,
      kind: BhorPanelKind.list,
      width: 380,
      scroll: false,
      builder: (BuildContext ctx) => BhorListRow(
        leading: const Icon(BhorIcons.add),
        title: label,
        divider: false,
        onTap: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (choice == true && mounted) {
      await showExtraClassSheet(context, date: date, startMin: startMin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) => _focus.requestFocus(),
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? _) => _buildGrid(context, ref),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, LocalDate today) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final BhorThemeData b = context.bhor;
    final LocalDate start = _start;
    return Padding(
      padding: const EdgeInsets.only(bottom: BhorSpace.s4),
      child: Wrap(
        spacing: BhorSpace.s4,
        runSpacing: BhorSpace.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          BhorIconButton(
            semanticLabel: l10n.clsPrevWeek,
            icon: BhorIcons.chevronLeft,
            onPressed: () => _shiftWeek(-1),
          ),
          Text(
            '${fmt.dateShort(start)} – ${fmt.dateShort(start.addDays(6))}',
            style: b.type.heading,
          ),
          BhorIconButton(
            semanticLabel: l10n.clsNextWeek,
            icon: BhorIcons.chevronRight,
            onPressed: () => _shiftWeek(1),
          ),
          BhorButton(
            label: l10n.commonToday,
            variant: BhorButtonVariant.ghost,
            size: BhorButtonSize.sm,
            onPressed: () => setState(() {
              _offset = (widget.weekStart.daysUntil(today) / 7).floor();
              _selectedOcc = null;
            }),
          ),
          BhorButton(
            label: l10n.clsAddExtraButton,
            variant: BhorButtonVariant.secondary,
            size: BhorButtonSize.sm,
            onPressed: _newExtra,
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final BhorColors colors = context.bhor.colors;
    final LocalDate today = ref.watch(todayProvider);
    _today = today;
    final int nowMin = ref.watch(nowMinutesProvider);
    final AsyncValue<List<DayPlan>> async = ref.watch(weekPlanProvider(_start));

    final Widget header = _header(context, today);
    if (async.hasError) {
      return Column(children: <Widget>[header, Expanded(child: Center(child: Text(l10n.commonLoadingFailed)))]);
    }
    if (!async.hasValue) {
      return Column(
        children: <Widget>[header, const Expanded(child: Center(child: BhorSpinner(size: 28)))],
      );
    }
    final List<DayPlan> plans = async.requireValue;

    final List<_Block> blocks = <_Block>[
      for (int d = 0; d < plans.length; d++)
        for (final DayClass c in plans[d].classes) _Block(c, d, plans[d].date),
    ];
    final List<_Ghost> ghosts = <_Ghost>[];
    for (int d = 0; d < plans.length; d++) {
      for (final MovedAway m in plans[d].movedAway) {
        int dur = 60;
        for (final _Block b in blocks) {
          if (b.dc.occ == m.occ) dur = b.dc.endMin - b.dc.startMin;
        }
        ghosts.add(_Ghost(m, d, dur));
      }
    }
    _blocks = blocks;

    if (blocks.isEmpty && ghosts.isEmpty) {
      return Column(
        children: <Widget>[
          header,
          Expanded(
            child: BhorEmptyState(
              icon: BhorIcons.calendar,
              title: l10n.clsWeekEmpty,
              action: BhorButton(
                label: l10n.clsWeekEmptyAction,
                onPressed: () => GoRouter.maybeOf(context)?.go(Routes.batches),
              ),
            ),
          ),
        ],
      );
    }

    int minStart = 1440;
    int maxEnd = 0;
    for (final _Block b in blocks) {
      minStart = math.min(minStart, b.dc.startMin);
      maxEnd = math.max(maxEnd, b.dc.endMin);
    }
    for (final _Ghost g in ghosts) {
      minStart = math.min(minStart, g.moved.originalStartMin);
      maxEnd = math.max(maxEnd, g.moved.originalStartMin + g.durationMin);
    }
    int fromH = math.max(0, minStart ~/ 60 - 1);
    int toH = math.min(24, (maxEnd + 59) ~/ 60 + 1);
    if (toH - fromH < 4) {
      toH = math.min(24, fromH + 4);
      fromH = math.max(0, toH - 4);
    }
    final int hours = toH - fromH;
    final int todayIdx = _start.daysUntil(today);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints outer) {
        final Widget dayHeaders = _dayHeaders(context, plans, today);
        final Widget body = LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double hourH = math.max(48.0, (c.hasBoundedHeight ? c.maxHeight : 560) / hours);
            return SingleChildScrollView(
              child: SizedBox(
                height: hourH * hours,
                child: _gridBody(
                  context,
                  hourH: hourH,
                  fromH: fromH,
                  toH: toH,
                  blocks: blocks,
                  ghosts: ghosts,
                  plans: plans,
                  todayIdx: todayIdx,
                  nowMin: nowMin,
                  colors: colors,
                ),
              ),
            );
          },
        );
        if (outer.hasBoundedHeight) {
          return Column(children: <Widget>[header, dayHeaders, Expanded(child: body)]);
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[header, dayHeaders, SizedBox(height: 560, child: body)],
        );
      },
    );
  }

  Widget _dayHeaders(BuildContext context, List<DayPlan> plans, LocalDate today) {
    final BhorThemeData b = context.bhor;
    final fmt = context.fmt;
    return Padding(
      padding: const EdgeInsets.only(bottom: BhorSpace.s4),
      child: Row(
        children: <Widget>[
          const SizedBox(width: _kLabelWidth),
          for (final DayPlan p in plans)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
                decoration: BoxDecoration(
                  color: p.date == today ? b.colors.accentTint : null,
                  borderRadius: BorderRadius.circular(BhorRadius.chip),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      fmt.weekdayShort(p.date.isoWeekday),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: b.type.label.copyWith(color: b.colors.text2),
                    ),
                    Text(
                      fmt.digits('${p.date.day}'),
                      style: (p.date == today ? b.type.heading : b.type.body)
                          .copyWith(color: p.date == today ? b.colors.accent : b.colors.text),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gridBody(
    BuildContext context, {
    required double hourH,
    required int fromH,
    required int toH,
    required List<_Block> blocks,
    required List<_Ghost> ghosts,
    required List<DayPlan> plans,
    required int todayIdx,
    required int nowMin,
    required BhorColors colors,
  }) {
    final fmt = context.fmt;
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final double totalH = hourH * (toH - fromH);
    double yOf(int minute) => (minute - fromH * 60) / 60 * hourH;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double colW = math.max(0.0, (c.maxWidth - _kLabelWidth) / 7);
        final List<Widget> children = <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                fromMin: fromH * 60,
                toMin: toH * 60,
                hourH: hourH,
                labelW: _kLabelWidth,
                colW: colW,
                hour: colors.line,
                quarter: colors.line.withValues(alpha: colors.line.a * 0.5),
              ),
            ),
          ),
          for (int h = fromH; h < toH; h++)
            Positioned(
              left: 0,
              top: yOf(h * 60) + 2,
              width: _kLabelWidth - 8,
              child: Text(
                fmt.time(h * 60).replaceFirst(RegExp(':(00|০০)'), ''),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: b.type.caption,
              ),
            ),
          // Empty-cell hit areas (blocks sit above and take their own taps).
          for (int d = 0; d < 7 && d < plans.length; d++)
            Positioned(
              left: _kLabelWidth + d * colW,
              top: 0,
              width: colW,
              height: totalH,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (TapUpDetails details) {
                  final int raw = (fromH * 60 + details.localPosition.dy / hourH * 60).floor();
                  _emptyCellTap(details, plans[d].date, (raw ~/ 15) * 15);
                },
              ),
            ),
          for (final _Ghost g in ghosts)
            Positioned(
              left: _kLabelWidth + g.day * colW + 2,
              top: yOf(g.moved.originalStartMin) + 1,
              width: math.max(0.0, colW - 4),
              height: math.max(24.0, g.durationMin / 60 * hourH - 2),
              child: _GhostBlock(
                text: l10n.clsMovedAway('${fmt.dateShort(g.moved.newDate)} ${fmt.time(g.moved.newStartMin)}'),
              ),
            ),
          for (final _Block b in blocks)
            Positioned(
              left: _kLabelWidth + b.day * colW + 2,
              top: yOf(b.dc.startMin) + 1,
              width: math.max(0.0, colW - 4),
              height: math.max(24.0, (b.dc.endMin - b.dc.startMin) / 60 * hourH - 2),
              child: _ClassBlock(
                dc: b.dc,
                selected: b.dc.occ == _selectedOcc,
                onTap: () {
                  _focus.requestFocus();
                  _select(b.dc.occ);
                  _open(b.dc.occ);
                },
              ),
            ),
          if (todayIdx >= 0 && todayIdx < 7 && nowMin >= fromH * 60 && nowMin <= toH * 60)
            Positioned(
              left: _kLabelWidth + todayIdx * colW,
              top: yOf(nowMin) - 1,
              width: colW,
              height: 2,
              child: IgnorePointer(child: ColoredBox(color: colors.accent)),
            ),
        ];
        return Stack(clipBehavior: Clip.hardEdge, children: children);
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.fromMin,
    required this.toMin,
    required this.hourH,
    required this.labelW,
    required this.colW,
    required this.hour,
    required this.quarter,
  });

  final int fromMin;
  final int toMin;
  final double hourH;
  final double labelW;
  final double colW;
  final Color hour;
  final Color quarter;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint hourPaint = Paint()
      ..color = hour
      ..strokeWidth = 1;
    // Half-hour lines at line@50%; the quarter-hour ones even lighter.
    final Paint quarterPaint = Paint()
      ..color = quarter
      ..strokeWidth = 1;
    final Paint faintPaint = Paint()
      ..color = quarter.withValues(alpha: quarter.a * 0.5)
      ..strokeWidth = 1;
    for (int m = fromMin; m <= toMin; m += 15) {
      final double y = (m - fromMin) / 60 * hourH;
      canvas.drawLine(
        Offset(labelW, y),
        Offset(size.width, y),
        m % 60 == 0 ? hourPaint : (m % 30 == 0 ? quarterPaint : faintPaint),
      );
    }
    for (int d = 0; d <= 7; d++) {
      final double x = labelW + d * colW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), hourPaint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.fromMin != fromMin ||
      old.toMin != toMin ||
      old.hourH != hourH ||
      old.labelW != labelW ||
      old.colW != colW ||
      old.hour != hour ||
      old.quarter != quarter;
}

class _ClassBlock extends StatelessWidget {
  const _ClassBlock({required this.dc, required this.selected, required this.onTap});

  final DayClass dc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final bool cancelled = dc.cancelled;
    final Color fg = cancelled ? c.text2 : c.accent;
    final TextStyle base = b.type.label.copyWith(
      color: fg,
      decoration: cancelled ? TextDecoration.lineThrough : null,
      decorationColor: fg,
    );
    // State marks are Material icons: Hind Siliguri has no ＋ ↻ ✓ glyphs
    // (they rendered as tofu boxes, QA-17).
    final double iconSize = (base.fontSize ?? 12) + 2;
    final List<InlineSpan> marks = <InlineSpan>[
      if (!cancelled && dc.state == ClassState.extra)
        _mark(BhorIcons.add, fg, iconSize, const Key('week-block-extra')),
      if (!cancelled && dc.state == ClassState.moved)
        _mark(BhorIcons.refresh, fg, iconSize, const Key('week-block-moved')),
      if (!cancelled && dc.taken) _mark(BhorIcons.check, fg, iconSize, const Key('week-block-taken')),
    ];
    final String time = fmt.timeRange(dc.startMin, dc.endMin);
    final String name = '${dc.subjectName} — ${dc.batch.name}';
    final String label = l10n.clsBlockLabel(dc.subjectName, dc.batch.name, time);
    final ClassState? st = dc.state;
    final String stateLabel = st == null || st == ClassState.now
        ? ''
        : ', ${st == ClassState.cancelled ? l10n.uiClassCancelled : st == ClassState.moved ? l10n.uiClassMoved : l10n.uiClassExtra}';

    final Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(BhorRadius.chip),
      child: BhorPressable(
      onTap: onTap,
      radius: BhorRadius.chip,
      scaleOnPress: false,
      showFocusRing: false,
      builder: (BuildContext context, BhorStates s) => AnimatedContainer(
        duration: BhorMotion.of(context, BhorMotion.fast),
        curve: BhorMotion.ease,
        padding: const EdgeInsets.fromLTRB(BhorSpace.s8, BhorSpace.s4, BhorSpace.s4, BhorSpace.s4),
        decoration: BoxDecoration(
          color: cancelled
              ? null
              : (s.hovered ? Color.alphaBlend(c.accent.withValues(alpha: 0.08), c.accentTint) : c.accentTint),
          borderRadius: BorderRadius.circular(BhorRadius.chip),
          // Soft fill and a 3 px leading bar instead of an outline; only the
          // selected block gets a ring.
          border: selected ? Border.all(color: c.accent, width: 2) : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
            if (!cancelled)
              Positioned(
                left: -BhorSpace.s8,
                top: -BhorSpace.s4,
                bottom: -BhorSpace.s4,
                width: 3,
                child: ColoredBox(color: c.accent),
              ),
            ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (marks.isEmpty)
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: base)
                  else
                    Text.rich(
                      TextSpan(children: <InlineSpan>[...marks, TextSpan(text: name)]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base,
                    ),
                  Text(time, maxLines: 1, overflow: TextOverflow.ellipsis, style: base),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '$label$stateLabel',
      excludeSemantics: true,
      child: cancelled
          ? DashedBorder(color: c.text2, radius: BhorRadius.chip, child: content)
          : content,
    );
  }
}

/// One state mark before a block's name: an icon and a small gap.
WidgetSpan _mark(IconData icon, Color color, double size, Key key) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 2),
        child: Icon(icon, key: key, size: size, color: color),
      ),
    );

class _GhostBlock extends StatelessWidget {
  const _GhostBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final TextStyle style = b.type.caption;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: DashedBorder(
          color: b.colors.text2,
          radius: BhorRadius.chip,
          child: Padding(
            padding: const EdgeInsets.all(BhorSpace.s4),
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minHeight: 0,
                maxHeight: double.infinity,
                // "→ {when}": the arrow is an icon (no arrow glyph in Hind
                // Siliguri, QA-17).
                child: Text.rich(
                  TextSpan(children: <InlineSpan>[
                    _mark(BhorIcons.arrowRight, b.colors.text2, (style.fontSize ?? 11) + 2,
                        const Key('week-ghost-arrow')),
                    TextSpan(text: text),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
