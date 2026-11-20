// Desktop keys of the students screens (UX 3b): Ctrl+N new student, Ctrl+P
// collect for the selected student, F2 edit, Esc clears the selection. Same
// mechanism as the shell's window shortcuts (a HardwareKeyboard handler), and
// only active while the screen's route is on top.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class StudentKeys extends StatefulWidget {
  const StudentKeys({
    super.key,
    required this.child,
    this.onNew,
    this.onCollect,
    this.onEdit,
    this.onEscape,
  });

  final Widget child;
  final VoidCallback? onNew;
  final VoidCallback? onCollect;
  final VoidCallback? onEdit;
  final VoidCallback? onEscape;

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
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final HardwareKeyboard kb = HardwareKeyboard.instance;
    final LogicalKeyboardKey key = event.logicalKey;
    if (kb.isControlPressed && !kb.isAltPressed) {
      if (key == LogicalKeyboardKey.keyN && widget.onNew != null) {
        widget.onNew!();
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
