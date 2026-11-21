// App-specific pieces (docs/council/13-fluid-ui-spec.md):
// BhorAttendanceToggle (soft pill track, a coloured thumb glides between
// উপস্থিত / অনুপস্থিত / দেরি; labelled on wide rows, icon-only ✓ ✕ clock in
// dense phone rows), BhorStepper (± with a counting value),
// BhorEscalationBar (10-day dues bar, today ringed), BhorMoney, BhorStatText,
// BhorClashCard (clashing classes with fix buttons).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_button.dart';
import 'package:attendance_alamin/app/ds/components/bhor_motion.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/tokens.dart' show AttendanceKind;
import 'package:attendance_alamin/core/format/app_format.dart';

/// Three-way attendance control for one student: a soft pill track whose
/// coloured thumb (ok / absent / late tint) glides to the chosen status with
/// the spring; the icon / text colour follows. Fills the width when
/// labelled; [compact] uses short labels, [iconOnly] shows ✓ ✕ clock for
/// dense phone rows.
/// Usage: `BhorAttendanceToggle(value: AttendanceKind.present, onChanged: f)`,
/// `BhorAttendanceToggle(value: v, iconOnly: true, onChanged: f)`.
class BhorAttendanceToggle extends StatelessWidget {
  const BhorAttendanceToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.iconOnly = false,
  });

  static const List<AttendanceKind> kinds = <AttendanceKind>[
    AttendanceKind.present,
    AttendanceKind.absent,
    AttendanceKind.late,
  ];

  final AttendanceKind? value;
  final ValueChanged<AttendanceKind>? onChanged;

  /// Short labels and 38 tall, sized to its content.
  final bool compact;

  /// Icons only (✓ ✕ clock), sized to its content.
  final bool iconOnly;

  static IconData iconOf(AttendanceKind k) => switch (k) {
        AttendanceKind.present => BhorIcons.present,
        AttendanceKind.absent => BhorIcons.absent,
        AttendanceKind.late => BhorIcons.late,
        AttendanceKind.leave => BhorIcons.leave,
      };

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    String label(AttendanceKind k) => switch (k) {
          AttendanceKind.present => compact ? l10n.uiAttPresentShort : l10n.uiAttPresent,
          AttendanceKind.absent => compact ? l10n.uiAttAbsentShort : l10n.uiAttAbsent,
          AttendanceKind.late => compact ? l10n.uiAttLateShort : l10n.uiAttLate,
          AttendanceKind.leave => compact ? l10n.uiAttExcusedShort : l10n.uiAttExcused,
        };
    String fullLabel(AttendanceKind k) => switch (k) {
          AttendanceKind.present => l10n.uiAttPresent,
          AttendanceKind.absent => l10n.uiAttAbsent,
          AttendanceKind.late => l10n.uiAttLate,
          AttendanceKind.leave => l10n.uiAttExcused,
        };
    (Color, Color) look(AttendanceKind k) => switch (k) {
          AttendanceKind.present => (c.okBg, c.ok),
          AttendanceKind.absent => (c.absentBg, c.absentText),
          AttendanceKind.late => (c.lateBg, c.late),
          AttendanceKind.leave => (c.soft2, c.text2),
        };
    final bool dense = compact || iconOnly;
    final double h = dense ? BhorSize.compact : BhorSize.control;
    final int sel = value == null ? -1 : kinds.indexOf(value!);
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);

    Widget track(double segW) {
      final (Color thumbFill, _) = look(sel < 0 ? AttendanceKind.present : kinds[sel]);
      return Container(
        height: h,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(BhorRadius.pill)),
        child: Stack(
          children: <Widget>[
            AnimatedPositioned(
              duration: BhorMotion.of(context, BhorMotion.glide),
              curve: BhorMotion.curveOf(context, BhorMotion.spring),
              left: (sel < 0 ? 0 : sel) * segW,
              top: 0,
              bottom: 0,
              width: segW,
              child: AnimatedOpacity(
                opacity: sel < 0 ? 0 : 1,
                duration: fast,
                child: AnimatedContainer(
                  duration: fast,
                  curve: BhorMotion.ease,
                  decoration: BoxDecoration(color: thumbFill, borderRadius: BorderRadius.circular(BhorRadius.pill)),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                for (int i = 0; i < kinds.length; i++)
                  SizedBox(
                    width: segW,
                    child: BhorPressable(
                      onTap: onChanged == null
                          ? null
                          : () {
                              if (value != kinds[i]) HapticFeedback.selectionClick();
                              onChanged!(kinds[i]);
                            },
                      selected: value == kinds[i],
                      inMutuallyExclusiveGroup: true,
                      semanticLabel: fullLabel(kinds[i]),
                      excludeChildSemantics: true,
                      radius: (h - 6) / 2,
                      pressScale: 0.94,
                      builder: (BuildContext context, BhorStates s) {
                        final bool on = i == sel;
                        final Color fg = on ? look(kinds[i]).$2 : (s.hovered ? c.text : c.text2);
                        final Widget glyph = TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: fg),
                          duration: fast,
                          builder: (BuildContext context, Color? col, Widget? _) =>
                              Icon(iconOf(kinds[i]), size: dense ? BhorIconSize.chip : BhorIconSize.inline, color: col),
                        );
                        return Center(
                          child: iconOnly
                              ? glyph
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (!compact) ...<Widget>[glyph, const SizedBox(width: 6)],
                                    Flexible(
                                      child: AnimatedDefaultTextStyle(
                                        duration: fast,
                                        style: (on ? b.type.bodyStrong : b.type.body).copyWith(color: fg),
                                        child: Text(label(kinds[i]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final Widget body = dense
        ? track(iconOnly ? 42 : 46)
        : LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) =>
                track(((box.maxWidth.isFinite ? box.maxWidth : 360) - 6) / kinds.length),
          );
    return Semantics(container: true, explicitChildNodes: true, child: body);
  }
}

/// Number stepper: soft track, surface − / + buttons (press scale .9), the
/// value counts up / down. Usage:
/// `BhorStepper(value: n, min: 1, max: 12, onChanged: (v) => ..., semanticLabel: 'মাস')`.
class BhorStepper extends StatelessWidget {
  const BhorStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999999,
    this.step = 1,
    this.semanticLabel,
    this.format,
    this.decreaseLabel,
    this.increaseLabel,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;
  final int step;
  final String? semanticLabel;

  /// Formats the value (default: locale digits).
  final String Function(int value)? format;

  /// Accessible names of the buttons (default "−" / "+").
  final String? decreaseLabel;
  final String? increaseLabel;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool enabled = onChanged != null;
    Widget button(IconData icon, String label, int next, bool can) => BhorPressable(
          onTap: enabled && can ? () => onChanged!(next.clamp(min, max)) : null,
          semanticLabel: label,
          excludeChildSemantics: true,
          radius: 11,
          pressScale: BhorMotion.pressScaleSmall,
          builder: (BuildContext context, BhorStates s) => AnimatedOpacity(
            opacity: enabled && can ? 1 : 0.4,
            duration: BhorMotion.of(context, BhorMotion.fast),
            child: AnimatedContainer(
              duration: BhorMotion.of(context, BhorMotion.instant),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: s.hovered || s.pressed ? Color.alphaBlend(c.pressShade, c.surface) : c.surface,
                borderRadius: BorderRadius.circular(11),
                boxShadow: c.thumbShadow,
              ),
              child: Icon(icon, size: BhorIconSize.chip, color: c.text),
            ),
          ),
        );
    return Semantics(
      container: true,
      label: semanticLabel,
      value: format?.call(value) ?? context.fmt.number(value),
      child: Container(
        height: BhorSize.control,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(BhorRadius.control)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            button(BhorIcons.minus, decreaseLabel ?? '−', value - step, value > min),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s8),
                child: ExcludeSemantics(
                  child: BhorCountUp(
                    value: value,
                    from: value,
                    format: format == null ? null : (num v) => format!(v.round()),
                    style: BhorType.tabular(b.type.heading),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            button(BhorIcons.add, increaseLabel ?? '+', value + step, value < max),
          ],
        ),
      ),
    );
  }
}

/// Thin 5px, 10-segment dues escalation bar; [day] is the day since due
/// (1..10, beyond 10 = overdue, 0 = not due). Today's segment is ringed.
/// Usage: `BhorEscalationBar(day: 7)`.
class BhorEscalationBar extends StatelessWidget {
  const BhorEscalationBar({super.key, required this.day});

  final int day;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final String label =
        day > 10 ? l10n.uiEscalationBeyond : l10n.a11yEscalationDay(fmt.number(day < 0 ? 0 : day));
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: 11,
        child: Row(
          children: <Widget>[
            for (int i = 1; i <= 10; i++) ...<Widget>[
              if (i > 1) const SizedBox(width: 2),
              Expanded(
                child: Center(
                  child: Container(
                    height: i == day ? 11 : 5,
                    padding: i == day ? const EdgeInsets.all(2) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(i == day ? 4 : 2.5),
                      border: i == day ? Border.all(color: c.text, width: 1.5) : null,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: (day > 10 || i <= day) ? c.segment(day > 10 ? 11 : i) : c.soft,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Money: "৳" + thin space + lakh-grouped digits, the sign at 70% size.
/// In stats ([muteSign]) the sign is text2. Usage: `BhorMoney(1500, style: b.type.stat)`.
/// For a counting amount use `BhorCountUp.money(...)`.
class BhorMoney extends StatelessWidget {
  const BhorMoney(this.amount, {super.key, this.style, this.muteSign = false, this.color});

  final int amount;
  final TextStyle? style;
  final bool muteSign;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final AppFormat fmt = context.fmt;
    TextStyle base = BhorType.tabular(style ?? b.type.bodyStrong);
    if (color != null) base = base.copyWith(color: color);
    final double size = base.fontSize ?? 14;
    final String digits = fmt.number(amount.abs());
    final String text = fmt.money(amount);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(children: <InlineSpan>[
          if (amount < 0) const TextSpan(text: '-'),
          TextSpan(
            text: AppFormat.takaSign,
            style: TextStyle(fontSize: size * 0.7, color: muteSign ? b.colors.text2 : null),
          ),
          const TextSpan(text: AppFormat.takaGap),
          TextSpan(text: digits),
        ]),
        style: base,
        maxLines: 1,
      ),
    );
  }
}

/// A stat: big value (text or money) over a meta label. [countUp] counts
/// money / numeric values up on first appearance and rolls on change.
/// Usage: `BhorStatText(label: 'উপস্থিত', value: '২৪')`,
/// `BhorStatText.money(label: 'বকেয়া', amount: 4500, countUp: true)`,
/// `BhorStatText.count(label: 'উপস্থিত', count: 24)`.
class BhorStatText extends StatelessWidget {
  const BhorStatText({super.key, required this.label, required String this.value, this.color})
      : amount = null,
        count = null,
        countUp = false;

  const BhorStatText.money({super.key, required this.label, required int this.amount, this.color, this.countUp = false})
      : value = null,
        count = null;

  /// A counting integer (locale digits).
  const BhorStatText.count({super.key, required this.label, required int this.count, this.color})
      : value = null,
        amount = null,
        countUp = true;

  final String label;
  final String? value;
  final int? amount;
  final int? count;
  final Color? color;
  final bool countUp;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final TextStyle stat = color == null ? b.type.stat : b.type.stat.copyWith(color: color);
    final Widget big;
    if (amount != null) {
      big = countUp ? BhorCountUp.money(amount: amount!, style: stat, muteSign: true) : BhorMoney(amount!, style: stat, muteSign: true);
    } else if (count != null) {
      big = BhorCountUp(value: count!, style: stat);
    } else {
      big = Text(value!, maxLines: 1, style: stat);
    }
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          big,
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
        ],
      ),
    );
  }
}

/// One fix offered by a [BhorClashCard].
class BhorClashFix {
  const BhorClashFix({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;

  /// The recommended fix (danger-styled button).
  final bool primary;
}

/// The red "classes clash" card: the clashing lines, "+N more" and 1-3 fix
/// buttons. A live region, so it is announced when it appears.
/// Usage: `BhorClashCard(lines: ['ফিজিক্স এ, ৪টা-৫টা'], fixes: [BhorClashFix(label: 'সময় বদলান', onTap: f)])`.
class BhorClashCard extends StatelessWidget {
  const BhorClashCard({super.key, required this.lines, this.moreCount = 0, this.fixes = const <BhorClashFix>[]});

  final List<String> lines;
  final int moreCount;
  final List<BhorClashFix> fixes;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final Color on = b.colors.danger;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: b.colors.dangerBg,
          borderRadius: BorderRadius.circular(BhorRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(BhorIcons.warningFill, color: on, size: BhorIconSize.nav),
                  const SizedBox(width: BhorSpace.s8),
                  Expanded(child: Text(l10n.uiConflictTitle, style: b.type.heading.copyWith(color: on))),
                ],
              ),
              const SizedBox(height: BhorSpace.s8),
              for (final String line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: BhorSpace.s4),
                  child: Text(line, style: b.type.body.copyWith(color: on)),
                ),
              if (moreCount > 0)
                Text(l10n.uiConflictMore(context.fmt.number(moreCount)), style: b.type.label.copyWith(color: on)),
              if (fixes.isNotEmpty) ...<Widget>[
                const SizedBox(height: BhorSpace.s8),
                Wrap(
                  spacing: BhorSpace.s8,
                  runSpacing: BhorSpace.s8,
                  children: <Widget>[
                    for (final BhorClashFix f in fixes)
                      BhorButton(
                        label: f.label,
                        variant: f.primary ? BhorButtonVariant.danger : BhorButtonVariant.secondary,
                        onPressed: f.onTap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
