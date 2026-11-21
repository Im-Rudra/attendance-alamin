// App-specific pieces: BhorAttendanceToggle (উপস্থিত/অনুপস্থিত/দেরি),
// BhorEscalationBar (10-day dues bar, today ringed), BhorMoney, BhorStatText.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/tokens.dart' show AttendanceKind;
import 'package:attendance_alamin/core/format/app_format.dart';

/// Three-way attendance control for one student.
/// Usage: `BhorAttendanceToggle(value: AttendanceKind.present, onChanged: f)`.
class BhorAttendanceToggle extends StatelessWidget {
  const BhorAttendanceToggle({super.key, required this.value, required this.onChanged, this.compact = false});

  static const List<AttendanceKind> kinds = <AttendanceKind>[
    AttendanceKind.present,
    AttendanceKind.absent,
    AttendanceKind.late,
  ];

  final AttendanceKind? value;
  final ValueChanged<AttendanceKind>? onChanged;

  /// Short labels (P/A/L style) and 36 tall.
  final bool compact;

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
    (Color, Color, Color) look(AttendanceKind k) => switch (k) {
          AttendanceKind.present => (c.okBg, c.ok, c.ok),
          AttendanceKind.absent => (c.absent, c.onAbsent, c.absent),
          AttendanceKind.late => (c.lateBg, c.lateText, c.lateText),
          AttendanceKind.leave => (c.surface2, c.text2, c.line),
        };
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: <Widget>[
          for (int i = 0; i < kinds.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            _wrap(
              compact,
              BhorPressable(
                onTap: onChanged == null ? null : () => onChanged!(kinds[i]),
                selected: value == kinds[i],
                inMutuallyExclusiveGroup: true,
                semanticLabel: fullLabel(kinds[i]),
                excludeChildSemantics: true,
                radius: BhorRadius.chip,
                builder: (BuildContext context, BhorStates s) {
                  final bool sel = value == kinds[i];
                  final (Color bg, Color fg, Color edge) = look(kinds[i]);
                  return AnimatedContainer(
                    duration: BhorMotion.fast,
                    height: compact ? BhorSize.compact : BhorSize.control,
                    constraints: const BoxConstraints(minWidth: BhorSize.minTap),
                    padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? bg : (s.hovered ? c.surface2 : c.surface),
                      borderRadius: BorderRadius.circular(BhorRadius.chip),
                      border: Border.all(color: sel ? edge : c.line),
                    ),
                    child: Text(
                      label(kinds[i]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (sel ? b.type.bodyStrong : b.type.body).copyWith(color: sel ? fg : c.text2),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _wrap(bool compact, Widget child) => compact ? child : Expanded(child: child);
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
                        color: (day > 10 || i <= day) ? c.segment(day > 10 ? 11 : i) : c.surface2,
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

/// A stat: big value (text or money) over a meta label.
/// Usage: `BhorStatText(label: 'উপস্থিত', value: '২৪')`, `BhorStatText.money(label: 'বকেয়া', amount: 4500)`.
class BhorStatText extends StatelessWidget {
  const BhorStatText({super.key, required this.label, required String this.value, this.color})
      : amount = null;

  const BhorStatText.money({super.key, required this.label, required int this.amount, this.color})
      : value = null;

  final String label;
  final String? value;
  final int? amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final TextStyle stat = color == null ? b.type.stat : b.type.stat.copyWith(color: color);
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (amount != null)
            BhorMoney(amount!, style: stat, muteSign: true)
          else
            Text(value!, maxLines: 1, style: stat),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.meta),
        ],
      ),
    );
  }
}
