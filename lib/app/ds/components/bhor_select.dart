// BhorSelect (docs/council/13-fluid-ui-spec.md, Select): field-styled (soft
// fill, floating label), the chevron rotates 180° with the spring. On wide
// windows the menu drops from the field as a surface popover (scale .96 -> 1,
// y -4 -> 0, fade, 200 ms) with a check on the chosen item; on phones the
// options open as a bottom-sheet list instead. The chosen item is an accent
// tint + check (never an outline) and the list opens scrolled to it. No
// Material DropdownButton. While open the field keeps its soft fill (one
// field style): the label turns accent and the chevron turns; no ring.
// BhorPickerField is the same soft field as a plain tap target (date, time
// or any value chosen in a picker), so no feature draws its own white,
// outlined or borderless "field".
// `searchable: true` (opt-in, for entity lists: students, batches, tuitions,
// places) puts a filter field at the top of the popover / sheet: typing
// narrows the list (the label and the option's `searchText`, Bangla or ASCII
// digits alike), Enter picks the first match, arrow-down moves into the list.
// Short fixed lists (months, times) never get one.
// Usage: `BhorSelect<String>(label: 'ব্যাচ', value: id, options: [...], onChanged: f)`,
// `BhorPickerField(label: 'শুরু', value: fmt.time(m), icon: BhorIcons.clock, onTap: pick)`.

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_overlays.dart';
import 'package:attendance_alamin/app/ds/components/bhor_text_field.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

/// Lists longer than this are worth a filter field: callers with a list of
/// people / batches use it to decide on `searchable` (the select itself never
/// turns search on by itself).
const int kBhorSelectSearchAbove = 6;

/// One choice of a [BhorSelect].
class BhorOption<T> {
  const BhorOption(this.value, this.label, {this.icon, this.enabled = true, this.searchText});

  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;

  /// Extra words the filter field also matches (a phone number, a roll).
  final String? searchText;
}

/// Lower case, Bangla digits as ASCII, runs of spaces as one: what the
/// filter field compares.
String bhorSearchNorm(String s) {
  final StringBuffer out = StringBuffer();
  for (final int r in s.toLowerCase().runes) {
    out.writeCharCode(r >= 0x09E6 && r <= 0x09EF ? r - 0x09E6 + 0x30 : r);
  }
  return out.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
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
    this.searchable = false,
    this.searchHint,
  });

  final List<BhorOption<T>> options;
  final T? value;

  /// Filter field at the top of the list (opt-in: entity lists such as
  /// students, batches / tuitions and places; never months or times).
  final bool searchable;

  /// Placeholder of the filter field (default "খুঁজুন…").
  final String? searchHint;

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

  bool get _searchable => widget.searchable;

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
      searchable: _searchable,
      searchHint: widget.searchHint,
    ));
  }

  Future<_Pick<T>?> _sheet() => showBhorSheet<_Pick<T>>(
        context,
        title: widget.label ?? widget.semanticLabel,
        builder: (BuildContext ctx) => SingleChildScrollView(
          child: _searchable
              ? _SearchableOptions<T>(
                  options: widget.options,
                  selected: widget.value,
                  rowHeight: BhorSize.field - 4,
                  bounded: false,
                  autofocus: false,
                  hint: widget.searchHint,
                  onPick: (T v) => Navigator.of(ctx).pop(_Pick<T>(v)),
                )
              : _OptionList<T>(
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
          showFocusRing: false,
          radius: BhorRadius.control,
          builder: (BuildContext context, BhorStates s) => BhorFocusRing(
            // Keyboard focus only (BhorPressable's own ring is off here so
            // the ring hugs the field box); opening never adds one.
            visible: s.focused,
            radius: BhorRadius.control,
            child: AnimatedContainer(
              key: _boxKey,
              duration: fast,
              curve: BhorMotion.ease,
              constraints: BoxConstraints(minHeight: hasLabel ? BhorSize.field : BhorSize.control),
              padding: const EdgeInsets.fromLTRB(BhorSpace.s16, 6, BhorSpace.s12, 6),
              decoration: BoxDecoration(
                color: !enabled ? c.soft : (_open || s.hovered || s.pressed ? c.soft2 : c.soft),
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

/// A soft field that opens a picker (date, time, anything chosen elsewhere):
/// the same box as [BhorTextField] / [BhorSelect] (soft fill r14, h56 with a
/// label, soft2 on hover), the small label over the value and a trailing
/// [icon]. Never white, outlined or borderless. The tap callback receives
/// the field's own context so pickers can anchor to it.
/// Usage: `BhorPickerField(label: 'শুরু', value: fmt.time(m), icon: BhorIcons.clock, onTap: (ctx) => pick(ctx))`.
class BhorPickerField extends StatelessWidget {
  const BhorPickerField({
    super.key,
    required this.value,
    required this.onTap,
    this.label,
    this.placeholder,
    this.icon = BhorIcons.chevronDown,
    this.leading,
    this.error,
    this.semanticLabel,
  });

  /// Shown value; null / empty shows [placeholder] in text3.
  final String? value;

  /// Null disables the field. Gets the field's context (anchor).
  final ValueChanged<BuildContext>? onTap;
  final String? label;
  final String? placeholder;

  /// Trailing glyph (calendar, clock, chevron).
  final IconData icon;

  /// Optional leading glyph.
  final IconData? leading;
  final String? error;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool enabled = onTap != null;
    final bool hasError = error != null && error!.isNotEmpty;
    final bool empty = value == null || value!.isEmpty;
    final bool hasLabel = label != null;
    final Duration fast = BhorMotion.of(context, BhorMotion.fast);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorPressable(
          onTap: enabled ? () => onTap!(context) : null,
          semanticLabel: <String>[
            ?(label ?? semanticLabel),
            if (!empty) value!,
          ].join(', '),
          excludeChildSemantics: true,
          scaleOnPress: false,
          radius: BhorRadius.control,
          builder: (BuildContext context, BhorStates s) => AnimatedContainer(
            duration: fast,
            curve: BhorMotion.ease,
            constraints: BoxConstraints(minHeight: hasLabel ? BhorSize.field : BhorSize.control),
            padding: const EdgeInsets.fromLTRB(BhorSpace.s16, 6, BhorSpace.s12, 6),
            decoration: BoxDecoration(
              color: enabled && (s.hovered || s.pressed) ? c.soft2 : c.soft,
              borderRadius: BorderRadius.circular(BhorRadius.control),
              border: Border.all(color: hasError ? c.danger : c.danger.withValues(alpha: 0), width: 1.5),
            ),
            child: Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  Icon(leading, size: BhorIconSize.chip, color: c.text2),
                  const SizedBox(width: BhorSpace.s8),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (hasLabel)
                        Text(
                          label!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: b.type.label.copyWith(fontSize: 12, color: hasError ? c.danger : c.text2),
                        ),
                      Text(
                        empty ? (placeholder ?? '') : value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BhorType.tabular(b.type.body).copyWith(
                          fontSize: 15,
                          color: empty || !enabled ? c.text3 : c.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BhorSpace.s8),
                Icon(icon, size: BhorIconSize.row, color: enabled ? c.text2 : c.text3),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(error!, style: b.type.meta.copyWith(color: c.danger)),
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

/// The filter field over the option rows. [bounded]: the list scrolls under
/// the field (popover, height capped); otherwise the caller scrolls both.
class _SearchableOptions<T> extends StatefulWidget {
  const _SearchableOptions({
    required this.options,
    required this.selected,
    required this.onPick,
    this.rowHeight = BhorSize.control,
    this.bounded = true,
    this.autofocus = true,
    this.hint,
  });

  final List<BhorOption<T>> options;
  final T? selected;
  final ValueChanged<T> onPick;
  final double rowHeight;
  final bool bounded;
  final bool autofocus;
  final String? hint;

  @override
  State<_SearchableOptions<T>> createState() => _SearchableOptionsState<T>();
}

class _SearchableOptionsState<T> extends State<_SearchableOptions<T>> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _field = FocusNode(debugLabel: 'bhor-select-search');

  @override
  void dispose() {
    _query.dispose();
    _field.dispose();
    super.dispose();
  }

  List<BhorOption<T>> get _shown {
    final String q = bhorSearchNorm(_query.text);
    if (q.isEmpty) return widget.options;
    return <BhorOption<T>>[
      for (final BhorOption<T> o in widget.options)
        if (bhorSearchNorm('${o.label} ${o.searchText ?? ''}').contains(q)) o,
    ];
  }

  void _pickFirst() {
    for (final BhorOption<T> o in _shown) {
      if (o.enabled) {
        widget.onPick(o.value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final List<BhorOption<T>> shown = _shown;
    final Widget list = shown.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s16, vertical: BhorSpace.s12),
            child: Text(
              context.l10n.dsNoMatch,
              key: const ValueKey<String>('bhor-select-no-match'),
              style: b.type.body.copyWith(color: b.colors.text2),
            ),
          )
        : _OptionList<T>(
            options: shown,
            selected: widget.selected,
            rowHeight: widget.rowHeight,
            autofocusSelected: false,
            onPick: widget.onPick,
          );
    final Widget field = Padding(
      padding: const EdgeInsets.fromLTRB(BhorSpace.s8, BhorSpace.s8, BhorSpace.s8, BhorSpace.s4),
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          // Arrow-down leaves the field for the first option row.
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _field.nextFocus(),
        },
        child: BhorTextField(
          key: const ValueKey<String>('bhor-select-search'),
          controller: _query,
          focusNode: _field,
          autofocus: widget.autofocus,
          hint: widget.hint ?? context.l10n.dsSearchHint,
          prefix: const Icon(BhorIcons.search),
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _pickFirst(),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        field,
        if (widget.bounded)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 4),
              child: list,
            ),
          )
        else
          list,
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
    this.searchable = false,
    this.searchHint,
  });

  final Rect anchor;
  final List<BhorOption<T>> options;
  final T? selected;
  final BhorThemeData theme;
  final bool reduced;
  final bool searchable;
  final String? searchHint;

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
        // The filter field adds its own height, so the list keeps its room.
        delegate: _MenuLayout(
          anchor: anchor,
          padding: MediaQuery.paddingOf(context),
          extra: searchable ? _kSearchFieldHeight : 0,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(BhorRadius.control),
            border: Border.all(color: c.line),
            boxShadow: c.floatShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BhorRadius.control),
            child: searchable
                ? _SearchableOptions<T>(
                    options: options,
                    selected: selected,
                    hint: searchHint,
                    onPick: (T v) => Navigator.of(context).pop(_Pick<T>(v)),
                  )
                : SingleChildScrollView(
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

/// Height of the filter field row (field + its padding) in the popover.
const double _kSearchFieldHeight = BhorSize.field + BhorSpace.s12;

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout({required this.anchor, required this.padding, this.extra = 0});

  final Rect anchor;
  final EdgeInsets padding;

  /// Added to the height cap (the filter field).
  final double extra;

  static const double _gap = 6;
  static const double _maxHeight = 320;

  double _below(Size size) => size.height - padding.bottom - anchor.bottom - _gap - 8;
  double _above() => anchor.top - padding.top - _gap - 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final Size size = constraints.biggest;
    final double room = math.max(_below(size), _above());
    final double width = math.min(math.max(anchor.width, 200), size.width - 16);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(88 + extra, math.min(_maxHeight + extra, room)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bool down = _below(size) >= childSize.height || _below(size) >= _above();
    final double top = down ? anchor.bottom + _gap : anchor.top - _gap - childSize.height;
    final double left = anchor.left.clamp(8, math.max(8, size.width - childSize.width - 8)).toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_MenuLayout old) => old.anchor != anchor || old.padding != padding || old.extra != extra;
}
