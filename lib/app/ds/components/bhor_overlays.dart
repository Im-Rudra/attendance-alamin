// Overlays on the root navigator / root Overlay (docs/council/13-fluid-ui-spec.md):
// - showBhorSheet / BhorSheetFrame: phone bottom sheet (r28 top, grab
//   handle, spring up, scrim fade, drag to dismiss with velocity). Opens at
//   its content height up to 92% (nothing below the fold), content scrolls,
//   the footer stays pinned above the keyboard; the expanding variant drags
//   up to full height.
// - showBhorPopover / BhorPopoverFrame: desktop popover anchored to the
//   invoking control (grows from the anchor corner, flips near edges, Esc /
//   outside click closes); centred dialog when there is no anchor.
// - showBhorSidePanel: desktop floating side panel (inset 10, r20, slides
//   in from the right with the spring; the list behind stays visible under a
//   light dim; Esc / ✕ close).
// - showBhorDialog / showBhorConfirm / BhorDialog: centred card, scale
//   .96 -> 1 + fade + 8 px rise.
// - showBhorPanel: the adaptive container. One API, two renderings: phone
//   -> bottom (or expanding) sheet; desktop (>= 840) -> side panel for forms,
//   centred dialog for confirmations, anchored popover for lists / menus /
//   pickers.
// - showBhorSuccess: inside a sheet or panel, swaps the content for the
//   BhorSuccess check (pop + draw), closes, then shows a toast.
// - BhorToast: floating pill (surface, line edge, soft shadow), spring in,
//   auto-dismiss, above the phone nav pill and any pinned save bar / sheet
//   footer (BhorBottomObstruction); a replaced toast leaves before the new
//   one enters.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show HitTestEntry, HitTestResult, HitTestTarget;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_button.dart';
import 'package:attendance_alamin/app/ds/components/bhor_display.dart' show BhorTone;
import 'package:attendance_alamin/app/ds/components/bhor_motion.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_icons.dart';
import 'package:attendance_alamin/app/ds/foundation/bhor_interaction.dart' show BhorTapTracker;
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

  /// Fade-through: the form fades out completely (first 40%) before the
  /// check fades in, so the two are never legible together.
  Widget successSwap(Widget content) => AnimatedSwitcher(
        duration: BhorMotion.of(context, BhorMotion.base),
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          fit: StackFit.passthrough,
          alignment: AlignmentDirectional.topStart,
          children: <Widget>[...previous, if (current != null) current],
        ),
        transitionBuilder: (Widget child, Animation<double> a) => FadeTransition(
          opacity: CurvedAnimation(
            parent: a,
            curve: child.key == const ValueKey<String>('bhor-success')
                ? const Interval(0.4, 1, curve: BhorMotion.ease)
                : const Interval(0.6, 1, curve: BhorMotion.ease),
          ),
          child: child,
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
/// spring up, safe area, keyboard inset, max width 640). It opens at its
/// content height, up to 92% of the window ([BhorSheetFrame.maxFraction]);
/// [expanding] also lets it drag up to that full height (long forms).
/// [footer] stays pinned under the scrolling content, above the keyboard.
/// Pop it with
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
///
/// It opens at its content's height, up to [maxFraction] of the window, so
/// nothing starts below the fold; taller content scrolls inside while the
/// [footer] stays pinned (above the keyboard too). [expanding] sheets can
/// also be dragged up to the full [maxFraction] height and back.
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

  /// Can be dragged up to the full height.
  final bool expanding;

  /// Fades the content in slightly after the sheet starts to move.
  final Animation<double>? contentOpacity;

  /// Where [showBhorSuccess] puts its toast (the page that opened the sheet).
  final BuildContext? toastAnchor;
  final double toastLift;

  /// Tallest a sheet gets, as a share of the window height.
  static const double maxFraction = 0.92;

  /// Older name kept for callers. Sheets now open at their content height.
  static const double minExtent = 0.6;

  /// Height available to the sheet body (handle, content and footer) in a
  /// window described by [mq]: at most [maxFraction] of the window, and
  /// always clear of the status bar and the keyboard.
  static double maxBodyHeight(MediaQueryData mq) {
    final double room =
        mq.size.height - mq.viewPadding.top - BhorSpace.s8 - mq.viewInsets.bottom - mq.viewPadding.bottom;
    return math.max(120.0, math.min(mq.size.height * maxFraction, room));
  }

  @override
  State<BhorSheetFrame> createState() => _BhorSheetFrameState();
}

class _BhorSheetFrameState extends State<BhorSheetFrame>
    with TickerProviderStateMixin, _SuccessSwap<BhorSheetFrame>
    implements _BhorSurface {
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'bhor-sheet-body');

  /// Downward offset while dragged towards dismissal.
  double _drag = 0;
  bool _dragging = false;

  /// Explicit body height while expanded / dragged up; null = content height.
  double? _height;

  /// Content height measured when a drag starts.
  double _natural = 0;

  late final AnimationController _settle = AnimationController.unbounded(vsync: this)
    ..addListener(() => setState(() => _drag = _settle.value));
  late final AnimationController _grow = AnimationController.unbounded(vsync: this)
    ..addListener(() => setState(() => _height = _grow.value));

  bool get _canClose => widget.closeLabel != null;

  @override
  BuildContext get toastAnchor => widget.toastAnchor ?? context;

  @override
  double get toastLift => widget.toastLift;

  double _bodyHeightNow() {
    final RenderObject? ro = _bodyKey.currentContext?.findRenderObject();
    return ro is RenderBox && ro.hasSize ? ro.size.height : 0;
  }

  void _start(DragStartDetails _) {
    _settle.stop();
    _grow.stop();
    if (_height == null) _natural = _bodyHeightNow();
    setState(() => _dragging = true);
  }

  void _update(DragUpdateDetails d) {
    final double dy = d.delta.dy;
    final double maxH = BhorSheetFrame.maxBodyHeight(MediaQuery.of(context));
    setState(() {
      if (widget.expanding && _drag <= 0 && _natural < maxH - 1) {
        final double next = (_height ?? _natural) - dy;
        if (next > _natural) {
          _height = math.min(next, maxH);
          return;
        }
        _height = null;
      }
      final double next = _drag + dy;
      // Rubber band upwards (resistance .35), free downwards.
      _drag = next < 0 ? (_drag + dy * 0.35).clamp(-24.0, 0.0) : next;
    });
  }

  void _end(DragEndDetails d) {
    final double v = d.primaryVelocity ?? 0;
    setState(() => _dragging = false);
    final bool expanded = _height != null && _height! > _natural + 1;
    if ((_drag > 80 || v > 700) && !expanded) {
      Navigator.of(context).maybePop();
      return;
    }
    final bool reduced = BhorMotion.reduced(context);
    final double? from = _height;
    if (from != null) {
      final double maxH = BhorSheetFrame.maxBodyHeight(MediaQuery.of(context));
      final bool toFull = v < -700 || (v <= 700 && from - _natural > (maxH - _natural) / 2);
      final double target = toFull ? maxH : _natural;
      void finish() {
        if (mounted && !toFull) setState(() => _height = null);
      }

      if (reduced) {
        setState(() => _height = target);
        finish();
      } else {
        _grow.value = from;
        _grow.animateWith(SpringSimulation(BhorMotion.springGentle, from, target, -v)).whenCompleteOrCancel(finish);
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
    final double maxH = BhorSheetFrame.maxBodyHeight(mq);
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
    final double? height = _height == null ? null : math.min(_height!, maxH);
    final Widget column = Column(
      mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
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
        if (height == null) Flexible(child: content) else Expanded(child: content),
        if (widget.footer != null && !_success)
          BhorBottomObstruction(
            child: DecoratedBox(
              key: const ValueKey<String>('bhor-sheet-footer'),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(BhorSpace.s20, BhorSpace.s12, BhorSpace.s20, BhorSpace.s12),
                child: widget.footer,
              ),
            ),
          ),
      ],
    );
    final Widget body = KeyedSubtree(
      key: _bodyKey,
      child: height == null
          ? ConstrainedBox(constraints: BoxConstraints(maxHeight: maxH), child: column)
          : SizedBox(height: height, child: column),
    );
    const BorderRadius radius = BorderRadius.vertical(top: Radius.circular(BhorRadius.sheet));
    return _SurfaceScope(
      surface: this,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Transform.translate(
          offset: Offset(0, _drag),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
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
                    child: body,
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
              BhorBottomObstruction(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(BhorSpace.s20, BhorSpace.s12, BhorSpace.s20, BhorSpace.s16),
                    child: widget.footer,
                  ),
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
  /// filters): side panel on desktop; on phones a sheet that opens at its
  /// content height and drags up to full height.
  form,

  /// Confirmations and short choices: centred dialog on desktop.
  confirm,

  /// Short lists of choices: a popover anchored to the control that opened
  /// it on desktop (a centred dialog when there is no such control).
  list,

  /// Overflow (⋮) and row menus: an anchored popover on desktop.
  menu,

  /// Date / time / value pickers: an anchored popover on desktop.
  picker,
}

/// The adaptive container (one API, two renderings). Phone (< 840): a
/// bottom sheet that opens at its content height (up to 92%); [expand] (and
/// every [BhorPanelKind.form]) lets it drag up to full height. Desktop: a
/// floating side panel for [BhorPanelKind.form], a centred dialog for
/// [BhorPanelKind.confirm], and a popover anchored to the invoking widget
/// for [BhorPanelKind.list] / [BhorPanelKind.menu] / [BhorPanelKind.picker].
/// The anchor is [anchor] when given, else [context] itself when it is a
/// control (a button's context), else the control the user just tapped;
/// with none of those it falls back to a centred dialog. [footer] (the save
/// button) stays pinned under the content in every rendering. Pop with
/// `Navigator.pop(ctx, v)`; finish a save with [showBhorSuccess].
/// Usage:
/// `final ok = await showBhorPanel<bool>(context, title: 'টাকা নিন', builder: (c) => PaymentForm(), footer: (c) => saveButton);`
/// `showBhorPanel<void>(buttonContext, kind: BhorPanelKind.menu, builder: (c) => rows);`
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
  BuildContext? anchor,
}) {
  if (!context.bhorIsWide) {
    return showBhorSheet<T>(
      context,
      title: title,
      dismissible: dismissible,
      expanding: expand || kind == BhorPanelKind.form,
      footer: footer,
      builder: scroll ? ((BuildContext c) => SingleChildScrollView(child: builder(c))) : builder,
    );
  }
  switch (kind) {
    case BhorPanelKind.form:
      return showBhorSidePanel<T>(
        context,
        title: title,
        footer: footer,
        dismissible: dismissible,
        width: width ?? 480,
        scroll: scroll,
        builder: builder,
      );
    case BhorPanelKind.list:
    case BhorPanelKind.menu:
    case BhorPanelKind.picker:
      return showBhorPopover<T>(
        context,
        anchor: anchor,
        title: title,
        footer: footer,
        dismissible: dismissible,
        width: width ?? (kind == BhorPanelKind.menu ? 280 : 340),
        scroll: scroll,
        padding: kind == BhorPanelKind.picker
            ? const EdgeInsets.fromLTRB(BhorSpace.s12, 0, BhorSpace.s12, BhorSpace.s12)
            : const EdgeInsets.fromLTRB(BhorSpace.s4, 0, BhorSpace.s4, BhorSpace.s4),
        builder: builder,
      );
    case BhorPanelKind.confirm:
      return _showPanelDialog<T>(context,
          builder: builder, title: title, footer: footer, dismissible: dismissible, width: width ?? 480, scroll: scroll);
  }
}

Future<T?> _showPanelDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required String? title,
  required WidgetBuilder? footer,
  required bool dismissible,
  required double width,
  required bool scroll,
}) =>
    showBhorDialog<T>(
      context,
      dismissible: dismissible,
      builder: (BuildContext ctx) {
        final Widget content = Builder(builder: builder);
        return BhorDialog(
          title: title ?? '',
          maxWidth: width,
          onClose: dismissible ? () => Navigator.of(ctx).maybePop() : null,
          body: scroll ? SingleChildScrollView(child: content) : content,
          actions: <Widget>[if (footer != null) Expanded(child: Builder(builder: footer))],
        );
      },
    );

// -------------------------------------------------------------- Popover ----

/// The rect of the control [context] belongs to, in the coordinates of the
/// root navigator, or null when there is no control to anchor to.
Rect? bhorAnchorRect(BuildContext context) {
  final NavigatorState? nav = Navigator.maybeOf(context, rootNavigator: true);
  final RenderObject? navObject = nav?.context.findRenderObject();
  if (navObject is! RenderBox || !navObject.hasSize) return null;
  final RenderBox navBox = navObject;
  final Size area = navBox.size;
  bool control(Rect r) =>
      r.width > 0 && r.height > 0 && r.width <= area.width * 0.6 && r.height <= area.height * 0.4;
  Rect? own;
  if (context.mounted) {
    final RenderObject? ro = context.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      own = ro.localToGlobal(Offset.zero, ancestor: navBox) & ro.size;
      if (control(own)) return own;
    }
  }
  // A whole-screen context: anchor to the control the user just tapped.
  final Offset? tap = BhorTapTracker.position;
  final int? viewId = BhorTapTracker.viewId;
  if (tap == null || viewId == null) return null;
  final Offset local = navBox.globalToLocal(tap);
  if (own != null && !own.contains(local)) return null;
  final HitTestResult hit = HitTestResult();
  WidgetsBinding.instance.hitTestInView(hit, tap, viewId);
  for (final HitTestEntry e in hit.path) {
    final HitTestTarget t = e.target;
    if (t is RenderBox && t.attached && t.hasSize && t.size.width >= 32 && t.size.height >= 32) {
      final Rect r = t.localToGlobal(Offset.zero, ancestor: navBox) & t.size;
      return control(r) ? r : null;
    }
  }
  return null;
}

/// Opens [builder] in a floating popover anchored to the control that
/// opened it (see [bhorAnchorRect]): it drops from the anchor's corner
/// (scale .96 -> 1 + fade), opens below the anchor or flips above it near
/// the bottom edge, aligns to the anchor's start or end edge, and scrolls
/// when it is taller than the room. Esc, ✕ or a click outside closes it.
/// Without an anchor it falls back to a centred dialog.
/// Usage: `showBhorPopover<String>(buttonContext, title: 'ব্যাচ', builder: (c) => rows)`.
Future<T?> showBhorPopover<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  WidgetBuilder? footer,
  bool dismissible = true,
  double width = 320,
  bool scroll = true,
  EdgeInsets padding = const EdgeInsets.fromLTRB(BhorSpace.s4, 0, BhorSpace.s4, BhorSpace.s4),
  BuildContext? anchor,
}) {
  final Rect? rect = bhorAnchorRect(anchor ?? context);
  if (rect == null) {
    return _showPanelDialog<T>(context,
        builder: builder, title: title, footer: footer, dismissible: dismissible, width: width + 60, scroll: scroll);
  }
  return Navigator.of(context, rootNavigator: true).push<T>(_BhorPopoverRoute<T>(
    anchor: rect,
    builder: builder,
    footer: footer,
    title: title,
    theme: context.bhor,
    closeLabel: context.l10n.commonClose,
    dismissible: dismissible,
    width: width,
    scroll: scroll,
    padding: padding,
    reduced: BhorMotion.reduced(context),
    toastAnchor: BhorToast.anchorOf(context),
    lift: BhorToastInset.of(context),
  ));
}

class _BhorPopoverRoute<T> extends PopupRoute<T> {
  _BhorPopoverRoute({
    required this.anchor,
    required this.builder,
    required this.footer,
    required this.title,
    required this.theme,
    required this.closeLabel,
    required this.dismissible,
    required this.width,
    required this.scroll,
    required this.padding,
    required this.reduced,
    required this.toastAnchor,
    required this.lift,
  });

  final Rect anchor;
  final WidgetBuilder builder;
  final WidgetBuilder? footer;
  final String? title;
  final BhorThemeData theme;
  final String closeLabel;
  final bool dismissible;
  final double width;
  final bool scroll;
  final EdgeInsets padding;
  final bool reduced;
  final BuildContext toastAnchor;
  final double lift;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => closeLabel;

  @override
  Duration get transitionDuration => reduced ? BhorMotion.reducedFade : const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => reduced ? BhorMotion.reducedFade : const Duration(milliseconds: 130);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return BhorTheme(
      data: theme,
      child: _DialogSurface(
        anchor: toastAnchor,
        lift: lift,
        child: BhorPopoverFrame(
          anchor: anchor,
          animation: animation,
          title: title,
          closeLabel: dismissible ? closeLabel : null,
          width: width,
          scroll: scroll,
          padding: padding,
          reduced: reduced,
          footer: footer == null ? null : Builder(builder: footer!),
          child: Builder(builder: builder),
        ),
      ),
    );
  }
}

/// Where a popover sits relative to its anchor.
class BhorPopoverPlacement {
  const BhorPopoverPlacement({required this.rect, required this.below, required this.alignStart});

  /// Left / top / width / max height of the popover (height is the most it
  /// may take; the card hugs its content).
  final Rect rect;

  /// Opens under the anchor (false: flipped above it).
  final bool below;

  /// Left edge aligned to the anchor's left (false: right edges aligned).
  final bool alignStart;

  /// The corner the popover grows from.
  Alignment get origin => Alignment(alignStart ? -1 : 1, below ? -1 : 1);

  static const double gap = 6;
  static const double margin = 8;

  /// Places a [width]-wide popover next to [anchor] inside [area] (minus
  /// [padding], e.g. the status bar and the keyboard).
  static BhorPopoverPlacement of({
    required Rect anchor,
    required Size area,
    required EdgeInsets padding,
    required double width,
  }) {
    final double w = math.min(width, area.width - 2 * margin);
    final double roomBelow = area.height - padding.bottom - anchor.bottom - gap - margin;
    final double roomAbove = anchor.top - padding.top - gap - margin;
    final bool below = roomBelow >= 360 || roomBelow >= roomAbove;
    final double maxH = math.max(120.0, below ? roomBelow : roomAbove);
    final bool alignStart = anchor.left + w <= area.width - margin;
    final double left = (alignStart ? anchor.left : anchor.right - w).clamp(margin, math.max(margin, area.width - w - margin));
    final double top = below ? anchor.bottom + gap : anchor.top - gap - maxH;
    return BhorPopoverPlacement(rect: Rect.fromLTWH(left, top, w, maxH), below: below, alignStart: alignStart);
  }
}

/// The popover page: an anchored floating card (also usable inline with a
/// completed [animation], e.g. in the gallery and tests).
class BhorPopoverFrame extends StatelessWidget {
  const BhorPopoverFrame({
    super.key,
    required this.anchor,
    required this.child,
    this.animation = kAlwaysCompleteAnimation,
    this.title,
    this.closeLabel,
    this.footer,
    this.width = 320,
    this.scroll = true,
    this.padding = const EdgeInsets.fromLTRB(BhorSpace.s4, 0, BhorSpace.s4, BhorSpace.s4),
    this.reduced = false,
  });

  /// The control it hangs from, in this page's coordinates.
  final Rect anchor;
  final Widget child;
  final Animation<double> animation;
  final String? title;

  /// Accessible name of ✕; null hides it (and Esc close).
  final String? closeLabel;
  final Widget? footer;
  final double width;
  final bool scroll;
  final EdgeInsets padding;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final MediaQueryData mq = MediaQuery.of(context);
    void close() {
      if (closeLabel != null) Navigator.of(context).maybePop();
    }

    final Widget body = DefaultTextStyle(
      style: b.type.body,
      child: scroll ? SingleChildScrollView(padding: padding, child: child) : Padding(padding: padding, child: child),
    );
    final bool hasHeader = title != null && title!.isNotEmpty;
    final Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(BhorRadius.card),
        border: Border.all(color: c.line),
        boxShadow: c.floatShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BhorRadius.card),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (hasHeader)
                Padding(
                  padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s8, BhorSpace.s8, BhorSpace.s4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: b.type.heading),
                        ),
                      ),
                      if (closeLabel != null)
                        BhorIconButton(
                          icon: BhorIcons.close,
                          semanticLabel: closeLabel!,
                          size: BhorButtonSize.sm,
                          circle: true,
                          onPressed: close,
                        ),
                    ],
                  ),
                )
              else
                const SizedBox(height: BhorSpace.s4),
              Flexible(child: body),
              if (footer != null)
                DecoratedBox(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(BhorSpace.s12, BhorSpace.s8, BhorSpace.s12, BhorSpace.s12),
                    child: footer,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Actions(
      actions: <Type, Action<Intent>>{
        DismissIntent: CallbackAction<DismissIntent>(onInvoke: (DismissIntent _) {
          close();
          return null;
        }),
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{const SingleActivator(LogicalKeyboardKey.escape): close},
        child: FocusScope(
          autofocus: true,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final BhorPopoverPlacement p = BhorPopoverPlacement.of(
                anchor: anchor,
                area: box.biggest,
                padding: mq.padding + EdgeInsets.only(bottom: mq.viewInsets.bottom),
                width: width,
              );
              final Animation<double> a =
                  CurvedAnimation(parent: animation, curve: BhorMotion.ease, reverseCurve: BhorMotion.exitCurve);
              final Widget sized = ConstrainedBox(
                constraints: BoxConstraints(minWidth: p.rect.width, maxWidth: p.rect.width, maxHeight: p.rect.height),
                child: card,
              );
              final Widget moving = FadeTransition(
                opacity: a,
                child: reduced
                    ? sized
                    : AnimatedBuilder(
                        animation: a,
                        builder: (BuildContext context, Widget? child) => Transform.translate(
                          offset: Offset(0, (p.below ? -4 : 4) * (1 - a.value)),
                          child: Transform.scale(scale: 0.96 + 0.04 * a.value, alignment: p.origin, child: child),
                        ),
                        child: sized,
                      ),
              );
              return Stack(
                children: <Widget>[
                  Positioned(
                    key: const ValueKey<String>('bhor-popover'),
                    left: p.rect.left,
                    width: p.rect.width,
                    top: p.below ? p.rect.top : null,
                    bottom: p.below ? null : box.biggest.height - anchor.top + BhorPopoverPlacement.gap,
                    child: moving,
                  ),
                ],
              );
            },
          ),
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

/// Marks chrome pinned to the bottom of the window that toasts must never
/// cover: the phone nav pill, a [BhorActionBar], a sheet or panel footer.
/// While it is on screen (not in an offstage route or tab), bottom toasts
/// sit above it, whatever context showed them.
/// Usage: `BhorBottomObstruction(child: saveBar)`.
class BhorBottomObstruction extends StatefulWidget {
  const BhorBottomObstruction({super.key, required this.child});

  final Widget child;

  /// Bumps whenever an obstruction appears, moves or goes away.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static final Set<_BhorBottomObstructionState> _all = <_BhorBottomObstructionState>{};

  /// Height from the window bottom that the visible obstructions under the
  /// horizontal band [left]..[right] cover (0 when none). Only chrome in the
  /// lower 40% of a window [height] tall counts. Reads render boxes: call it
  /// from event handlers or post-frame callbacks, never during build.
  static double coveredHeight({required double height, required double left, required double right}) {
    double top = height;
    for (final _BhorBottomObstructionState s in _all) {
      final Rect? r = s.rect;
      if (r == null || r.bottom < height * 0.6 || r.right <= left || r.left >= right) continue;
      if (r.top < top) top = r.top;
    }
    return math.max(0.0, height - top);
  }

  @override
  State<BhorBottomObstruction> createState() => _BhorBottomObstructionState();
}

class _BhorBottomObstructionState extends State<BhorBottomObstruction> {
  bool _active = false;

  /// Global rect while on screen (live; outside build only).
  Rect? get rect {
    if (!_active || !mounted) return null;
    final RenderObject? ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  @override
  void initState() {
    super.initState();
    BhorBottomObstruction._all.add(this);
  }

  @override
  void dispose() {
    BhorBottomObstruction._all.remove(this);
    _bump();
    super.dispose();
  }

  static void _bump() {
    WidgetsBinding.instance.addPostFrameCallback((_) => BhorBottomObstruction.revision.value++);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild (and re-measure) when the tab / route is hidden or the window
    // or keyboard changes.
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    _active = TickerMode.of(context) && (route == null || route.isActive);
    MediaQuery.sizeOf(context);
    MediaQuery.viewInsetsOf(context);
    // Toasts re-measure after this frame.
    _bump();
    return widget.child;
  }
}

/// Short message as a floating pill (surface, line edge, soft shadow),
/// a leading status icon + text + pill actions, top or bottom,
/// auto-dismissed after [duration] (null keeps it until an action is
/// tapped). Enters with the spring (y +14, scale .96 -> 1). A new toast
/// replaces the old one: the old one leaves first, then the new one comes
/// in. Bottom toasts always sit above the phone nav pill, pinned save bars
/// and sheet footers ([BhorBottomObstruction]); a phone FAB moves up out of
/// their way ([BhorToast.occupied]). Shown in the root Overlay (else the
/// app's [BhorToastHost]).
/// Usage: `BhorToast.show(context, message: 'সংরক্ষিত', actionLabel: 'ফেরান', onAction: undo)`
/// or `actions: [BhorToastAction(label: 'রসিদ পাঠান', onPressed: send), BhorToastAction(...)]`.
abstract final class BhorToast {
  static _ToastViewState? _current;

  /// Height (plus a gap) that the visible bottom toast takes above the
  /// chrome; 0 when none. Floating buttons lift by this much.
  static final ValueNotifier<double> occupied = ValueNotifier<double>(0);

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

  /// The leading icon a toast of [tone] gets when none is given.
  static IconData defaultIcon(BhorTone tone) => switch (tone) {
        BhorTone.ok => BhorIcons.checkCircleFill,
        BhorTone.danger || BhorTone.overdue || BhorTone.warn => BhorIcons.warningFill,
        _ => BhorIcons.infoFill,
      };

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
    final bool replacing = _current != null;
    _current?.dismiss();
    final double chrome = top ? 0 : _ToastViewState.chromeFor(context);
    final GlobalKey<_ToastViewState> key = GlobalKey<_ToastViewState>();
    VoidCallback remove = () {};
    Widget build(BuildContext ctx) => BhorTheme(
          data: theme,
          child: _ToastView(
            key: key,
            message: message,
            actions: all,
            tone: tone,
            icon: icon ?? defaultIcon(tone),
            duration: duration,
            top: top,
            bottomOffset: lift,
            reduced: reduced,
            delayed: replacing && !reduced,
            chrome: chrome,
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
    required this.delayed,
    required this.chrome,
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

  /// Replacing another toast: wait for it to leave first.
  final bool delayed;

  /// Bottom chrome height when shown (re-measured after every frame that
  /// moves an obstruction).
  final double chrome;
  final VoidCallback onGone;

  /// How long the leaving toast takes (the new one waits this long).
  static const Duration exit = Duration(milliseconds: 140);

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.reduced ? BhorMotion.reducedFade : BhorMotion.slow,
    reverseDuration: widget.reduced ? BhorMotion.reducedFade : _ToastView.exit,
  );
  final GlobalKey _cardKey = GlobalKey(debugLabel: 'bhor-toast-card');
  Timer? _timer;
  Timer? _start;
  bool _closing = false;
  late double _chrome = widget.chrome;

  /// Visible bottom chrome under a toast shown from [context] (outside
  /// build only).
  static double chromeFor(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double band = math.min(480.0, size.width - 2 * BhorSpace.s16);
    return BhorBottomObstruction.coveredHeight(
      height: size.height,
      left: (size.width - band) / 2,
      right: (size.width + band) / 2,
    );
  }

  @override
  void initState() {
    super.initState();
    BhorToast._current = this;
    if (widget.delayed) {
      _start = Timer(_ToastView.exit, () {
        if (mounted && !_closing) _c.forward();
      });
    } else {
      _c.forward();
    }
    final Duration? d = widget.duration;
    if (d != null) _timer = Timer(d + (widget.delayed ? _ToastView.exit : Duration.zero), dismiss);
    BhorBottomObstruction.revision.addListener(_reflow);
    if (!widget.top) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reflow();
        _publishHeight();
      });
    }
  }

  /// Re-measures the chrome (called from post-frame callbacks).
  void _reflow() {
    if (!mounted || widget.top) return;
    final double now = chromeFor(context);
    if ((now - _chrome).abs() > 0.5) setState(() => _chrome = now);
  }

  void _publishHeight() {
    if (!mounted || _closing || BhorToast._current != this) return;
    final RenderObject? ro = _cardKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) BhorToast.occupied.value = ro.size.height + BhorSpace.s8;
  }

  void _clearHeight() {
    if (BhorToast._current == this || BhorToast._current == null) BhorToast.occupied.value = 0;
  }

  void dismiss() {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    _start?.cancel();
    if (BhorToast._current == this) BhorToast._current = null;
    _clearHeight();
    _c.reverse().whenCompleteOrCancel(widget.onGone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _start?.cancel();
    BhorBottomObstruction.revision.removeListener(_reflow);
    if (BhorToast._current == this) {
      BhorToast._current = null;
      BhorToast.occupied.value = 0;
    }
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
      key: _cardKey,
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
    // Clear of the keyboard / gesture bar, the shell's inset, and any
    // visible bottom chrome under the toast's band.
    final double bottom = math.max(
      mq.viewPadding.bottom + mq.viewInsets.bottom + BhorSpace.s12 + widget.bottomOffset,
      _chrome + BhorSpace.s12,
    );
    return Positioned(
      left: BhorSpace.s16,
      right: BhorSpace.s16,
      top: widget.top ? mq.viewPadding.top + BhorSpace.s16 : null,
      bottom: widget.top ? null : bottom,
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
