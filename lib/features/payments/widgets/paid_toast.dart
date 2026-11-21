// The "৳৮০০ জমা হয়েছে" toast with TWO actions (রসিদ পাঠান + undo). BhorToast
// carries a single action, so this composes the same look locally (message,
// accent edge, ghost actions, bottom, auto-dismiss) until the library offers
// a second action. Replaced by any newer paid toast; BhorToast stays for every
// other message.

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

/// One action button of the toast.
class PaidToastAction {
  const PaidToastAction({required this.key, required this.label, required this.onPressed});

  final Key key;
  final String label;
  final VoidCallback onPressed;
}

_PaidToastState? _current;

/// Shows the toast on the root overlay for [duration].
void showPaidToast(
  BuildContext context, {
  required String message,
  required List<PaidToastAction> actions,
  Duration duration = const Duration(seconds: 8),
  double bottomOffset = 0,
}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final BhorThemeData theme = context.bhor;
  _current?.dismiss();
  late final OverlayEntry entry;
  final GlobalKey<_PaidToastState> key = GlobalKey<_PaidToastState>();
  entry = OverlayEntry(
    builder: (BuildContext ctx) => BhorTheme(
      data: theme,
      child: _PaidToast(
        key: key,
        message: message,
        actions: actions,
        duration: duration,
        bottomOffset: bottomOffset,
        onGone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    ),
  );
  overlay.insert(entry);
}

class _PaidToast extends StatefulWidget {
  const _PaidToast({
    super.key,
    required this.message,
    required this.actions,
    required this.duration,
    required this.bottomOffset,
    required this.onGone,
  });

  final String message;
  final List<PaidToastAction> actions;
  final Duration duration;
  final double bottomOffset;
  final VoidCallback onGone;

  @override
  State<_PaidToast> createState() => _PaidToastState();
}

class _PaidToastState extends State<_PaidToast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BhorMotion.slow);
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _current = this;
    _c.forward();
    _timer = Timer(widget.duration, dismiss);
  }

  void dismiss() {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    if (_current == this) _current = null;
    _c.reverse().whenCompleteOrCancel(widget.onGone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_current == this) _current = null;
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final MediaQueryData mq = MediaQuery.of(context);
    final Widget card = Container(
      constraints: const BoxConstraints(maxWidth: 480, minHeight: BhorSize.control + 8),
      padding: const EdgeInsets.fromLTRB(BhorSpace.s12, 6, 6, 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(BhorRadius.control),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 24,
            margin: const EdgeInsets.only(right: BhorSpace.s12),
            decoration: BoxDecoration(color: c.ok, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(widget.message, style: b.type.body),
            ),
          ),
          for (final PaidToastAction a in widget.actions)
            BhorButton(
              key: a.key,
              label: a.label,
              variant: BhorButtonVariant.ghost,
              size: BhorButtonSize.sm,
              onPressed: () {
                dismiss();
                a.onPressed();
              },
            ),
        ],
      ),
    );
    final Animation<double> a = CurvedAnimation(parent: _c, curve: BhorMotion.curve);
    return Positioned(
      left: BhorSpace.s16,
      right: BhorSpace.s16,
      bottom: mq.viewPadding.bottom + mq.viewInsets.bottom + BhorSpace.s16 + widget.bottomOffset,
      child: FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
          child: Semantics(liveRegion: true, container: true, child: Center(child: card)),
        ),
      ),
    );
  }
}
