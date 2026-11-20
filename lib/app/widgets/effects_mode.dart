// Reduced-effects switch (UX 4, performance rule 5).
//
// Reduced mode removes every BackdropFilter and the grain overlay; the static
// mesh stays. It is on when the app set it explicitly (Settings toggle, low-RAM
// device, slow web raster) or when the OS asks for reduced motion / high
// contrast. Layout is identical in both modes.

import 'package:flutter/widgets.dart';

class EffectsMode extends InheritedWidget {
  const EffectsMode({super.key, required this.reduced, required super.child});

  /// Explicit app-level choice. The OS flags are applied on top of it.
  final bool reduced;

  /// True when effects must be reduced for [context].
  static bool reducedOf(BuildContext context) {
    final EffectsMode? mode = context.dependOnInheritedWidgetOfExactType<EffectsMode>();
    if (mode != null && mode.reduced) return true;
    final MediaQueryData? mq = MediaQuery.maybeOf(context);
    if (mq == null) return false;
    return mq.disableAnimations || mq.highContrast;
  }

  @override
  bool updateShouldNotify(EffectsMode oldWidget) => reduced != oldWidget.reduced;
}
