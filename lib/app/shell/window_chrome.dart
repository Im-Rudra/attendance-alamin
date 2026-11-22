// Native window chrome that follows the app (docs/council/15-windows-ux-review.md
// G5, 16-windows-rebuild-plan.md W1-B 6).
//
// BhorWindowChrome tells the Windows runner whether the app is dark, so the
// title bar follows the app theme (light / dark / system) instead of the
// Windows theme. The runner side lives in windows/runner/flutter_window.cpp
// (written by tool/platform_patches/apply.py): MethodChannel `bhor/window`,
// method `setDark(bool)` -> DwmSetWindowAttribute(DWMWA_USE_IMMERSIVE_DARK_MODE).
// It is a no-op on every other platform (and on the web).
//
// BhorKeyboardFocusMode makes the keyboard focus ring a keyboard-only signal:
// any pointer press switches focus highlights off (touch mode), Tab or an
// arrow key switches them back on (traditional mode). A click therefore never
// leaves a ring behind on the control it pressed (review R3 / L1).

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The `bhor/window` channel of the Windows runner.
abstract final class BhorWindow {
  /// Channel name shared with windows/runner/flutter_window.cpp.
  static const String channelName = 'bhor/window';
  static const MethodChannel channel = MethodChannel(channelName);

  /// True where the runner implements the channel (Windows desktop only).
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Paints the native title bar dark ([dark]) or light. No-op elsewhere;
  /// never throws (an older runner without the channel is ignored).
  static Future<void> setDark(bool dark) async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('setDark', dark);
    } on MissingPluginException {
      // Runner without the patch: keep the Windows default.
    } on PlatformException {
      // Same: the title bar is cosmetic.
    }
  }
}

/// Keeps the native title bar in step with [brightness]: sends it once on
/// start and again whenever it changes. Wrap the app root with it.
class BhorWindowChrome extends StatefulWidget {
  const BhorWindowChrome({super.key, required this.brightness, required this.child});

  /// The app's effective brightness (theme mode resolved against the platform).
  final Brightness brightness;
  final Widget child;

  @override
  State<BhorWindowChrome> createState() => _BhorWindowChromeState();
}

class _BhorWindowChromeState extends State<BhorWindowChrome> {
  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void didUpdateWidget(BhorWindowChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness != widget.brightness) _send();
  }

  void _send() {
    if (!BhorWindow.supported) return;
    BhorWindow.setDark(widget.brightness == Brightness.dark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Focus rings only while the keyboard drives focus: a pointer press turns
/// focus highlights off, Tab / arrow keys turn them on again. Restores the
/// framework default when disposed.
class BhorKeyboardFocusMode extends StatefulWidget {
  const BhorKeyboardFocusMode({super.key, required this.child});

  final Widget child;

  /// Keys that start keyboard traversal (and so show the focus ring).
  static final Set<LogicalKeyboardKey> traversalKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  @override
  State<BhorKeyboardFocusMode> createState() => _BhorKeyboardFocusModeState();
}

class _BhorKeyboardFocusModeState extends State<BhorKeyboardFocusMode> {
  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    super.dispose();
  }

  void _set(FocusHighlightStrategy s) {
    if (FocusManager.instance.highlightStrategy != s) FocusManager.instance.highlightStrategy = s;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _set(FocusHighlightStrategy.alwaysTouch);
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent && BhorKeyboardFocusMode.traversalKeys.contains(event.logicalKey)) {
      _set(FocusHighlightStrategy.alwaysTraditional);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
