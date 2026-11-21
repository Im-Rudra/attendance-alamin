// BhorTextField (docs/council/13-fluid-ui-spec.md, TextField): filled, no
// border. h56, r14, soft fill (hover soft2). The label floats inside the box
// (15 px at rest -> 12 px at the top on focus / when filled, 220 ms). Focus:
// surface fill + 1.5 px accent ring + 4 px focus ring, accent label. Error:
// 1.5 px error ring and a message that slides down 4 px and fades in.
// Built on EditableText (no Material InputDecorator).
// Usage: `BhorTextField(label: 'নাম', controller: c, error: err, onChanged: f)`.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';

class BhorTextField extends StatefulWidget {
  const BhorTextField({
    super.key,
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.tabular = false,
    this.semanticLabel,
  });

  /// Floating label inside the box.
  final String? label;

  /// Placeholder, shown once the label has floated and the field is empty.
  final String? hint;
  final String? helper;

  /// Inline error under the field; non-null paints the error ring.
  final String? error;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Initial text when no [controller] is given.
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Widgets inside the box, before/after the text (icon, "৳", unit).
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Soft-keyboard capitalisation (names: words, notes: sentences).
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextAlign textAlign;

  /// Tabular figures (money, phone numbers).
  final bool tabular;

  /// Accessible name when there is no visible [label].
  final String? semanticLabel;

  @override
  State<BhorTextField> createState() => _BhorTextFieldState();
}

class _BhorTextFieldState extends State<BhorTextField>
    implements TextSelectionGestureDetectorBuilderDelegate {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  late final TextSelectionGestureDetectorBuilder _gestures =
      TextSelectionGestureDetectorBuilder(delegate: this);
  bool _hovered = false;
  Offset? _downAt;

  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController(text: widget.initialValue));

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'BhorTextField'));

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(BhorTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool focused = _focus.hasFocus;
    final bool hasError = widget.error != null && widget.error!.isNotEmpty;
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);
    final Duration labelDur = BhorMotion.of(context, const Duration(milliseconds: 220));
    TextStyle style = b.type.body.copyWith(color: widget.enabled ? c.text : c.text3, fontSize: 15);
    if (widget.tabular) style = BhorType.tabular(style);
    final bool multi = widget.maxLines == null || widget.maxLines! > 1;
    final bool hasLabel = widget.label != null;

    final Widget editable = EditableText(
      key: editableTextKey,
      controller: _controller,
      focusNode: _focus,
      readOnly: widget.readOnly || !widget.enabled,
      obscureText: widget.obscureText,
      autofocus: widget.autofocus,
      style: style,
      textAlign: widget.textAlign,
      cursorColor: c.accent,
      backgroundCursorColor: c.text3,
      selectionColor: c.accent.withValues(alpha: 0.24),
      keyboardType: widget.keyboardType ?? (multi ? TextInputType.multiline : TextInputType.text),
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: <TextInputFormatter>[
        if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
        ...?widget.inputFormatters,
      ],
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      rendererIgnoresPointer: true,
      cursorWidth: 1.5,
      cursorRadius: const Radius.circular(1),
      enableInteractiveSelection: widget.enabled,
    );

    final Widget field = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (BuildContext context, TextEditingValue v, Widget? _) {
        final bool empty = v.text.isEmpty;
        // The label floats on focus or once there is text.
        final bool floated = !hasLabel || focused || !empty;
        final Color labelColor = hasError ? c.danger : (focused ? c.accent : c.text2);
        final Widget text = Stack(
          children: <Widget>[
            if (widget.hint != null && empty)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: AnimatedOpacity(
                      opacity: empty && floated ? 1 : 0,
                      duration: fast,
                      child: Text(
                        widget.hint!,
                        maxLines: multi ? null : 1,
                        overflow: multi ? null : TextOverflow.ellipsis,
                        textAlign: widget.textAlign,
                        style: style.copyWith(color: c.text3),
                      ),
                    ),
                  ),
                ),
              ),
            editable,
          ],
        );
        if (!hasLabel) return text;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: floated ? 1 : 0),
          duration: labelDur,
          curve: BhorMotion.ease,
          builder: (BuildContext context, double t, Widget? child) => Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Padding(padding: const EdgeInsets.only(top: 17), child: child),
              Positioned(
                left: 0,
                right: 0,
                top: 10 * (1 - t),
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Text(
                      widget.label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: widget.textAlign,
                      style: b.type.body.copyWith(
                        fontSize: 15 - 3 * t,
                        fontWeight: t > 0.5 ? FontWeight.w600 : FontWeight.w400,
                        color: Color.lerp(c.text2, labelColor, t),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: text,
        );
      },
    );

    final Color fill = !widget.enabled
        ? c.soft
        : focused
            ? c.surface
            : (_hovered ? c.soft2 : c.soft);

    final Widget box = MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // A tap (not a drag) anywhere in the box focuses the field and opens
      // the keyboard; the selection gestures below place the caret.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (PointerDownEvent e) => _downAt = e.position,
        onPointerUp: (PointerUpEvent e) {
          final Offset? from = _downAt;
          _downAt = null;
          if (!widget.enabled || from == null || (e.position - from).distance > 18) return;
          editableTextKey.currentState?.requestKeyboard();
        },
        child: _gestures.buildGestureDetector(
          behavior: HitTestBehavior.translucent,
          child: BhorFocusRing(
            visible: focused && !hasError,
            radius: BhorRadius.control,
            child: AnimatedContainer(
              duration: fast,
              curve: BhorMotion.ease,
              constraints: const BoxConstraints(minHeight: BhorSize.field),
              padding: hasLabel
                  ? const EdgeInsets.fromLTRB(BhorSpace.s16, 7, BhorSpace.s16, 11)
                  : const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: 16),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(BhorRadius.control),
                border: Border.all(color: hasError ? c.danger : c.danger.withValues(alpha: 0), width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: <Widget>[
                  if (widget.prefix != null) ...<Widget>[
                    IconTheme(data: IconThemeData(color: c.text3, size: BhorIconSize.chip), child: widget.prefix!),
                    const SizedBox(width: BhorSpace.s8),
                  ],
                  Expanded(child: field),
                  if (widget.suffix != null) ...<Widget>[
                    const SizedBox(width: BhorSpace.s8),
                    IconTheme(data: IconThemeData(color: c.text3, size: BhorIconSize.chip), child: widget.suffix!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final Widget below = hasError
        ? Semantics(
            key: const ValueKey<String>('error'),
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(widget.error!, style: b.type.meta.copyWith(color: c.danger)),
            ),
          )
        : widget.helper != null
            ? Padding(
                key: const ValueKey<String>('helper'),
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(widget.helper!, style: b.type.meta.copyWith(color: c.text3)),
              )
            : const SizedBox(key: ValueKey<String>('none'), width: double.infinity);

    return Semantics(
      container: true,
      label: widget.label ?? widget.semanticLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          box,
          AnimatedSize(
            duration: fast,
            curve: BhorMotion.ease,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: fast,
              switchInCurve: BhorMotion.ease,
              switchOutCurve: BhorMotion.exitCurve,
              layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                alignment: Alignment.topLeft,
                children: <Widget>[...previous, if (current != null) current],
              ),
              transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, -0.22), end: Offset.zero).animate(a),
                  child: child,
                ),
              ),
              child: below,
            ),
          ),
        ],
      ),
    );
  }
}
