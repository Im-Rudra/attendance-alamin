// BhorSelect: a dropdown field whose menu is a custom popup route on the
// root Overlay (no Material DropdownButton / PopupMenu).
// Usage: `BhorSelect<String>(label: 'ব্যাচ', value: id, options: [...], onChanged: f)`.

import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

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
    final RenderBox? box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    final NavigatorState nav = Navigator.of(context, rootNavigator: true);
    final RenderBox? navBox = nav.context.findRenderObject() as RenderBox?;
    if (box == null || navBox == null) return;
    final Rect anchor = box.localToGlobal(Offset.zero, ancestor: navBox) & box.size;
    setState(() => _open = true);
    final _Pick<T>? picked = await nav.push(_BhorMenuRoute<T>(
      anchor: anchor,
      options: widget.options,
      selected: widget.value,
      theme: context.bhor,
      barrierLabel: widget.label ?? widget.semanticLabel ?? '',
    ));
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null && picked.value != widget.value) widget.onChanged?.call(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool enabled = widget.onChanged != null;
    final bool hasError = widget.error != null && widget.error!.isNotEmpty;
    final BhorOption<T>? current = _current;
    final String shown = current?.label ?? widget.hint ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          ExcludeSemantics(child: Text(widget.label!, style: b.type.label.copyWith(color: c.text2))),
          const SizedBox(height: 6),
        ],
        BhorPressable(
          onTap: enabled ? _openMenu : null,
          semanticLabel: '${widget.label ?? widget.semanticLabel ?? ''}${current == null ? '' : ', ${current.label}'}',
          excludeChildSemantics: true,
          scaleOnPress: false,
          builder: (BuildContext context, BhorStates s) => AnimatedContainer(
            key: _boxKey,
            duration: BhorMotion.fast,
            constraints: const BoxConstraints(minHeight: BhorSize.control),
            padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12, vertical: 8),
            decoration: BoxDecoration(
              color: enabled ? c.surface : c.surface2,
              borderRadius: BorderRadius.circular(BhorRadius.control),
              border: Border.all(
                color: hasError
                    ? c.danger
                    : _open
                        ? c.accent
                        : s.hovered
                            ? c.accentLine
                            : c.line,
                width: _open || hasError ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                if (current?.icon != null) ...<Widget>[
                  Icon(current!.icon, size: 18, color: c.text2),
                  const SizedBox(width: BhorSpace.s8),
                ],
                Expanded(
                  child: Text(
                    shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: b.type.body.copyWith(color: current == null || !enabled ? c.text3 : c.text),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: BhorMotion.base,
                  child: Icon(Icons.expand_more_rounded, size: 20, color: c.text2),
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 6),
          Text(widget.error!, style: b.type.meta.copyWith(color: c.danger)),
        ],
      ],
    );
  }
}

/// Wraps the picked value so "picked null" and "dismissed" differ.
class _Pick<T> {
  const _Pick(this.value);

  final T value;
}

class _BhorMenuRoute<T> extends PopupRoute<_Pick<T>> {
  _BhorMenuRoute({
    required this.anchor,
    required this.options,
    required this.selected,
    required this.theme,
    required this.barrierLabel,
  });

  final Rect anchor;
  final List<BhorOption<T>> options;
  final T? selected;
  final BhorThemeData theme;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => BhorMotion.base;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return BhorTheme(
      data: theme,
      child: CustomSingleChildLayout(
        delegate: _MenuLayout(anchor: anchor, padding: MediaQuery.paddingOf(context)),
        child: _Menu<T>(options: options, selected: selected),
      ),
    );
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final Animation<double> a = CurvedAnimation(parent: animation, curve: BhorMotion.curve);
    return FadeTransition(
      opacity: a,
      child: ScaleTransition(
        alignment: Alignment.topCenter,
        scale: Tween<double>(begin: 0.97, end: 1).animate(a),
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

class _Menu<T> extends StatelessWidget {
  const _Menu({required this.options, required this.selected});

  final List<BhorOption<T>> options;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(BhorRadius.control),
        border: Border.all(color: c.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BhorRadius.control),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: <Widget>[
            for (final BhorOption<T> o in options)
              BhorPressable(
                autofocus: o.value == selected,
                onTap: o.enabled ? () => Navigator.of(context).pop(_Pick<T>(o.value)) : null,
                selected: o.value == selected,
                semanticLabel: o.label,
                excludeChildSemantics: true,
                scaleOnPress: false,
                radius: 8,
                builder: (BuildContext context, BhorStates s) {
                  final bool sel = o.value == selected;
                  return Container(
                    constraints: const BoxConstraints(minHeight: BhorSize.control),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12),
                    decoration: BoxDecoration(
                      color: sel ? c.accentTint : (s.hovered || s.pressed ? c.surface2 : null),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: <Widget>[
                        if (o.icon != null) ...<Widget>[
                          Icon(o.icon, size: 18, color: sel ? c.accent : c.text2),
                          const SizedBox(width: BhorSpace.s8),
                        ],
                        Expanded(
                          child: Text(
                            o.label,
                            style: (sel ? b.type.bodyStrong : b.type.body)
                                .copyWith(color: !o.enabled ? c.text3 : (sel ? c.accent : c.text)),
                          ),
                        ),
                        if (sel) Icon(Icons.check_rounded, size: 18, color: c.accent),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
