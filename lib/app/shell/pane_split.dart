// PaneLayout whose list width is remembered per screen in local preferences
// (`local_meta` key `pane:<screen>`, UX 3b rule 6). Use it for every
// list ‖ detail (‖ context) screen on wide windows.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';

class PaneSplit extends ConsumerStatefulWidget {
  const PaneSplit({
    super.key,
    required this.screen,
    required this.list,
    required this.detail,
    this.contextPane,
    this.preferList = false,
    this.listMax = 440,
    this.detailMax = 720,
  });

  /// Stable screen id, e.g. `batches` (part of the stored key).
  final String screen;
  final Widget list;
  final Widget detail;
  final Widget? contextPane;

  /// When the window is too narrow for two panes (e.g. 840–880 with the
  /// rail), show the list instead of the detail (nothing selected yet).
  final bool preferList;

  /// Widest the list pane may grow (default 440). A data table can raise it so
  /// it takes the space left beside a narrower [detailMax] detail pane.
  final double listMax;

  /// Widest the detail pane may grow before extra space goes elsewhere.
  final double detailMax;

  @override
  ConsumerState<PaneSplit> createState() => _PaneSplitState();
}

class _PaneSplitState extends ConsumerState<PaneSplit> {
  late final LocalMetaRepository _meta = ref.read(localMetaRepositoryProvider);
  double? _width;
  bool _touched = false;
  Timer? _saveTimer;

  String get _key => LocalMetaKeys.pane(widget.screen);

  @override
  void initState() {
    super.initState();
    _meta.getRaw(_key).then((String? raw) {
      if (!mounted || _touched || raw == null) return;
      final double? w = double.tryParse(raw);
      if (w != null && w.isFinite) setState(() => _width = w);
    }, onError: (Object _) {});
  }

  void _changed(double w) {
    _touched = true;
    setState(() => _width = w);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  void _save() {
    final double? w = _width;
    if (w == null) return;
    _meta.setRaw(_key, w.toStringAsFixed(1)).catchError((Object _) {});
  }

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _save();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? ctx = widget.contextPane;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final PaneWidths w = PaneLayout.compute(
          width: c.maxWidth,
          hasContext: ctx != null,
          listWidth: _width,
          listMax: widget.listMax,
          detailMax: widget.detailMax,
        );
        // Too narrow for two panes: one full screen, with its own back arrow.
        if (w.list == 0) return widget.preferList ? widget.list : widget.detail;
        return PaneLayout(
          list: PaneScope(child: widget.list),
          detail: PaneScope(child: widget.detail),
          contextPane: ctx == null ? null : PaneScope(child: ctx),
          listWidth: _width,
          onListWidthChanged: _changed,
          listMax: widget.listMax,
          detailMax: widget.detailMax,
        );
      },
    );
  }
}

/// Marks a subtree as one pane of a [PaneSplit]: screens inside it hide their
/// own back arrow (the window, not the pane, owns navigation).
class PaneScope extends InheritedWidget {
  const PaneScope({super.key, required super.child});

  static bool isEmbedded(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaneScope>() != null;

  @override
  bool updateShouldNotify(PaneScope oldWidget) => false;
}
