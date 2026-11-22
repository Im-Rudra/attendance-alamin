// One roll-call row (UX 2b): a surface card with the student and the gliding
// attendance toggle (present / absent / late). Tapping the name still flips
// present/absent for speed; long-press / right-click / the options button open
// the status panel (excused, note). Absent and late tint the row (the toggle
// and tag carry the state too, so it never relies on colour alone). Rows sit
// inside one grouped list, so a row has no border or stripe of its own.

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

  /// The keyboard cursor is on this row (the caller passes true only while the
  /// user is driving with the keyboard, review R3).
  final bool focused;

  /// Tap on the name: present <-> absent.
  final VoidCallback? onToggle;

  /// A segment of the attendance toggle was chosen.
  final ValueChanged<AttendanceStatus>? onSet;
  /// Called with the context to anchor the menu to (the dots button, else the row).
  final ValueChanged<BuildContext>? onMenu;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final String statusText = status.label(l10n);
    final String rollText = fmt.number(roll);
    final VoidCallback? tap = enabled ? onToggle : null;
    final VoidCallback? menu = (enabled && onMenu != null) ? () => onMenu!(context) : null;
    final String hint = status == AttendanceStatus.absent ? l10n.a11yHintMarkPresent : l10n.a11yHintMarkAbsent;
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);

    // Row tint per status.
    final Color fill = switch (status) {
      AttendanceStatus.present => c.surface,
      AttendanceStatus.absent => c.absentBg,
      AttendanceStatus.late => c.lateBg,
      AttendanceStatus.leave => c.soft,
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final bool menuButton = dense && box.maxWidth >= 360 && menu != null;
        final bool labelled = dense && box.maxWidth >= 460;
        // Wide rows: "Leave" is one click away, next to the toggle (R5).
        final bool leaveChip = labelled && enabled && onSet != null && box.maxWidth >= 580;

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
            if (status == AttendanceStatus.leave && !leaveChip) ...<Widget>[
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
              radius: 0,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (leaveChip) ...<Widget>[
                BhorChip(
                  label: AttendanceStatus.leave.label(l10n),
                  icon: statusIcon(AttendanceStatus.leave),
                  selected: status == AttendanceStatus.leave,
                  onSelected: (bool on) => onSet!(on ? AttendanceStatus.leave : AttendanceStatus.present),
                ),
                const SizedBox(width: BhorSpace.s8),
              ],
              SizedBox(
                width: labelled ? 280 : null,
                child: BhorAttendanceToggle(
                  value: status == AttendanceStatus.leave ? null : status.kind,
                  iconOnly: !labelled,
                  onChanged: enabled && onSet != null
                      ? (AttendanceKind k) => onSet!(AttendanceStatus.values[k.index])
                      : null,
                ),
              ),
            ],
          ),
        );

        return AnimatedContainer(
          duration: fast,
          curve: BhorMotion.ease,
          constraints: BoxConstraints(minHeight: height),
          decoration: BoxDecoration(
            color: fill,
            border: focused ? Border.all(color: c.accent, width: 2) : null,
          ),
          child: Row(
            children: <Widget>[
              Expanded(child: main),
              if (menuButton)
                Builder(
                  // The menu hangs from the dots button itself (G7).
                  builder: (BuildContext dots) => BhorIconButton(
                    semanticLabel: l10n.rollRowMenu,
                    icon: BhorIcons.overflow,
                    size: BhorButtonSize.sm,
                    color: c.text2,
                    onPressed: () => onMenu!(dots),
                  ),
                ),
              toggle,
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
  BuildContext? anchor,
}) {
  // Phone: bottom sheet; desktop: a centred panel over the roster.
  return showBhorPanel<RollMenuChoice>(
    context,
    kind: BhorPanelKind.list,
    anchor: anchor,
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
