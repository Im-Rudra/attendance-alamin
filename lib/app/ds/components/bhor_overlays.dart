// Overlays on the root navigator / root Overlay (docs/council/13-fluid-ui-spec.md):
// - showBhorSheet / BhorSheetFrame: phone bottom sheet (r28 top, grab
//   handle, spring up, scrim fade, drag to dismiss with velocity, an
//   expanding variant that drags from 60% to full).
// - showBhorSidePanel: desktop floating side panel (inset 10, r20, slides
//   in from the right with the spring; the list behind stays visible under a
//   light dim; Esc / ✕ close).
// - showBhorDialog / showBhorConfirm / BhorDialog: centred card, scale
//   .96 -> 1 + fade + 8 px rise.
// - showBhorPanel: the adaptive container. One API, two renderings: phone
//   -> bottom (or expanding) sheet; desktop (>= 840) -> side panel for forms,
//   centred dialog for confirmations / short choices / lists.
// - showBhorSuccess: inside a sheet or panel, swaps the content for the
//   BhorSuccess check (pop + draw), closes, then shows a toast.
// - BhorToast: floating pill (surface, line edge, soft shadow), spring in,
//   auto-dismiss, above the phone nav pill.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_button.dart';
import 'package:attendance_alamin/app/ds/components/bhor_display.dart' show BhorTone;
import 'package:attendance_alamin/app/ds/components/bhor_motion.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_theme.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

// ------------------------------------------------------------- Insets ----

/// Chrome that overlays must leave visible: the desktop sidebar width
/// ([start]). The shell provides it; [showBhorSidePanel] keeps the sidebar
/// undimmed so navigation stays in view while a panel is open.
class BhorChromeInset extends InheritedWidget {
  const BhorChromeInset({super.key, required this.start, required super.child});

  final double start;

  static double startOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BhorChromeInset>()?.start ?? 0;

  @override
  bool updateShouldNotify(BhorChromeInset oldWidget) => oldWidget.start != start;
}

// -------------------------------------------------------------- Surface ----

/// What sheets and panels share: the success swap and the opener's toast
/// anchor (a context that outlives the sheet).
abstract class _BhorSurface {
  BuildContext get toastAnchor;
  double get toastLift;
  Future<void> playSuccess(String? label);
}

class _SurfaceScope extends InheritedWidget {
  const _SurfaceScope({required this.surface, required super.child});

  final _BhorSurface surface;

  static _BhorSurface? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SurfaceScope>()?.surface;

  @override
  bool updateShouldNotify(_SurfaceScope oldWidget) => oldWidget.surface != surface;
}

/// Success content swap used by both frames.
mixin _SuccessSwap<W extends StatefulWidget> on State<W> {
  String? _successLabel;
  bool _success = false;
  Completer<void>? _done;

  Future<void> playSuccess(String? label) {
    if (_success) return _done?.future ?? Future<void>.value();
    final Completer<void> done = Completer<void>();
    _done = done;
    setState(() {
      _success = true;
      _successLabel = label;
    });
    return done.future;
  }

  Widget successSwap(Widget content) => AnimatedSwitcher(
        duration: BhorMotion.of(context, BhorMotion.base),
        switchInCurve: BhorMotion.ease,
        switchOutCurve: BhorMotion.exitCurve,
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          fit: StackFit.passthrough,
          alignment: AlignmentDirectional.topStart,
          children: <Widget>[...previous, if (current != null) current],
        ),
        child: _success
            ? Padding(
                key: const ValueKey<String>('bhor-success'),
                padding: const EdgeInsets.symmetric(vertical: BhorSpace.s32),
                child: Center(
                  child: BhorSuccess(
                    label: _successLabel,
                    onDone: () {
                      if (!(_done?.isCompleted ?? true)) _done!.complete();
                    },
                  ),
                ),
              )
            : KeyedSubtree(key: const ValueKey<String>('bhor-content'), child: content),
      );

  void disposeSuccess() {
    if (!(_done?.isCompleted ?? true)) _done!.complete();
  }
}

/// Plays the success moment inside the nearest sheet or side panel (the
/// circle pops, the check draws, a short hold), pops that route with
/// [result], then shows [toast] (with optional [toastActions]) on the page
/// behind. Outside a sheet / panel it just pops and toasts.
/// Usage: `await showBhorSuccess(ctx, result: true, toast: '৳১,০০০ জমা হয়েছে')`.
Future<void> showBhorSuccess<T>(
  BuildContext context, {
  T? result,
  String? label,
  String? toast,
  List<BhorToastAction> toastActions = const <BhorToastAction>[],
}) async {
  final _BhorSurface? surface = _SurfaceScope.of(context);
  final NavigatorState nav = Navigator.of(context);
  final BuildContext anchor = surface?.toastAnchor ?? BhorToast.anchorOf(context);
  final double lift = surface?.toastLift ?? BhorToastInset.of(context);
  HapticFeedback.mediumImpact();
  if (surface != null) await surface.playSuccess(label);
  if (nav.mounted && nav.canPop()) nav.pop<T>(result);
  if (toast != null && anchor.mounted && BhorToast.canShowIn(anchor)) {
    BhorToast.show(
      anchor,
      message: toast,
      tone: BhorTone.ok,
      icon: BhorIcons.checkCircleFill,
      actions: toastActions,
      bottomOffset: lift,
      duration: Duration(seconds: toastActions.isEmpty ? 4 : 6),
    );
  }
}

// ---------------------------------------------------------------- Sheet ----

/// Opens a modal bottom sheet on the root navigator (r28 top, grab handle,
/// spring up, safe area, keyboard inset, max width 640). [expanding] opens
/// it at 60% of the window and lets it drag to full height (long forms).
/// [footer] stays pinned under the scrolling content. Pop it with
/// `Navigator.pop(context, v)`.
/// Usage: `final v = await showBhorSheet<int>(context, title: 'ব্যাচ', builder: (c) => ...)`.
Future<T?> showBhorSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool dismissible = true,
  bool expanding = false,
  WidgetBuilder? footer,
}) {
  final BhorThemeData theme = context.bhor;
  final String closeLabel = context.l10n.a11yCloseSheet;
  return Navigator.of(context, rootNavigator: true).push<T>(_BhorSheetRoute<T>(
    builder: builder,
    footer: footer,
    title: title,
    theme: theme,
    closeLabel: closeLabel,
    dismissible: dismissible,
    expanding: expanding,
    reduced: BhorMotion.reduced(context),
    anchor: BhorToast.anchorOf(context),
    lift: BhorToastInset.of(context),
  ));
}

class _BhorSheetRoute<T> extends PopupRoute<T> {
  _BhorSheetRoute({
    required this.builder,
    required this.footer,
    required this.title,
    required this.theme,
    required this.closeLabel,
    required this.dismissible,
    required this.expanding,
    required this.reduced,
    required this.anchor,
    required this.lift,
  });

  final WidgetBuilder builder;
  final WidgetBuilder? footer;
  final String? title;
  final BhorThemeData theme;
  final String closeLabel;
  final bool dismissible;
  final bool expanding;
  final bool reduced;
  final BuildContext anchor;
  final double lift;

  @override
  Color? get barrierColor => theme.colors.scrim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => closeLabel;

  @override
  Duration get transitionDuration => reduced ? BhorMotion.reducedFade : const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => reduced ? BhorMotion.reducedFade : BhorMotion.exit;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return BhorTheme(
      data: theme,
      child: BhorSheetFrame(
        title: title,
        closeLabel: dismissible ? closeLabel : null,
        expanding: expanding,
        toastAnchor: anchor,
        toastLift: lift,
        contentOpacity: reduced
            ? null
            : CurvedAnimation(parent: animation, curve: const Interval(0.08, 0.6, curve: BhorMotion.ease)),
        footer: footer == null ? null : Builder(builder: footer!),
        child: Builder(builder: builder),
      ),
    );
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (reduced) return FadeTransition(opacity: animation, child: child);
    final Animation<double> a =
        CurvedAnimation(parent: animation, curve: BhorMotion.springSoft, reverseCurve: BhorMotion.exitCurve);
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(a),
      child: child,
    );
  }
}

/// The sheet surface itself (also usable inline, e.g. in the gallery).
class BhorSheetFrame extends StatefulWidget {
  const BhorSheetFrame({
    super.key,
    required this.child,
    this.title,
    this.closeLabel,
    this.footer,
    this.expanding = false,
    this.contentOpacity,
    this.toastAnchor,
    this.toastLift = 0,
  });

  final Widget child;
  final String? title;

  /// Accessible name of the close button; null hides it (and the drag).
  final String? closeLabel;

  /// Pinned under the content (save button).
  final Widget? footer;

  /// Opens at 60% and drags to full height.
  final bool expanding;

  /// Fades the content in slightly after the sheet starts to move.
  final Animation<double>? contentOpacity;

  /// Where [showBhorSuccess] puts its toast (the page that opened the sheet).
  final BuildContext? toastAnchor;
  final double toastLift;

  static const double minExtent = 0.6;

  @override
  State<BhorSheetFrame> createState() => _BhorSheetFrameState();
}

class _BhorSheetFrameState extends State<BhorSheetFrame>
    with TickerProviderStateMixin, _SuccessSwap<BhorSheetFrame>
    implements _BhorSurface {
  double _drag = 0;
  bool _dragging = false;
  double _extent = BhorSheetFrame.minExtent;
  late final AnimationController _settle = AnimationController.unbounded(vsync: this)
    ..addListener(() => setState(() => _drag = _settle.value));
  late final AnimationController _grow = AnimationController(vsync: this, value: BhorSheetFrame.minExtent)
    ..addListener(() => setState(() => _extent = _grow.value));

  bool get _canClose => widget.closeLabel != null;

  @override
  BuildContext get toastAnchor => widget.toastAnchor ?? context;

  @override
  double get toastLift => widget.toastLift;

  double _maxHeight(MediaQueryData mq) => mq.size.height * 0.94 - mq.viewPadding.top;

  void _start(DragStartDetails _) {
    _settle.stop();
    _grow.stop();
    setState(() => _dragging = true);
  }

  void _update(DragUpdateDetails d) {
    final double dy = d.delta.dy;
    final double maxH = _maxHeight(MediaQuery.of(context));
    setState(() {
      if (widget.expanding && _drag <= 0) {
        final double next = _extent - dy / maxH;
        if (next >= BhorSheetFrame.minExtent) {
          _extent = next.clamp(BhorSheetFrame.minExtent, 1.0);
          return;
        }
        _extent = BhorSheetFrame.minExtent;
      }
      final double next = _drag + dy;
      // Rubber band upwards (resistance .35), free downwards.
      _drag = next < 0 ? (_drag + dy * 0.35).clamp(-24.0, 0.0) : next;
    });
  }

  void _end(DragEndDetails d) {
    final double v = d.primaryVelocity ?? 0;
    setState(() => _dragging = false);
    if (_drag > 80 || v > 700) {
      if (!widget.expanding || _extent <= BhorSheetFrame.minExtent + 0.01 || _drag > 0) {
        Navigator.of(context).maybePop();
        return;
      }
    }
    final bool reduced = BhorMotion.reduced(context);
    if (widget.expanding) {
      final double target = v > 700
          ? BhorSheetFrame.minExtent
          : (v < -700 || _extent > 0.8 ? 1.0 : BhorSheetFrame.minExtent);
      _grow.value = _extent;
      if (reduced) {
        _grow.value = target;
      } else {
        _grow.animateTo(target, duration: BhorMotion.slow, curve: BhorMotion.spring);
      }
    }
    if (_drag != 0) {
      if (reduced) {
        _settle.value = 0;
      } else {
        _settle.value = _drag;
        _settle.animateWith(SpringSimulation(BhorMotion.springGentle, _drag, 0, v));
      }
    }
  }

  @override
  void dispose() {
    disposeSuccess();
    _settle.dispose();
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final MediaQueryData mq = MediaQuery.of(context);
    final double maxH = _maxHeight(mq);
    final bool keyboard = mq.viewInsets.bottom > 0;
    final Widget handle = Semantics(
      excludeSemantics: true,
      child: SizedBox(
        height: 22,
        child: Center(
          child: AnimatedContainer(
            duration: BhorMotion.of(context, BhorMotion.fast),
            width: _dragging ? 44 : 36,
            height: 5,
            decoration: BoxDecoration(color: _dragging ? c.text3 : c.soft2, borderRadius: BorderRadius.circular(3)),
          ),
        ),
      ),
    );
    final Widget top = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        handle,
        if (widget.title != null || _canClose)
          Padding(
            padding: const EdgeInsets.fromLTRB(BhorSpace.s20, 0, BhorSpace.s12, BhorSpace.s8),
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
                    icon: BhorIcons.close,
                    semanticLabel: widget.closeLabel!,
                    variant: BhorButtonVariant.secondary,
                    size: BhorButtonSize.sm,
                    circle: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
              ],
            ),
          ),
      ],
    );
    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(BhorSpace.s20, 0, BhorSpace.s20, BhorSpace.s16),
      child: DefaultTextStyle(style: b.type.body, child: successSwap(widget.child)),
    );
    if (widget.contentOpacity != null) content = FadeTransition(opacity: widget.contentOpacity!, child: content);
    final bool fixedHeight = widget.expanding;
    final double height = keyboard ? maxH : maxH * _extent;
    final Widget column = Column(
      mainAxisSize: fixedHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_canClose)
          GestureDetector(
            key: const ValueKey<String>('bhor-sheet-handle'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _start,
            onVerticalDragUpdate: _update,
            onVerticalDragEnd: _end,
            child: top,
          )
        else
          top,
        if (fixedHeight) Expanded(child: content) else Flexible(child: content),
        if (widget.footer != null && !_success)
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(BhorSpace.s20, BhorSpace.s12, BhorSpace.s20, BhorSpace.s12),
              child: widget.footer,
            ),
          ),
      ],
    );
    const BorderRadius radius = BorderRadius.vertical(top: Radius.circular(BhorRadius.sheet));
    return _SurfaceScope(
      surface: this,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Transform.translate(
          offset: Offset(0, _drag),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 640, maxHeight: fixedHeight ? height : maxH),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Surface below the bottom edge, visible only while the
                // spring overshoots or the sheet is dragged up.
                Positioned(left: 0, right: 0, top: 40, bottom: -80, child: ColoredBox(color: c.surface)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: radius,
                    border: Border.all(color: c.line),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: mq.viewInsets.bottom + mq.viewPadding.bottom),
                    child: fixedHeight ? SizedBox(height: height, child: column) : column,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- Side panel ----

/// Opens a floating side panel on the root navigator (desktop): a surface
/// card inset 10 px from the right edge, r20, sliding in from the right
/// with the spring. The page behind stays visible under a light dim (the
/// sidebar is left undimmed); a click on the dim, Esc or ✕ closes it.
/// [footer] stays pinned under the scrolling body.
/// Usage: `showBhorSidePanel<bool>(context, title: 'টাকা নিন', builder: (c) => form)`.
Future<T?> showBhorSidePanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  WidgetBuilder? footer,
  bool dismissible = true,
  double width = 480,
  bool scroll = true,
}) {
  final BhorThemeData theme = context.bhor;
  return Navigator.of(context, rootNavigator: true).push<T>(_BhorSidePanelRoute<T>(
    builder: builder,
    footer: footer,
    title: title,
    theme: theme,
    closeLabel: context.l10n.commonClose,
    dismissible: dismissible,
    width: width,
    scroll: scroll,
    reduced: BhorMotion.reduced(context),
    inset: BhorChromeInset.startOf(context),
    anchor: BhorToast.anchorOf(context),
    lift: BhorToastInset.of(context),
  ));
}

class _BhorSidePanelRoute<T> extends PopupRoute<T> {
  _BhorSidePanelRoute({
    required this.builder,
    required this.footer,
    required this.title,
    required this.theme,
    required this.closeLabel,
    required this.dismissible,
    required this.width,
    required this.scroll,
    required this.reduced,
    required this.inset,
    required this.anchor,
    required this.lift,
  });

  final WidgetBuilder builder;
  final WidgetBuilder? footer;
  final String? title;
  final BhorThemeData theme;
  final String closeLabel;
  final bool dismissible;
  final double width;
  final bool scroll;
  final bool reduced;
  final double inset;
  final BuildContext anchor;
  final double lift;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => closeLabel;

  @override
  Duration get transitionDuration => reduced ? BhorMotion.reducedFade : BhorMotion.slow;

  @override
  Duration get reverseTransitionDuration => reduced ? BhorMotion.reducedFade : BhorMotion.exit;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return BhorTheme(
      data: theme,
      child: BhorSidePanelFrame(
        animation: animation,
        title: title,
        closeLabel: dismissible ? closeLabel : null,
        width: width,
        inset: inset,
        scroll: scroll,
        reduced: reduced,
        toastAnchor: anchor,
        toastLift: lift,
        footer: footer == null ? null : Builder(builder: footer!),
        child: Builder(builder: builder),
      ),
    );
  }
}

/// The side panel page: dim + floating card (also usable inline with a
/// completed [animation], e.g. in the gallery).
class BhorSidePanelFrame extends StatefulWidget {
  const BhorSidePanelFrame({
    super.key,
    required this.child,
    this.animation = kAlwaysCompleteAnimation,
    this.title,
    this.closeLabel,
    this.footer,
    this.width = 480,
    this.inset = 0,
    this.scroll = true,
    this.reduced = false,
    this.toastAnchor,
    this.toastLift = 0,
  });

  final Widget child;
  final Animation<double> animation;
  final String? title;

  /// Accessible name of ✕; null hides it (and Esc / outside-click close).
  final String? closeLabel;
  final Widget? footer;
  final double width;

  /// Left part of the window that is not dimmed (the sidebar).
  final double inset;
  final bool scroll;
  final bool reduced;
  final BuildContext? toastAnchor;
  final double toastLift;

  @override
  State<BhorSidePanelFrame> createState() => _BhorSidePanelFrameState();
}

class _BhorSidePanelFrameState extends State<BhorSidePanelFrame>
    with _SuccessSwap<BhorSidePanelFrame>
    implements _BhorSurface {
  @override
  BuildContext get toastAnchor => widget.toastAnchor ?? context;

  @override
  double get toastLift => widget.toastLift;

  void _close() {
    if (widget.closeLabel != null) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    disposeSuccess();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final MediaQueryData mq = MediaQuery.of(context);
    final double w = math.min(widget.width, math.max(280.0, mq.size.width - widget.inset - 20));
    final Animation<double> fade = CurvedAnimation(parent: widget.animation, curve: BhorMotion.ease);
    final Animation<double> slide = CurvedAnimation(
      parent: widget.animation,
      curve: BhorMotion.springSoft,
      reverseCurve: BhorMotion.exitCurve,
    );
    final Widget body = DefaultTextStyle(
      style: b.type.body,
      child: widget.scroll
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(BhorSpace.s20, 0, BhorSpace.s20, BhorSpace.s20),
              child: widget.child,
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(BhorSpace.s20, 0, BhorSpace.s20, BhorSpace.s20),
              child: widget.child,
            ),
    );
    final Widget card = Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(BhorRadius.panel),
        border: Border.all(color: c.line),
        boxShadow: c.floatShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: widget.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(BhorSpace.s20, BhorSpace.s16, BhorSpace.s12, BhorSpace.s12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(header: true, child: Text(widget.title ?? '', style: b.type.title)),
                  ),
                  if (widget.closeLabel != null)
                    BhorIconButton(
                      icon: BhorIcons.close,
                      semanticLabel: widget.closeLabel!,
                      variant: BhorButtonVariant.secondary,
                      size: BhorButtonSize.sm,
                      circle: true,
                      onPressed: _close,
                    ),
                ],
              ),
            ),
            Expanded(child: successSwap(body)),
            if (widget.footer != null && !_success)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(BhorSpace.s20, BhorSpace.s12, BhorSpace.s20, BhorSpace.s16),
                  child: widget.footer,
                ),
              ),
          ],
        ),
      ),
    );
    return _SurfaceScope(
      surface: this,
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(onInvoke: (DismissIntent _) {
            _close();
            return null;
          }),
        },
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): _close,
          },
          child: Focus(
            autofocus: true,
            skipTraversal: true,
            child: _panelStack(context, c, mq, fade, slide, w, card),
          ),
        ),
      ),
    );
  }

  Widget _panelStack(
    BuildContext context,
    BhorColors c,
    MediaQueryData mq,
    Animation<double> fade,
    Animation<double> slide,
    double w,
    Widget card,
  ) =>
      Stack(
          children: <Widget>[
            Positioned(
              left: widget.inset,
              top: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: FadeTransition(opacity: fade, child: ColoredBox(color: c.panelScrim)),
              ),
            ),
            Positioned(
              top: 10 + mq.viewPadding.top,
              right: 10,
              bottom: 10 + mq.viewPadding.bottom,
              width: w,
              child: widget.reduced
                  ? FadeTransition(opacity: fade, child: card)
                  : AnimatedBuilder(
                      animation: slide,
                      builder: (BuildContext context, Widget? child) =>
                          Transform.translate(offset: Offset((1 - slide.value) * (w + 24), 0), child: child),
                      child: card,
                    ),
            ),
          ],
        );
}

// --------------------------------------------------------------- Dialog ----

/// Opens [builder] (usually a [BhorDialog]) centred on the root navigator:
/// scale .96 -> 1 + fade + 8 px rise; exit fade + scale .98.
/// Usage: `showBhorDialog<bool>(context, builder: (c) => BhorDialog(...))`.
Future<T?> showBhorDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  final BhorThemeData theme = context.bhor;
  final bool reduced = BhorMotion.reduced(context);
  final BuildContext anchor = BhorToast.anchorOf(context);
  final double lift = BhorToastInset.of(context);
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: dismissible,
    barrierLabel: context.l10n.commonClose,
    barrierColor: theme.colors.scrim,
    transitionDuration: reduced ? BhorMotion.reducedFade : BhorMotion.slow,
    pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> s) => BhorTheme(
      data: theme,
      child: _DialogSurface(
        anchor: anchor,
        lift: lift,
        child: SafeArea(child: Center(child: Builder(builder: builder))),
      ),
    ),
    transitionBuilder: (BuildContext ctx, Animation<double> a, Animation<double> s, Widget child) {
      final Animation<double> curved = CurvedAnimation(parent: a, curve: BhorMotion.ease, reverseCurve: BhorMotion.exitCurve);
      if (reduced) return FadeTransition(opacity: curved, child: child);
      return FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          builder: (BuildContext context, Widget? c) {
            final bool exiting = a.status == AnimationStatus.reverse;
            return Transform.translate(
              offset: Offset(0, exiting ? 0 : 8 * (1 - curved.value)),
              child: Transform.scale(
                scale: exiting ? 0.98 + 0.02 * curved.value : 0.96 + 0.04 * curved.value,
                child: c,
              ),
            );
          },
          child: child,
        ),
      );
    },
  );
}

/// Gives dialogs the opener's toast anchor (no success swap: dialogs close
/// straight to the toast).
class _DialogSurface extends StatelessWidget implements _BhorSurface {
  const _DialogSurface({required this.anchor, required this.lift, required this.child});

  final BuildContext anchor;
  final double lift;
  final Widget child;

  @override
  BuildContext get toastAnchor => anchor;

  @override
  double get toastLift => lift;

  @override
  Future<void> playSuccess(String? label) => Future<void>.value();

  @override
  Widget build(BuildContext context) => _SurfaceScope(surface: this, child: child);
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
/// (stacked full width on narrow windows). [onClose] adds a ✕.
class BhorDialog extends StatelessWidget {
  const BhorDialog({
    super.key,
    required this.title,
    this.message,
    this.body,
    this.actions = const <Widget>[],
    this.maxWidth = 440,
    this.onClose,
    this.closeLabel,
  });

  final String title;
  final String? message;
  final Widget? body;
  final List<Widget> actions;
  final double maxWidth;
  final VoidCallback? onClose;
  final String? closeLabel;

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
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.all(BhorSpace.s24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(BhorRadius.panel),
          border: Border.all(color: c.line),
          boxShadow: c.floatShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: Text(title, style: b.type.title)),
                if (onClose != null)
                  BhorIconButton(
                    icon: BhorIcons.close,
                    semanticLabel: closeLabel ?? context.l10n.commonClose,
                    variant: BhorButtonVariant.secondary,
                    size: BhorButtonSize.sm,
                    circle: true,
                    onPressed: onClose,
                  ),
              ],
            ),
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

// -------------------------------------------------------- Adaptive panel ----

/// What a [showBhorPanel] holds; picks the desktop container.
enum BhorPanelKind {
  /// Forms (payment, student / batch edit, slot editor, other income,
  /// filters): side panel on desktop.
  form,

  /// Confirmations and short choices: centred dialog on desktop.
  confirm,

  /// Short lists / pickers: centred dialog on desktop.
  list,
}

/// The adaptive container (one API, two renderings). Phone (< 840): a
/// bottom sheet, or an expanding sheet when [expand] (long forms). Desktop:
/// a floating side panel for [BhorPanelKind.form], a centred dialog for
/// [BhorPanelKind.confirm] and [BhorPanelKind.list]. [footer] (the save
/// button) stays pinned under the content in every rendering. Pop with
/// `Navigator.pop(ctx, v)`; finish a save with [showBhorSuccess].
/// Usage:
/// `final ok = await showBhorPanel<bool>(context, title: 'টাকা নিন', builder: (c) => PaymentForm(), footer: (c) => saveButton);`
Future<T?> showBhorPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  BhorPanelKind kind = BhorPanelKind.form,
  String? title,
  WidgetBuilder? footer,
  bool dismissible = true,
  bool expand = false,
  double? width,
  bool scroll = true,
}) {
  if (!context.bhorIsWide) {
    return showBhorSheet<T>(
      context,
      title: title,
      dismissible: dismissible,
      expanding: expand,
      footer: footer,
      builder: scroll ? ((BuildContext c) => SingleChildScrollView(child: builder(c))) : builder,
    );
  }
  if (kind == BhorPanelKind.form) {
    return showBhorSidePanel<T>(
      context,
      title: title,
      footer: footer,
      dismissible: dismissible,
      width: width ?? 480,
      scroll: scroll,
      builder: builder,
    );
  }
  return showBhorDialog<T>(
    context,
    dismissible: dismissible,
    builder: (BuildContext ctx) {
      final Widget content = Builder(builder: builder);
      return BhorDialog(
        title: title ?? '',
        maxWidth: width ?? (kind == BhorPanelKind.list ? 520 : 480),
        onClose: dismissible ? () => Navigator.of(ctx).maybePop() : null,
        body: scroll ? SingleChildScrollView(child: content) : content,
        actions: <Widget>[if (footer != null) Expanded(child: Builder(builder: footer))],
      );
    },
  );
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
/// when the context has one (so it sits above open sheets and panels) and
/// this host otherwise: contexts above the navigator, and the
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
/// (the phone nav pill). The shell provides it; [BhorToast.show] reads it
/// when no explicit `bottomOffset` is passed.
class BhorToastInset extends InheritedWidget {
  const BhorToastInset({super.key, required this.bottom, required super.child});

  final double bottom;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BhorToastInset>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(BhorToastInset oldWidget) => oldWidget.bottom != bottom;
}

/// Short message as a floating pill (surface, line edge, soft shadow),
/// icon + text + pill actions, top or bottom, auto-dismissed after
/// [duration] (null keeps it until an action is tapped). Enters with the
/// spring (y +14, scale .96 -> 1). A new toast replaces the old one. Shown
/// in the root Overlay (else the app's [BhorToastHost]).
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
    final bool reduced = BhorMotion.reduced(context);
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
            reduced: reduced,
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
    required this.reduced,
    required this.onGone,
  });

  final String message;
  final List<BhorToastAction> actions;
  final BhorTone tone;
  final IconData? icon;
  final Duration? duration;
  final bool top;
  final double bottomOffset;
  final bool reduced;
  final VoidCallback onGone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.reduced ? BhorMotion.reducedFade : BhorMotion.slow,
    reverseDuration: widget.reduced ? BhorMotion.reducedFade : const Duration(milliseconds: 180),
  );
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
        variant: BhorButtonVariant.tonal,
        size: BhorButtonSize.sm,
        pill: true,
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
    final Color tint = switch (widget.tone) {
      BhorTone.ok => c.ok,
      BhorTone.danger || BhorTone.overdue => c.danger,
      BhorTone.late => c.late,
      BhorTone.absent => c.absentText,
      BhorTone.warn => c.warn,
      BhorTone.accent || BhorTone.neutral => c.accent,
    };
    final Widget text = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(widget.message, style: b.type.body.copyWith(fontWeight: FontWeight.w500)),
    );
    final bool two = widget.actions.length > 1;
    final Widget card = Container(
      constraints: const BoxConstraints(maxWidth: 480, minHeight: 52),
      padding: EdgeInsets.fromLTRB(widget.icon == null ? 20 : 14, 4, widget.actions.isEmpty ? 20 : 6, 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(two ? 24 : BhorRadius.pill),
        border: Border.all(color: c.line),
        boxShadow: c.floatShadow,
      ),
      child: DefaultTextStyle(
        style: b.type.body,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: two ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: <Widget>[
            if (widget.icon != null) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(top: two ? 11 : 0),
                child: Icon(widget.icon, size: BhorIconSize.row, color: tint),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
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
                          spacing: 6,
                          children: <Widget>[for (final BhorToastAction a in widget.actions) _button(a)],
                        ),
                      ],
                    )
                  : text,
            ),
            if (widget.actions.length == 1) ...<Widget>[
              const SizedBox(width: 8),
              _button(widget.actions.first),
            ],
          ],
        ),
      ),
    );
    final Animation<double> fade = CurvedAnimation(parent: _c, curve: BhorMotion.ease, reverseCurve: BhorMotion.exitCurve);
    final Animation<double> move = CurvedAnimation(parent: _c, curve: BhorMotion.spring, reverseCurve: BhorMotion.exitCurve);
    final double dir = widget.top ? -1 : 1;
    return Positioned(
      left: BhorSpace.s16,
      right: BhorSpace.s16,
      top: widget.top ? mq.viewPadding.top + BhorSpace.s16 : null,
      bottom: widget.top ? null : mq.viewPadding.bottom + mq.viewInsets.bottom + BhorSpace.s12 + widget.bottomOffset,
      child: FadeTransition(
        opacity: fade,
        child: AnimatedBuilder(
          animation: move,
          builder: (BuildContext context, Widget? child) => widget.reduced
              ? child!
              : Transform.translate(
                  offset: Offset(0, dir * 14 * (1 - move.value)),
                  child: Transform.scale(scale: 0.96 + 0.04 * move.value, child: child),
                ),
          child: Semantics(liveRegion: true, container: true, child: Center(child: card)),
        ),
      ),
    );
  }
}
