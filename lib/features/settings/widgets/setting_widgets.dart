// Small building blocks shared by the settings screens: a dense group card, a
// two-line row (label + current value), a switch row, an info chip, a header
// and a two-column arrangement for wide windows.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';

/// Section title above a group (labelLarge in accent, UX 3a).
class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.aurora.accent),
          ),
        ),
      );
}

/// A dense glass card holding rows separated by hairline dividers.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    return GlassCard(
      dense: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: tokens.track),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Two-line row: label, then the current value in textSecondary. Optional
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final Widget? end = trailing ??
        (onTap == null ? null : Icon(Icons.chevron_right, color: tokens.textSecondary));
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, color: destructive ? tokens.error : tokens.accent),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: tt.bodyLarge?.copyWith(
                        color: destructive ? tokens.error : tokens.textPrimary,
                      ),
                    ),
                    if (value != null && value!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          value!,
                          style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              if (end != null) ...<Widget>[const SizedBox(width: 8), end],
            ],
          ),
        ),
      ),
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
            trailing: Switch(value: value, onChanged: onChanged),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: tt.bodyLarge?.copyWith(color: tokens.textPrimary)),
          if (value != null && value!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(value!, style: tt.bodyMedium?.copyWith(color: tokens.textSecondary)),
            ),
          const SizedBox(height: 10),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: tokens.infoContainer,
        borderRadius: BorderRadius.circular(AuroraMetrics.radiusChip + 4),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: tokens.info),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: tt.bodyMedium?.copyWith(color: tokens.info))),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: tokens.info,
              ),
              child: Text(actionLabel!),
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
