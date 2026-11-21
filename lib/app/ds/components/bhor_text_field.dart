// BhorTextField: label above, hint, helper, inline error, prefix/suffix and a
// focus ring, built on EditableText (no Material InputDecorator).
// Usage: `BhorTextField(label: 'নাম', controller: c, error: err, onChanged: f)`.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

  final String? label;
  final String? hint;
  final String? helper;

  /// Inline error under the field; non-null turns the border red.
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
    final Color border = hasError
        ? c.danger
        : focused
            ? c.accent
            : _hovered && widget.enabled
                ? c.accentLine
                : c.line;
    TextStyle style = b.type.body.copyWith(color: widget.enabled ? c.text : c.text3);
    if (widget.tabular) style = BhorType.tabular(style);
    final bool multi = widget.maxLines == null || widget.maxLines! > 1;

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

    final Widget text = Stack(
      children: <Widget>[
        if (widget.hint != null)
          Positioned.fill(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (BuildContext context, TextEditingValue v, Widget? _) => v.text.isEmpty
                  ? IgnorePointer(
                      child: ExcludeSemantics(
                        child: Text(
                          widget.hint!,
                          maxLines: multi ? null : 1,
                          overflow: multi ? null : TextOverflow.ellipsis,
                          textAlign: widget.textAlign,
                          style: style.copyWith(color: c.text3),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        editable,
      ],
    );

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
          child: AnimatedContainer(
            duration: BhorMotion.fast,
            curve: BhorMotion.curve,
            constraints: const BoxConstraints(minHeight: BhorSize.control),
            padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.enabled ? c.surface : c.surface2,
              borderRadius: BorderRadius.circular(BhorRadius.control),
              border: Border.all(color: border, width: focused || hasError ? 1.5 : 1),
            ),
            child: Row(
              crossAxisAlignment: multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: <Widget>[
                if (widget.prefix != null) ...<Widget>[
                  IconTheme(data: IconThemeData(color: c.text3, size: 18), child: widget.prefix!),
                  const SizedBox(width: BhorSpace.s8),
                ],
                Expanded(child: text),
                if (widget.suffix != null) ...<Widget>[
                  const SizedBox(width: BhorSpace.s8),
                  IconTheme(data: IconThemeData(color: c.text3, size: 18), child: widget.suffix!),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: widget.label ?? widget.semanticLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.label != null) ...<Widget>[
            ExcludeSemantics(
              child: Text(widget.label!, style: b.type.label.copyWith(color: c.text2)),
            ),
            const SizedBox(height: 6),
          ],
          box,
          if (hasError) ...<Widget>[
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Text(widget.error!, style: b.type.meta.copyWith(color: c.danger)),
            ),
          ] else if (widget.helper != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(widget.helper!, style: b.type.meta.copyWith(color: c.text3)),
          ],
        ],
      ),
    );
  }
}
