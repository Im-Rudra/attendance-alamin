// BhorFocusPage (docs/council/16-windows-rebuild-plan.md W1-B 5): one focused
// task (roll call) INSIDE the shell, so the sidebar stays (review R1). A slim
// top bar (back, title, subtitle, actions), the content at most 880 wide and
// centred, and a sticky bottom bar (a live summary on the left, the primary
// action on the right) next to the work instead of in a far rail.
// Esc goes back like the back button: it pops through Navigator.maybePop,
// so a PopScope / unsaved-changes guard on the page still asks first, and it
// only acts while this page is the top-most route (never under a dialog,
// menu or panel).
// Usage:
//   BhorFocusPage(
//     title: 'হাজিরা · নবম গণিত',
//     subtitle: fmt.weekdayDate(date),
//     summary: Text('২৮ উপস্থিত · ২ অনুপস্থিত'),
//     primary: BhorButton(label: 'সংরক্ষণ', onPressed: save),
//     body: RollList(...),
//   )

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class BhorFocusPage extends StatefulWidget {
  const BhorFocusPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.titleWidget,
    this.actions = const <Widget>[],
    this.onBack,
    this.summary,
    this.primary,
    this.secondary,
    this.maxWidth = defaultMaxWidth,
    this.scrollable = true,
    this.escToBack = true,
  });

  /// Widest the content (and the bottom bar's content) gets.
  static const double defaultMaxWidth = 880;

  static const Key bodyKey = Key('bhor-focus-body');
  static const Key barKey = Key('bhor-focus-bar');

  final String title;
  final String? subtitle;

  /// Replaces the title block (e.g. a title with a date switcher).
  final Widget? titleWidget;
  final List<Widget> actions;

  /// Back / Esc; default `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Left of the bottom bar: live counts or status.
  final Widget? summary;

  /// Right of the bottom bar: the main action (BhorButton).
  final Widget? primary;

  /// Before [primary] in the bottom bar.
  final Widget? secondary;
  final double maxWidth;

  /// The content column scrolls (false: [body] scrolls itself).
  final bool scrollable;

  /// Esc goes back (off in previews such as the gallery).
  final bool escToBack;
  final Widget body;

  /// True when [context]'s route is the top-most one on every navigator up
  /// to the root (no dialog, menu, sheet or panel above it).
  static bool isTopMost(BuildContext context) {
    BuildContext? ctx = context;
    for (int depth = 0; depth < 8 && ctx != null; depth++) {
      final ModalRoute<Object?>? route = ModalRoute.of(ctx);
      if (route == null) return true;
      if (!route.isCurrent) return false;
      final NavigatorState? nav = route.navigator;
      if (nav == null || !nav.mounted) return true;
      ctx = nav.context;
    }
    return true;
  }

  @override
  State<BhorFocusPage> createState() => _BhorFocusPageState();
}

class _BhorFocusPageState extends State<BhorFocusPage> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _back() {
    final VoidCallback? onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  bool _onKey(KeyEvent event) {
    if (!widget.escToBack || !mounted) return false;
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (!BhorFocusPage.isTopMost(context)) return false;
    _back();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final bool wide = context.bhorIsWide;
    final double gutter = wide ? BhorSpace.screenDesktop : BhorSpace.screenPhone;
    Widget centred(Widget child) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: widget.maxWidth), child: child),
        );
    final Widget body = KeyedSubtree(
      key: BhorFocusPage.bodyKey,
      child: widget.scrollable
          ? SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(gutter, BhorSpace.s16, gutter, BhorSpace.s24),
              child: centred(widget.body),
            )
          : Padding(
              padding: EdgeInsets.fromLTRB(gutter, BhorSpace.s16, gutter, 0),
              child: centred(widget.body),
            ),
    );
    final bool hasBar = widget.summary != null || widget.primary != null || widget.secondary != null;
    final Widget? bar = !hasBar
        ? null
        : BhorBottomObstruction(
            child: DecoratedBox(
              key: BhorFocusPage.barKey,
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter, vertical: BhorSpace.s12),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: widget.maxWidth),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: DefaultTextStyle.merge(
                              style: b.type.label.copyWith(color: c.text2),
                              child: Semantics(liveRegion: true, child: widget.summary ?? const SizedBox.shrink()),
                            ),
                          ),
                          if (widget.secondary != null) ...<Widget>[
                            const SizedBox(width: BhorSpace.s12),
                            widget.secondary!,
                          ],
                          if (widget.primary != null) ...<Widget>[
                            const SizedBox(width: BhorSpace.s12),
                            widget.primary!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
    return BhorScaffold(
      wash: false,
      header: BhorHeader(
        title: widget.title,
        titleWidget: widget.titleWidget,
        subtitle: widget.subtitle,
        actions: widget.actions,
        showBack: true,
        onBack: _back,
        divider: true,
      ),
      body: body,
      bottomNav: bar,
    );
  }
}
