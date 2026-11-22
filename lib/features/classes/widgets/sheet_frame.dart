// Shared chrome of the class sheets: a title block over a scrolling body with
// a pinned footer, a tappable labelled row (date, time, batch) and the sheet
// launcher. The drag handle and close button come from the Bhor sheet itself.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

/// Title (and subtitle) and a scrolling [child]; [footer] stays pinned below.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.child, this.subtitle, this.footer});

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: title.isEmpty && subtitle == null ? 0 : BhorSpace.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (title.isNotEmpty) Semantics(header: true, child: Text(title, style: b.type.title)),
              if (subtitle != null) Text(subtitle!, style: b.type.meta),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: BhorSpace.s12, bottom: BhorSpace.s16),
            child: child,
          ),
        ),
        if (footer != null) footer!,
      ],
    );
  }
}

/// The save button pinned under a class sheet, with the reason when disabled.
class ClassSaveBar extends StatelessWidget {
  const ClassSaveBar({super.key, required this.label, required this.onPressed, this.disabledReason, this.loading = false});

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final String? disabledReason;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BhorButton(label: label, expand: true, loading: loading, onPressed: onPressed, disabledReason: disabledReason),
        if (onPressed == null && disabledReason != null) ...<Widget>[
          const SizedBox(height: BhorSpace.s8),
          Text(disabledReason!, textAlign: TextAlign.center, style: b.type.meta),
        ],
      ],
    );
  }
}

/// A tappable labelled row (date, time, batch) with a 56 dp minimum height.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.leading,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return BhorPressable(
      onTap: onTap,
      semanticLabel: '$label, $value',
      excludeChildSemantics: true,
      radius: BhorRadius.control,
      scaleOnPress: false,
      builder: (BuildContext context, BhorStates s) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(BhorSpace.s4),
        decoration: BoxDecoration(
          color: s.hovered ? c.surface2 : c.surface,
          borderRadius: BorderRadius.circular(BhorRadius.control),
          border: Border.all(color: s.hovered ? c.accentLine : c.line),
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) leading! else const SizedBox(width: BhorSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: b.type.meta),
                  Text(value, style: b.type.body),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (icon != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12),
                child: Icon(icon, color: c.text2),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows [builder] in the adaptive container: a bottom sheet on phones
/// ([expand] opens a long form at 60%, drag to full), a centred dialog on
/// desktop ([kind] list = menus, confirm = short forms). The body keeps its
/// own title, scroll and pinned footer ([SheetFrame]).
Future<T?> showClassSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  BhorPanelKind kind = BhorPanelKind.confirm,
  bool expand = false,
  double? width,
  BuildContext? anchor,
  String? title,
  ValueListenable<bool>? dirty,
}) {
  return showBhorPanel<T>(
    context,
    kind: kind,
    anchor: anchor,
    title: title,
    dirty: dirty,
    expand: expand,
    width: width,
    scroll: false,
    builder: builder,
  );
}
