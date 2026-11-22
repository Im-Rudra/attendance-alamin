// Unsaved-changes guard (docs/council/16-windows-rebuild-plan.md W1-A, G3).
// - BhorGuard: put inside a panel / sheet / popover / dialog (showBhorPanel
//   and showBhorSheet do it for you with `dirty:`). While [dirty] is true,
//   closing it with Esc, ✕, a click on the dim, a drag or back asks
//   "Discard changes?" (Keep editing / Discard) instead of losing the input.
// - BhorDirtyScope: the same for a full page (back, a ✕ / back button that
//   calls Navigator.maybePop, and optionally Esc).
// Saving is never blocked: Navigator.pop(context, result) and
// showBhorSuccess pop straight through the guard; only maybePop (every
// "close" gesture) asks.

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/components/bhor_overlays.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';

/// Asks "Discard changes?" (Keep editing / Discard); true = discard.
/// Usage: `if (await showBhorDiscardConfirm(context)) Navigator.of(context).pop();`
Future<bool> showBhorDiscardConfirm(BuildContext context) {
  final l10n = context.l10n;
  return showBhorConfirm(
    context,
    title: l10n.commonDiscardTitle,
    message: l10n.commonDiscardMessage,
    confirmLabel: l10n.commonDiscardConfirm,
    cancelLabel: l10n.commonDiscardKeep,
    destructive: true,
  );
}

/// Blocks closing the route it sits in while [dirty] is true and asks
/// [showBhorDiscardConfirm] instead; on Discard the route pops (with no
/// result). Usage: `BhorGuard(dirty: form.dirty, child: form)`.
class BhorGuard extends StatefulWidget {
  const BhorGuard({super.key, required this.dirty, required this.child});

  /// True while there are unsaved changes.
  final ValueListenable<bool> dirty;
  final Widget child;

  @override
  State<BhorGuard> createState() => _BhorGuardState();
}

class _BhorGuardState extends State<BhorGuard> {
  bool _asking = false;

  Future<void> _ask() async {
    if (_asking) return;
    _asking = true;
    try {
      final bool discard = await showBhorDiscardConfirm(context);
      if (discard && mounted) {
        final ModalRoute<Object?>? route = ModalRoute.of(context);
        final NavigatorState nav = Navigator.of(context);
        // Pop exactly this route (the confirm dialog above it is gone).
        if (route != null && route.isCurrent) {
          nav.pop();
        } else if (route != null && route.isActive) {
          nav.removeRoute(route);
        }
      }
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: widget.dirty,
        builder: (BuildContext context, bool dirty, Widget? child) => PopScope<Object?>(
          canPop: !dirty,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) _ask();
          },
          child: child!,
        ),
        child: widget.child,
      );
}

/// [BhorGuard] for a full page: while [dirty] is true, leaving the page
/// with back (or a button that calls `Navigator.maybePop`) asks "Discard
/// changes?" first. [closeOnEscape] also makes Esc leave the page (through
/// the guard) while the page is the top-most layer and no text is being
/// typed.
/// Usage: `BhorDirtyScope(dirty: _dirty, closeOnEscape: true, child: page)`.
class BhorDirtyScope extends StatefulWidget {
  const BhorDirtyScope({super.key, required this.dirty, required this.child, this.closeOnEscape = false});

  final ValueListenable<bool> dirty;
  final Widget child;

  /// Esc = back (Navigator.maybePop) while this page is on top.
  final bool closeOnEscape;

  @override
  State<BhorDirtyScope> createState() => _BhorDirtyScopeState();
}

class _BhorDirtyScopeState extends State<BhorDirtyScope> {
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

  bool _onKey(KeyEvent event) {
    if (!widget.closeOnEscape || event is! KeyDownEvent || !mounted) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (bhorOverlayAbove(context)) return false;
    Navigator.of(context).maybePop();
    return true;
  }

  @override
  Widget build(BuildContext context) => BhorGuard(dirty: widget.dirty, child: widget.child);
}
