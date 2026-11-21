// A pinned footer for forms hosted in showBhorPanel: the panel's footer slot is
// built outside the form's State, so the form publishes its save bar here after
// each build and the panel renders whatever it last published.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class PanelFooterSlot extends ValueNotifier<Widget?> {
  PanelFooterSlot() : super(null);

  /// Footer builder for `showBhorPanel(footer: slot.build)`.
  Widget build(BuildContext context) => ValueListenableBuilder<Widget?>(
        valueListenable: this,
        builder: (BuildContext c, Widget? w, Widget? _) => w ?? const SizedBox.shrink(),
      );

  /// Publishes [footer] after the current frame (never during build).
  void publish(Widget footer, {required bool Function() alive}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (alive()) value = footer;
    });
  }
}
