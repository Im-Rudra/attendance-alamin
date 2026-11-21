// BhorSelect (docs/council/13-fluid-ui-spec.md, Select): field-styled (soft
// fill, floating label), the chevron rotates 180° with the spring. On wide
// windows the menu drops from the field as a surface popover (scale .96 -> 1,
// y -4 -> 0, fade, 200 ms) with a check on the chosen item; on phones the
// options open as a bottom-sheet list instead. The chosen item is an accent
// tint + check (never an outline) and the list opens scrolled to it. No
// Material DropdownButton.
// Usage: `BhorSelect<String>(label: 'ব্যাচ', value: id, options: [...], onChanged: f)`.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_overlays.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';

/// One choice of a [BhorSelect].
class BhorOption<T> {
  const BhorOption(this.value, this.label, {this.icon, this.enabled = true});

  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
}

class BhorSelect<T> extends StatefulWidget {
  const BhorSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint,
    this.error,
    this.semanticLabel,
  });

  final List<BhorOption<T>> options;
  final T? value;

  /// Null disables the field.
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? hint;
  final String? error;
  final String? semanticLabel;

  @override
  State<BhorSelect<T>> createState() => _BhorSelectState<T>();
}

class _BhorSelectState<T> extends State<BhorSelect<T>> {
  final GlobalKey _boxKey = GlobalKey();
  bool _open = false;

  BhorOption<T>? get _current {
    for (final BhorOption<T> o in widget.options) {
      if (o.value == widget.value) return o;
    }
    return null;
  }

  Future<void> _openMenu() async {
    setState(() => _open = true);
    final _Pick<T>? picked = context.bhorIsWide ? await _popover() : await _sheet();
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null && picked.value != widget.value) widget.onChanged?.call(picked.value);
  }

  Future<_Pick<T>?> _popover() async {
    final RenderBox? box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    final NavigatorState nav = Navigator.of(context, rootNavigator: true);
    final RenderBox? navBox = nav.context.findRenderObject() as RenderBox?;
    if (box == null || navBox == null) return null;
    final Rect anchor = box.localToGlobal(Offset.zero, ancestor: navBox) & box.size;
    return nav.push(_BhorMenuRoute<T>(
      anchor: anchor,
      options: widget.options,
      selected: widget.value,
      theme: context.bhor,
      reduced: BhorMotion.reduced(context),
      barrierLabel: widget.label ?? widget.semanticLabel ?? '',
    ));
  }

  Future<_Pick<T>?> _sheet() => showBhorSheet<_Pick<T>>(
        context,
        title: widget.label ?? widget.semanticLabel,
        builder: (BuildContext ctx) => SingleChildScrollView(
          child: _OptionList<T>(
            options: widget.options,
            selected: widget.value,
            rowHeight: BhorSize.field - 4,
            autofocusSelected: false,
            onPick: (T v) => Navigator.of(ctx).pop(_Pick<T>(v)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool enabled = widget.onChanged != null;
    final bool hasError = widget.error != null && widget.error!.isNotEmpty;
    final BhorOption<T>? current = _current;
    final String shown = current?.label ?? widget.hint ?? '';
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);
    final bool hasLabel = widget.label != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorPressable(
          onTap: enabled ? _openMenu : null,
          semanticLabel: '${widget.label ?? widget.semanticLabel ?? ''}${current == null ? '' : ', ${current.label}'}',
          excludeChildSemantics: true,
          scaleOnPress: false,
          radius: BhorRadius.control,
          builder: (BuildContext context, BhorStates s) => BhorFocusRing(
            visible: _open,
            radius: BhorRadius.control,
            child: AnimatedContainer(
              key: _boxKey,
              duration: fast,
              curve: BhorMotion.ease,
              constraints: BoxConstraints(minHeight: hasLabel ? BhorSize.field : BhorSize.control),
              padding: const EdgeInsets.fromLTRB(BhorSpace.s16, 6, BhorSpace.s12, 6),
              decoration: BoxDecoration(
                color: !enabled ? c.soft : (_open ? c.surface : (s.hovered || s.pressed ? c.soft2 : c.soft)),
                borderRadius: BorderRadius.circular(BhorRadius.control),
                border: Border.all(color: hasError ? c.danger : c.danger.withValues(alpha: 0), width: 1.5),
              ),
              child: Row(
                children: <Widget>[
                  if (current?.icon != null) ...<Widget>[
                    Icon(current!.icon, size: BhorIconSize.chip, color: c.text2),
                    const SizedBox(width: BhorSpace.s8),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (hasLabel)
                          Text(
                            widget.label!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: b.type.label.copyWith(
                              fontSize: 12,
                              color: hasError ? c.danger : (_open ? c.accent : c.text2),
                            ),
                          ),
                        Text(
                          shown,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: b.type.body.copyWith(
                            fontSize: 15,
                            color: current == null || !enabled ? c.text3 : c.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: BhorMotion.of(context, BhorMotion.glide),
                    curve: BhorMotion.curveOf(context, BhorMotion.spring),
                    child: Icon(BhorIcons.chevronDown, size: BhorIconSize.row, color: c.text2),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(widget.error!, style: b.type.meta.copyWith(color: c.danger)),
          ),
      ],
    );
  }
}

/// Wraps the picked value so "picked null" and "dismissed" differ.
class _Pick<T> {
  const _Pick(this.value);

  final T value;
}

/// The option rows shared by the popover and the phone sheet.
class _OptionList<T> extends StatelessWidget {
  const _OptionList({
    required this.options,
    required this.selected,
    required this.onPick,
    this.rowHeight = BhorSize.control,
    this.autofocusSelected = true,
  });

  final List<BhorOption<T>> options;
  final T? selected;
  final ValueChanged<T> onPick;
  final double rowHeight;

  /// Keyboard focus starts on the chosen item (desktop popover).
  final bool autofocusSelected;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final BhorOption<T> o in options)
          _ScrollIntoView(
            enabled: o.value == selected,
            child: BhorPressable(
            autofocus: autofocusSelected && o.value == selected,
            onTap: o.enabled ? () => onPick(o.value) : null,
            selected: o.value == selected,
            semanticLabel: o.label,
            excludeChildSemantics: true,
            scaleOnPress: false,
            radius: 10,
            builder: (BuildContext context, BhorStates s) {
              final bool sel = o.value == selected;
              return AnimatedContainer(
                duration: BhorMotion.of(context, BhorMotion.instant),
                constraints: BoxConstraints(minHeight: rowHeight),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12),
                decoration: BoxDecoration(
                  color: sel ? c.accentTint : (s.hovered || s.pressed ? c.soft : c.soft.withValues(alpha: 0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: <Widget>[
                    if (o.icon != null) ...<Widget>[
                      Icon(o.icon, size: BhorIconSize.chip, color: sel ? c.accent : c.text2),
                      const SizedBox(width: BhorSpace.s8),
                    ],
                    Expanded(
                      child: Text(
                        o.label,
                        style: (sel ? b.type.bodyStrong : b.type.body)
                            .copyWith(color: !o.enabled ? c.text3 : (sel ? c.accent : c.text)),
                      ),
                    ),
                    if (sel) Icon(BhorIcons.check, size: BhorIconSize.chip, color: c.accent),
                  ],
                ),
              );
            },
          ),
          ),
      ],
    );
  }
}

/// Scrolls [child] to the middle of its scroll view once, after the first
/// frame (the chosen option of a long list).
class _ScrollIntoView extends StatefulWidget {
  const _ScrollIntoView({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_ScrollIntoView> createState() => _ScrollIntoViewState();
}

class _ScrollIntoViewState extends State<_ScrollIntoView> {
  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || Scrollable.maybeOf(context) == null) return;
      Scrollable.ensureVisible(context, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BhorMenuRoute<T> extends PopupRoute<_Pick<T>> {
  _BhorMenuRoute({
    required this.anchor,
    required this.options,
    required this.selected,
    required this.theme,
    required this.reduced,
    required this.barrierLabel,
  });

  final Rect anchor;
  final List<BhorOption<T>> options;
  final T? selected;
  final BhorThemeData theme;
  final bool reduced;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => reduced ? BhorMotion.reducedFade : const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => reduced ? BhorMotion.reducedFade : const Duration(milliseconds: 120);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final BhorColors c = theme.colors;
    return BhorTheme(
      data: theme,
      child: CustomSingleChildLayout(
        delegate: _MenuLayout(anchor: anchor, padding: MediaQuery.paddingOf(context)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(BhorRadius.control),
            border: Border.all(color: c.line),
            boxShadow: c.floatShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BhorRadius.control),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _OptionList<T>(
                options: options,
                selected: selected,
                onPick: (T v) => Navigator.of(context).pop(_Pick<T>(v)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final Animation<double> a = CurvedAnimation(parent: animation, curve: BhorMotion.ease, reverseCurve: BhorMotion.exitCurve);
    if (reduced) return FadeTransition(opacity: a, child: child);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(0, -4 * (1 - a.value)),
          child: Transform.scale(scale: 0.96 + 0.04 * a.value, alignment: Alignment.topCenter, child: child),
        ),
        child: child,
      ),
    );
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout({required this.anchor, required this.padding});

  final Rect anchor;
  final EdgeInsets padding;

  static const double _gap = 6;
  static const double _maxHeight = 320;

  double _below(Size size) => size.height - padding.bottom - anchor.bottom - _gap - 8;
  double _above() => anchor.top - padding.top - _gap - 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final Size size = constraints.biggest;
    final double room = math.max(_below(size), _above());
    final double width = math.min(math.max(anchor.width, 200), size.width - 16);
    return BoxConstraints(minWidth: width, maxWidth: width, maxHeight: math.max(88, math.min(_maxHeight, room)));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bool down = _below(size) >= childSize.height || _below(size) >= _above();
    final double top = down ? anchor.bottom + _gap : anchor.top - _gap - childSize.height;
    final double left = anchor.left.clamp(8, math.max(8, size.width - childSize.width - 8)).toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_MenuLayout old) => old.anchor != anchor || old.padding != padding;
}
