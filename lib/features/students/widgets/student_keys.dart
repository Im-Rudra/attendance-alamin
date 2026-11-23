// Desktop keys of the students screens (UX 3b): Ctrl+N new student, Ctrl+P
// collect for the selected student, F2 edit, Ctrl+A selects every listed
// student, Esc clears the selection. Same
// mechanism as the shell's window shortcuts (a HardwareKeyboard handler), and
// only active while the screen's route is on top.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class StudentKeys extends StatefulWidget {
  const StudentKeys({
    super.key,
    required this.child,
    this.onNew,
    this.onCollect,
    this.onEdit,
    this.onEscape,
    this.onSelectAll,
    this.selectAllWhileTyping,
  });

  final Widget child;
  final VoidCallback? onNew;
  final VoidCallback? onCollect;
  final VoidCallback? onEdit;
  final VoidCallback? onEscape;

  /// Ctrl+A (item 10): select every listed student. Not while typing, unless
  /// [selectAllWhileTyping] says so (the list's empty search box).
  final VoidCallback? onSelectAll;
  final bool Function()? selectAllWhileTyping;

  @override
  State<StudentKeys> createState() => _StudentKeysState();
}

class _StudentKeysState extends State<StudentKeys> {
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
      if (key == LogicalKeyboardKey.keyN && widget.onNew != null) {
        widget.onNew!();
        return true;
      }
      if (key == LogicalKeyboardKey.keyA &&
          widget.onSelectAll != null &&
          (!_typing() || (widget.selectAllWhileTyping?.call() ?? false))) {
        widget.onSelectAll!();
        return true;
      }
      if (key == LogicalKeyboardKey.keyP && widget.onCollect != null) {
        widget.onCollect!();
        return true;
      }
      return false;
    }
    if (key == LogicalKeyboardKey.f2 && widget.onEdit != null) {
      widget.onEdit!();
      return true;
    }
    if (key == LogicalKeyboardKey.escape &&
        widget.onEscape != null &&
        !_typing()) {
      widget.onEscape!();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
