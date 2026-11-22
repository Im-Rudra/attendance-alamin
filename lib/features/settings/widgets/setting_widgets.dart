// Small building blocks shared by the settings screens: a dense group card, a
// two-line row (label + current value), a switch row, an info chip, a header
// and a two-column arrangement for wide windows.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

/// Section title above a group (UX 3a).
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(BhorSpace.s4, BhorSpace.s8, BhorSpace.s4, 0),
        child: BhorSectionHeader(title: text),
      );
}

/// A dense card holding rows separated by hairline dividers. [dividers] off
/// is for a card of fields (Coaching center): the fields are separated by
/// spacing only, never by a hairline inside the card (M6).
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children, this.dividers = true});

  final List<Widget> children;
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    final BhorColors c = context.bhor.colors;
    return BhorCard(
      padding: const EdgeInsets.symmetric(vertical: BhorSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0 && dividers)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16),
                child: SizedBox(height: 1, child: ColoredBox(color: c.line)),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Two-line row: label, then the current value in text2. Optional
/// leading icon, trailing widget (a chevron when it is tappable).
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.value,
    this.icon,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? value;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final Widget? end = trailing ??
        (onTap == null ? null : Icon(BhorIcons.chevronRight, size: BhorIconSize.chip, color: c.text3));
    Widget row(BhorStates s) => AnimatedContainer(
          duration: BhorMotion.fast,
          curve: BhorMotion.ease,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: 10),
          color: s.hovered || s.pressed ? c.soft : null,
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                // A soft tinted square keeps the icons calm and aligned.
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: destructive ? c.dangerBg : c.accentTint,
                    borderRadius: BorderRadius.circular(BhorRadius.control - 4),
                  ),
                  child: Icon(icon, size: BhorIconSize.row, color: destructive ? c.danger : c.accent),
                ),
                const SizedBox(width: BhorSpace.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: b.type.body.copyWith(color: destructive ? c.danger : c.text)),
                    if (value != null && value!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(value!, style: b.type.meta),
                      ),
                  ],
                ),
              ),
              if (end != null) ...<Widget>[const SizedBox(width: BhorSpace.s8), end],
            ],
          ),
        );
    if (onTap == null) return row(const BhorStates());
    return BhorPressable(
      onTap: onTap,
      scaleOnPress: false,
      radius: BhorRadius.control,
      builder: (BuildContext context, BhorStates s) => row(s),
    );
  }
}

/// A row that expands in place to show [body] (licences and fonts credit,
/// M5): no dialog, nothing to close; tap the row again to fold it.
class SettingExpandRow extends StatefulWidget {
  const SettingExpandRow({super.key, required this.title, required this.body, this.value, this.icon});

  final String title;
  final String? value;
  final IconData? icon;
  final String body;

  @override
  State<SettingExpandRow> createState() => _SettingExpandRowState();
}

class _SettingExpandRowState extends State<SettingExpandRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          expanded: _open,
          child: SettingRow(
            title: widget.title,
            value: widget.value,
            icon: widget.icon,
            onTap: () => setState(() => _open = !_open),
            trailing: Icon(
              _open ? BhorIcons.chevronUp : BhorIcons.chevronDown,
              size: BhorIconSize.chip,
              color: c.text3,
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(BhorSpace.s16, 0, BhorSpace.s16, BhorSpace.s16),
            child: Text(widget.body, key: const Key('setting-expand-body'), style: b.type.meta.copyWith(color: c.text2)),
          ),
      ],
    );
  }
}

/// A row with a switch; the whole row toggles.
class SettingSwitchRow extends StatelessWidget {
  const SettingSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        toggled: value,
        label: title,
        onTap: () => onChanged(!value),
        child: ExcludeSemantics(
          child: SettingRow(
            title: title,
            value: subtitle,
            icon: icon,
            onTap: () => onChanged(!value),
            trailing: BhorSwitch(value: value, onChanged: onChanged),
          ),
        ),
      );
}

/// A row whose control (segments, field, swatches) sits under the label.
class SettingControlRow extends StatelessWidget {
  const SettingControlRow({super.key, required this.title, this.value, required this.child});

  final String title;
  final String? value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s12, BhorSpace.s16, BhorSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: b.type.body),
          if (value != null && value!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(value!, style: b.type.meta),
            ),
          const SizedBox(height: BhorSpace.s12),
          child,
        ],
      ),
    );
  }
}

/// Neutral `info` chip (never a dues colour): icon, message, optional action.
class SettingInfoChip extends StatelessWidget {
  const SettingInfoChip({super.key, required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s4, BhorSpace.s16, BhorSpace.s8),
      padding: const EdgeInsets.fromLTRB(BhorSpace.s12, BhorSpace.s8, BhorSpace.s8, BhorSpace.s8),
      decoration: BoxDecoration(
        color: c.accentTint,
        borderRadius: BorderRadius.circular(BhorRadius.control),
      ),
      child: Row(
        children: <Widget>[
          Icon(BhorIcons.info, size: 20, color: c.accent),
          const SizedBox(width: BhorSpace.s8),
          Expanded(child: Text(message, style: b.type.meta.copyWith(color: c.text))),
          if (actionLabel != null && onAction != null)
            BhorButton(
              label: actionLabel!,
              variant: BhorButtonVariant.ghost,
              size: BhorButtonSize.sm,
              onPressed: onAction,
            ),
        ],
      ),
    );
  }
}

/// Places [children] in one column, or in two balanced columns when [twoUp]
/// (wide content panes), so wide windows have no empty half.
class SettingsColumns extends StatelessWidget {
  const SettingsColumns({super.key, required this.children, this.twoUp = false, this.gap = 12});

  final List<Widget> children;
  final bool twoUp;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!twoUp || children.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }
    final int split = (children.length + 1) ~/ 2;
    Widget column(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: gap),
              items[i],
            ],
          ],
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: column(children.sublist(0, split))),
        SizedBox(width: gap),
        Expanded(child: column(children.sublist(split))),
      ],
    );
  }
}
