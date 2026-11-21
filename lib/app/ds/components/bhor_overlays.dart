// Overlays on the root navigator / root Overlay: BhorSheet (modal bottom
// sheet with drag handle), BhorDialog (+ confirm helper) and BhorToast.

import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_button.dart';
import 'package:attendance_alamin/app/ds/components/bhor_display.dart' show BhorTone;
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

// ---------------------------------------------------------------- Sheet ----

/// Opens a modal bottom sheet on the root navigator (drag handle, safe area,
/// keyboard inset, max width 640). Pop it with `Navigator.pop(context, v)`.
/// Usage: `final v = await showBhorSheet<int>(context, title: 'ব্যাচ', builder: (c) => ...)`.
Future<T?> showBhorSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool dismissible = true,
}) {
  final BhorThemeData theme = context.bhor;
  final String closeLabel = context.l10n.a11yCloseSheet;
  return Navigator.of(context, rootNavigator: true).push<T>(_BhorSheetRoute<T>(
    builder: builder,
    title: title,
    theme: theme,
    closeLabel: closeLabel,
    dismissible: dismissible,
  ));
}

class _BhorSheetRoute<T> extends PopupRoute<T> {
  _BhorSheetRoute({
    required this.builder,
    required this.title,
    required this.theme,
    required this.closeLabel,
    required this.dismissible,
  });

  final WidgetBuilder builder;
  final String? title;
  final BhorThemeData theme;
  final String closeLabel;
  final bool dismissible;

  @override
  Color? get barrierColor => theme.colors.scrim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => closeLabel;

  @override
  Duration get transitionDuration => BhorMotion.slow;

  @override
  Duration get reverseTransitionDuration => BhorMotion.base;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return BhorTheme(
      data: theme,
      child: BhorSheetFrame(
        title: title,
        closeLabel: dismissible ? closeLabel : null,
        child: Builder(builder: builder),
      ),
    );
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final Animation<double> a = CurvedAnimation(parent: animation, curve: BhorMotion.curve);
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(a),
      child: child,
    );
  }
}

/// The sheet surface itself (also usable inline, e.g. in the gallery).
class BhorSheetFrame extends StatefulWidget {
  const BhorSheetFrame({super.key, required this.child, this.title, this.closeLabel});

  final Widget child;
  final String? title;

  /// Accessible name of the close button; null hides it (and the drag).
  final String? closeLabel;

  @override
  State<BhorSheetFrame> createState() => _BhorSheetFrameState();
}

class _BhorSheetFrameState extends State<BhorSheetFrame> {
  double _drag = 0;

  bool get _canClose => widget.closeLabel != null;

  void _end(DragEndDetails d) {
    if (_drag > 80 || (d.primaryVelocity ?? 0) > 700) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final MediaQueryData mq = MediaQuery.of(context);
    final Widget handle = Semantics(
      excludeSemantics: true,
      child: SizedBox(
        height: 20,
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ),
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640, maxHeight: mq.size.height * 0.9),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(BhorRadius.sheet)),
              border: Border.all(color: c.line),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: mq.viewInsets.bottom + mq.viewPadding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_canClose)
                    GestureDetector(
                      key: const ValueKey<String>('bhor-sheet-handle'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (DragUpdateDetails d) =>
                          setState(() => _drag = (_drag + d.delta.dy).clamp(0, double.infinity)),
                      onVerticalDragEnd: _end,
                      child: handle,
                    )
                  else
                    handle,
                  if (widget.title != null || _canClose)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(BhorSpace.s20, 0, BhorSpace.s8, BhorSpace.s4),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(widget.title ?? '', style: b.type.title),
                            ),
                          ),
                          if (_canClose)
                            BhorIconButton(
                              icon: Icons.close_rounded,
                              semanticLabel: widget.closeLabel!,
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                        ],
                      ),
                    ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(BhorSpace.s20, 0, BhorSpace.s20, BhorSpace.s16),
                      child: DefaultTextStyle(style: b.type.body, child: widget.child),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Dialog ----

/// Opens [builder] (usually a [BhorDialog]) centred on the root navigator.
/// Usage: `showBhorDialog<bool>(context, builder: (c) => BhorDialog(...))`.
Future<T?> showBhorDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  final BhorThemeData theme = context.bhor;
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: dismissible,
    barrierLabel: context.l10n.commonClose,
    barrierColor: theme.colors.scrim,
    transitionDuration: BhorMotion.slow,
    pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> s) =>
        BhorTheme(data: theme, child: SafeArea(child: Center(child: Builder(builder: builder)))),
    transitionBuilder: (BuildContext ctx, Animation<double> a, Animation<double> s, Widget child) {
      final Animation<double> curved = CurvedAnimation(parent: a, curve: BhorMotion.curve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(curved), child: child),
      );
    },
  );
}

/// Asks a yes/no question; true only when confirmed.
/// Usage: `if (await showBhorConfirm(context, title: 'মুছবেন?', confirmLabel: 'মুছুন', destructive: true)) ...`.
Future<bool> showBhorConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final String cancel = cancelLabel ?? context.l10n.commonCancel;
  final bool? ok = await showBhorDialog<bool>(
    context,
    builder: (BuildContext ctx) => BhorDialog(
      title: title,
      message: message,
      actions: <Widget>[
        BhorButton(
          label: cancel,
          variant: BhorButtonVariant.secondary,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        BhorButton(
          label: confirmLabel,
          variant: destructive ? BhorButtonVariant.danger : BhorButtonVariant.primary,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Dialog card: title, optional message/body and end-aligned actions
/// (stacked full width on narrow windows).
class BhorDialog extends StatelessWidget {
  const BhorDialog({super.key, required this.title, this.message, this.body, this.actions = const <Widget>[]});

  final String title;
  final String? message;
  final Widget? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool narrow = (MediaQuery.maybeSizeOf(context)?.width ?? 400) < 420;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Container(
        margin: const EdgeInsets.all(BhorSpace.s16),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(BhorSpace.s24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(BhorRadius.sheet),
          border: Border.all(color: c.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: b.type.title),
            if (message != null) ...<Widget>[
              const SizedBox(height: BhorSpace.s8),
              Text(message!, style: b.type.body.copyWith(color: c.text2)),
            ],
            if (body != null) ...<Widget>[
              const SizedBox(height: BhorSpace.s16),
              Flexible(child: DefaultTextStyle(style: b.type.body, child: body!)),
            ],
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: BhorSpace.s24),
              if (narrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int i = actions.length - 1; i >= 0; i--) ...<Widget>[
                      actions[i],
                      if (i > 0) const SizedBox(height: BhorSpace.s8),
                    ],
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    for (int i = 0; i < actions.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: BhorSpace.s8),
                      actions[i],
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------- Toast ----

/// Lets the caller close a toast early.
class BhorToastHandle {
  BhorToastHandle._(this._dismiss);

  final VoidCallback _dismiss;

  void dismiss() => _dismiss();
}

/// One button of a toast (a toast carries at most two).
class BhorToastAction {
  const BhorToastAction({required this.label, required this.onPressed, this.key});

  final String label;
  final VoidCallback onPressed;

  /// Key of the button (tests and automation tap it).
  final Key? key;
}

/// App-level home of toasts that have no navigator to sit in: put it once at
/// the root (above the navigator). [BhorToast.show] uses the root Overlay
/// when the context has one (so a sheet opened later covers the toast, as
/// before) and this host otherwise: contexts above the navigator, and the
/// [BhorToast.anchorOf] context services keep across an async gap.
class BhorToastHost extends StatefulWidget {
  const BhorToastHost({super.key, required this.child});

  final Widget child;

  @override
  State<BhorToastHost> createState() => _BhorToastHostState();
}

class _BhorToastHostState extends State<BhorToastHost> {
  final List<(Key, WidgetBuilder)> _toasts = <(Key, WidgetBuilder)>[];

  /// Adds a toast; the returned callback removes it.
  VoidCallback _insert(WidgetBuilder builder) {
    final Key key = UniqueKey();
    setState(() => _toasts.add((key, builder)));
    return () {
      if (!mounted) return;
      setState(() => _toasts.removeWhere(((Key, WidgetBuilder) t) => t.$1 == key));
    };
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          widget.child,
          for (final (Key key, WidgetBuilder builder) in _toasts)
            KeyedSubtree(key: key, child: Builder(builder: builder)),
        ],
      );
}

/// Lifts bottom toasts above chrome that covers the bottom of the window
/// (the phone bottom nav). The shell provides it; [BhorToast.show] reads it
/// when no explicit `bottomOffset` is passed.
class BhorToastInset extends InheritedWidget {
  const BhorToastInset({super.key, required this.bottom, required super.child});

  final double bottom;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BhorToastInset>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(BhorToastInset oldWidget) => oldWidget.bottom != bottom;
}

/// Short message, top or bottom, with up to two actions, auto-dismissed after
/// [duration] (null keeps it until an action is tapped). A new toast replaces
/// the old one. Shown in the app's [BhorToastHost] (else the root Overlay).
/// Usage: `BhorToast.show(context, message: 'সংরক্ষিত', actionLabel: 'ফেরান', onAction: undo)`
/// or `actions: [BhorToastAction(label: 'রসিদ পাঠান', onPressed: send), BhorToastAction(...)]`.
abstract final class BhorToast {
  static _ToastViewState? _current;

  /// The host at or above [context] (the anchor context is the host's own).
  static _BhorToastHostState? _hostOf(BuildContext context) {
    if (context is StatefulElement && context.state is _BhorToastHostState) {
      return context.state as _BhorToastHostState;
    }
    return context.findAncestorStateOfType<_BhorToastHostState>();
  }

  /// True when [show] has somewhere to put a toast from [context].
  static bool canShowIn(BuildContext context) =>
      Overlay.maybeOf(context, rootOverlay: true) != null || _hostOf(context) != null;

  /// A context that outlives [context] for showing a toast after an async
  /// gap (the host's own context; [context] itself without a host). Read
  /// `BhorToastInset.of(context)` before the gap too and pass it as
  /// `bottomOffset`.
  static BuildContext anchorOf(BuildContext context) =>
      _hostOf(context)?.context ?? context;

  static BhorToastHandle show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    List<BhorToastAction> actions = const <BhorToastAction>[],
    BhorTone tone = BhorTone.neutral,
    IconData? icon,
    Duration? duration = const Duration(seconds: 4),
    bool top = false,
    double? bottomOffset,
  }) {
    final List<BhorToastAction> all = <BhorToastAction>[
      if (actionLabel != null) BhorToastAction(label: actionLabel, onPressed: onAction ?? () {}),
      ...actions,
    ];
    assert(all.length <= 2, 'A BhorToast carries at most two actions');
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    final _BhorToastHostState? host = overlay == null ? _hostOf(context) : null;
    if (host == null && overlay == null) return BhorToastHandle._(() {});
    final BhorThemeData theme = context.bhor;
    final double lift = bottomOffset ?? BhorToastInset.of(context);
    _current?.dismiss();
    final GlobalKey<_ToastViewState> key = GlobalKey<_ToastViewState>();
    VoidCallback remove = () {};
    Widget build(BuildContext ctx) => BhorTheme(
          data: theme,
          child: _ToastView(
            key: key,
            message: message,
            actions: all,
            tone: tone,
            icon: icon,
            duration: duration,
            top: top,
            bottomOffset: lift,
            onGone: () => remove(),
          ),
        );
    if (host != null) {
      remove = host._insert(build);
    } else {
      final OverlayEntry entry = OverlayEntry(builder: build);
      overlay!.insert(entry);
      remove = () {
        if (entry.mounted) entry.remove();
      };
    }
    return BhorToastHandle._(() => key.currentState?.dismiss());
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.message,
    required this.actions,
    required this.tone,
    required this.icon,
    required this.duration,
    required this.top,
    required this.bottomOffset,
    required this.onGone,
  });

  final String message;
  final List<BhorToastAction> actions;
  final BhorTone tone;
  final IconData? icon;
  final Duration? duration;
  final bool top;
  final double bottomOffset;
  final VoidCallback onGone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BhorMotion.slow);
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    BhorToast._current = this;
    _c.forward();
    final Duration? d = widget.duration;
    if (d != null) _timer = Timer(d, dismiss);
  }

  void dismiss() {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    if (BhorToast._current == this) BhorToast._current = null;
    _c.reverse().whenCompleteOrCancel(widget.onGone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (BhorToast._current == this) BhorToast._current = null;
    _c.dispose();
    super.dispose();
  }

  Widget _button(BhorToastAction a) => BhorButton(
        key: a.key,
        label: a.label,
        variant: BhorButtonVariant.ghost,
        size: BhorButtonSize.sm,
        onPressed: () {
          dismiss();
          a.onPressed();
        },
      );

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final MediaQueryData mq = MediaQuery.of(context);
    final Color edge = switch (widget.tone) {
      BhorTone.ok => c.ok,
      BhorTone.danger => c.danger,
      BhorTone.late => c.lateText,
      BhorTone.absent => c.absent,
      BhorTone.accent || BhorTone.neutral => c.accent,
    };
    final Widget text = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(widget.message, style: b.type.body),
    );
    final bool two = widget.actions.length > 1;
    final Widget card = Container(
      constraints: const BoxConstraints(maxWidth: 480, minHeight: BhorSize.control + 8),
      padding: const EdgeInsets.fromLTRB(BhorSpace.s12, 6, 6, 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(BhorRadius.control),
        border: Border.all(color: c.line),
      ),
      child: DefaultTextStyle(
        style: b.type.body,
        child: Row(
          crossAxisAlignment: two ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 3,
              height: 24,
              margin: EdgeInsets.only(right: BhorSpace.s12, top: two ? 6 : 0),
              decoration: BoxDecoration(color: edge, borderRadius: BorderRadius.circular(2)),
            ),
            if (widget.icon != null) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(top: two ? 9 : 0),
                child: Icon(widget.icon, size: 18, color: edge),
              ),
              const SizedBox(width: BhorSpace.s8),
            ],
            Expanded(
              child: two
                  // Two actions: the message on top, the buttons under it, so
                  // long Bangla labels never squeeze the text.
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        text,
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: <Widget>[for (final BhorToastAction a in widget.actions) _button(a)],
                        ),
                      ],
                    )
                  : text,
            ),
            if (widget.actions.length == 1)
              _button(widget.actions.first)
            else if (!two)
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
    final Animation<double> a = CurvedAnimation(parent: _c, curve: BhorMotion.curve);
    return Positioned(
      left: BhorSpace.s16,
      right: BhorSpace.s16,
      top: widget.top ? mq.viewPadding.top + BhorSpace.s16 : null,
      bottom: widget.top ? null : mq.viewPadding.bottom + mq.viewInsets.bottom + BhorSpace.s16 + widget.bottomOffset,
      child: FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(begin: Offset(0, widget.top ? -0.4 : 0.4), end: Offset.zero).animate(a),
          child: Semantics(liveRegion: true, container: true, child: Center(child: card)),
        ),
      ),
    );
  }
}
