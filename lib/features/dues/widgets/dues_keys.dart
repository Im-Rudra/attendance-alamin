// Desktop keys of the Fees screen (UX 3b): Ctrl+P collect for the selected
// student, ↑ / ↓ move the selection, Esc clears it. Same mechanism as the
// students screen: a HardwareKeyboard handler that only acts while this
// screen's route is on top.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class DuesKeys extends StatefulWidget {
  const DuesKeys({
    super.key,
    required this.child,
    this.onCollect,
    this.onMove,
    this.onEscape,
  });

  final Widget child;
  final VoidCallback? onCollect;

  /// -1 = previous student, 1 = next student.
  final ValueChanged<int>? onMove;
  final VoidCallback? onEscape;

  @override
  State<DuesKeys> createState() => _DuesKeysState();
}

class _DuesKeysState extends State<DuesKeys> {
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

  bool _typing() {
    final BuildContext? ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    // Only while this page is the top-most layer: Esc on a menu, popover,
    // panel or dialog above it belongs to that layer (G2).
    if (bhorOverlayAbove(context)) return false;
    final HardwareKeyboard kb = HardwareKeyboard.instance;
    final LogicalKeyboardKey key = event.logicalKey;
    if (kb.isControlPressed && !kb.isAltPressed) {
      if (key == LogicalKeyboardKey.keyP && widget.onCollect != null) {
        widget.onCollect!();
        return true;
      }
      return false;
    }
    if (_typing()) return false;
    if (key == LogicalKeyboardKey.arrowDown && widget.onMove != null) {
      widget.onMove!(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp && widget.onMove != null) {
      widget.onMove!(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.escape && widget.onEscape != null) {
      widget.onEscape!();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
