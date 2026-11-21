// One roll-call row (UX 2b): a surface card with the student and the gliding
// attendance toggle (present / absent / late). Tapping the name still flips
// present/absent for speed; long-press / right-click / the options button open
// the status panel (excused, note). Absent and late tint the row and add a
// 3 px edge stripe, so the state never relies on colour alone.

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_parts.dart';

class RollRow extends StatelessWidget {
  const RollRow({
    super.key,
    required this.name,
    required this.roll,
    required this.status,
    this.dense = false,
    this.enabled = true,
    this.focused = false,
    this.onToggle,
    this.onSet,
    this.onMenu,
  });

  final String name;
  final int roll;
  final AttendanceStatus status;

  /// Desktop strip (56dp, roll number in place of the avatar) instead of the
  /// phone card (64dp).
  final bool dense;

  /// False for a future date or an archived batch: nothing reacts.
  final bool enabled;

  /// The keyboard cursor is on this row.
  final bool focused;

  /// Tap on the name: present <-> absent.
  final VoidCallback? onToggle;

  /// A segment of the attendance toggle was chosen.
  final ValueChanged<AttendanceStatus>? onSet;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final String statusText = status.label(l10n);
    final String rollText = fmt.number(roll);
    final VoidCallback? tap = enabled ? onToggle : null;
    final VoidCallback? menu = enabled ? onMenu : null;
    final String hint = status == AttendanceStatus.absent ? l10n.a11yHintMarkPresent : l10n.a11yHintMarkAbsent;
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);

    // Row tint and edge stripe per status; the row stays a surface card.
    final (Color fill, Color stripe) = switch (status) {
      AttendanceStatus.present => (c.surface, const Color(0x00000000)),
      AttendanceStatus.absent => (c.absentBg, c.absentText),
      AttendanceStatus.late => (c.lateBg, c.late),
      AttendanceStatus.leave => (c.soft, c.text3),
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final bool menuButton = dense && box.maxWidth >= 360 && menu != null;
        final bool labelled = dense && box.maxWidth >= 460;

        final Widget info = Row(
          children: <Widget>[
            if (dense)
              SizedBox(
                width: 32,
                child: Text(rollText, maxLines: 1, style: BhorType.tabular(b.type.meta)),
              )
            else ...<Widget>[
              BhorAvatar(name: name, size: 40),
              const SizedBox(width: BhorSpace.s12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: b.type.bodyStrong.copyWith(color: c.text),
                  ),
                  if (!dense) Text(rollText, style: b.type.meta),
                ],
              ),
            ),
            if (status == AttendanceStatus.leave) ...<Widget>[
              const SizedBox(width: BhorSpace.s8),
              attendanceTag(context, status),
            ],
            const SizedBox(width: BhorSpace.s8),
          ],
        );

        final double height = dense ? 56 : 64;
        final Widget main = Semantics(
          container: true,
          button: tap != null,
          label: l10n.a11yStudentRollRow(name, rollText, statusText),
          hint: tap == null ? null : hint,
          excludeSemantics: true,
          onTap: tap,
          onLongPress: menu,
          customSemanticsActions: menu == null
              ? null
              : <CustomSemanticsAction, VoidCallback>{
                  CustomSemanticsAction(label: l10n.rollRowMenu): menu,
                },
          child: Listener(
            onPointerDown: menu == null
                ? null
                : (PointerDownEvent e) {
                    if (e.buttons == kSecondaryButton) menu();
                  },
            child: BhorPressable(
              onTap: tap,
              onLongPress: menu,
              radius: BhorRadius.card,
              scaleOnPress: false,
              showFocusRing: false,
              builder: (BuildContext context, BhorStates s) => Padding(
                padding: EdgeInsets.fromLTRB(BhorSpace.s12, dense ? BhorSpace.s4 : BhorSpace.s8, 0,
                    dense ? BhorSpace.s4 : BhorSpace.s8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: height - (dense ? 8 : 16)),
                  child: Align(alignment: AlignmentDirectional.centerStart, child: info),
                ),
              ),
            ),
          ),
        );

        final Widget toggle = Padding(
          padding: const EdgeInsets.only(right: BhorSpace.s12),
          child: SizedBox(
            width: labelled ? 280 : null,
            child: BhorAttendanceToggle(
              value: status == AttendanceStatus.leave ? null : status.kind,
              iconOnly: !labelled,
              onChanged: enabled && onSet != null
                  ? (AttendanceKind k) => onSet!(AttendanceStatus.values[k.index])
                  : null,
            ),
          ),
        );

        return AnimatedContainer(
          duration: fast,
          curve: BhorMotion.ease,
          constraints: BoxConstraints(minHeight: height),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(BhorRadius.card),
            border: Border.all(color: focused ? c.accent : c.line, width: focused ? 2 : 1),
          ),
          child: Stack(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: main),
                  if (menuButton)
                    BhorIconButton(
                      semanticLabel: l10n.rollRowMenu,
                      icon: BhorIcons.overflow,
                      size: BhorButtonSize.sm,
                      color: c.text2,
                      onPressed: menu,
                    ),
                  toggle,
                ],
              ),
              Positioned(
                left: 0,
                top: 12,
                bottom: 12,
                width: 3,
                child: AnimatedContainer(
                  duration: fast,
                  decoration: BoxDecoration(color: stripe, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What the status sheet returns: a new status, or "edit the class note".
class RollMenuChoice {
  const RollMenuChoice.status(AttendanceStatus this.status) : note = false;
  const RollMenuChoice.note()
      : status = null,
        note = true;

  final AttendanceStatus? status;
  final bool note;
}

Future<RollMenuChoice?> showRollStatusSheet(
  BuildContext context, {
  required String name,
  required AttendanceStatus current,
}) {
  // Phone: bottom sheet; desktop: a centred panel over the roster.
  return showBhorPanel<RollMenuChoice>(
    context,
    kind: BhorPanelKind.list,
    title: context.l10n.rollStatusSheetTitle(name),
    scroll: false,
    width: 420,
    builder: (BuildContext ctx) => RollStatusSheet(name: name, current: current, showTitle: false),
  );
}

/// The sheet body (public so the screen matrix can render it directly).
class RollStatusSheet extends StatelessWidget {
  const RollStatusSheet({super.key, required this.name, required this.current, this.showTitle = true});

  final String name;
  final AttendanceStatus current;

  /// False when the hosting panel already shows the title.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final List<AttendanceStatus> all = AttendanceStatus.values;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showTitle)
            Padding(
              padding: const EdgeInsets.only(bottom: BhorSpace.s8),
              child: Semantics(
                header: true,
                child: Text(l10n.rollStatusSheetTitle(name), style: b.type.title),
              ),
            ),
          for (final AttendanceStatus s in all)
            BhorListRow(
              leading: Icon(statusIcon(s), color: _iconColor(b.colors, s)),
              title: s.label(l10n),
              trailing: s == current ? Icon(BhorIcons.check, color: b.colors.accent) : null,
              onTap: () => Navigator.of(context).pop(RollMenuChoice.status(s)),
            ),
          BhorListRow(
            leading: const Icon(BhorIcons.notes),
            title: l10n.rollMenuNote,
            divider: false,
            onTap: () => Navigator.of(context).pop(const RollMenuChoice.note()),
          ),
          const SizedBox(height: BhorSpace.s8),
        ],
      ),
    );
  }

  Color _iconColor(BhorColors c, AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => c.ok,
        AttendanceStatus.absent => c.absent,
        AttendanceStatus.late => c.lateText,
        AttendanceStatus.leave => c.text2,
      };
}
