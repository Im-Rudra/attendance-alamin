// One-time coach mark on Today: "tap today's class to start the roll call".
//
// It is an overlay on the root navigator, shown once right after onboarding
// (remembered in local_meta, so never twice). Today may wrap its roll-call
// button in [CoachMarkAnchor]; the bubble then points at that button, with a
// ring around it. Without an anchor the bubble sits above the bottom bar.

import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';

/// `local_meta` key set once the roll-call coach mark was shown.
const String kRollCallCoachMetaKey = 'coach:rollcall';

final ValueNotifier<GlobalKey?> _anchor = ValueNotifier<GlobalKey?>(null);

/// Wrap the roll-call button (or the class card that starts it) so the coach
/// mark can point at it. Harmless when no coach mark is showing.
class CoachMarkAnchor extends StatefulWidget {
  const CoachMarkAnchor({super.key, required this.child});

  final Widget child;

  @override
  State<CoachMarkAnchor> createState() => _CoachMarkAnchorState();
}

class _CoachMarkAnchorState extends State<CoachMarkAnchor> {
  final GlobalKey _key = GlobalKey(debugLabel: 'coach-anchor');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _anchor.value = _key;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_anchor.value == _key) _anchor.value = null;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}

/// Shows the coach mark above whatever route is current, unless it was shown
/// before. Call it right before navigating to Today. Returns true when shown.
Future<bool> showRollCallCoach(BuildContext context) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final meta = container.read(localMetaRepositoryProvider);
  if (await meta.getRaw(kRollCallCoachMetaKey) != null) return false;
  if (!context.mounted) return false;
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return false;
  await meta.setRaw(kRollCallCoachMetaKey, '1');
  late final OverlayEntry entry;
  final BhorThemeData theme = context.bhor;
  entry = OverlayEntry(
    builder: (BuildContext ctx) => BhorTheme(
      data: theme,
      child: _CoachOverlay(onDismiss: () => entry.remove()),
    ),
  );
  overlay.insert(entry);
  return true;
}

class _CoachOverlay extends StatelessWidget {
  const _CoachOverlay({required this.onDismiss});

  final VoidCallback onDismiss;

  Rect? _rectOf(GlobalKey? key) {
    final BuildContext? ctx = key?.currentContext;
    final RenderObject? ro = ctx?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    final Size screen = MediaQuery.sizeOf(context);

    return ValueListenableBuilder<GlobalKey?>(
      valueListenable: _anchor,
      builder: (BuildContext context, GlobalKey? key, Widget? _) {
        final Rect? target = _rectOf(key);
        final double bubbleWidth = screen.width < 400 ? screen.width - 32 : 360;

        final Widget bubble = DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(BhorRadius.control),
            border: Border.all(color: c.accent, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(color: c.scrim, blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(target == null ? Icons.touch_app_outlined : Icons.arrow_downward, color: c.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(l10n.onbCoachText, style: b.type.heading),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: BhorButton(
                    key: const Key('onb-coach-ok'),
                    label: l10n.onbCoachGotIt,
                    variant: BhorButtonVariant.ghost,
                    onPressed: onDismiss,
                  ),
                ),
              ],
            ),
          ),
        );

        double left = (screen.width - bubbleWidth) / 2;
        double? top;
        double? bottom;
        if (target == null) {
          bottom = 104;
        } else {
          left = math.min(math.max(target.center.dx - bubbleWidth / 2, 16.0), math.max(screen.width - bubbleWidth - 16, 16.0));
          if (target.center.dy > screen.height / 2) {
            bottom = screen.height - target.top + 12;
          } else {
            top = target.bottom + 12;
          }
        }

        return Semantics(
          container: true,
          liveRegion: true,
          label: l10n.onbCoachSemantics,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                  child: ColoredBox(color: c.scrim),
                ),
              ),
              if (target != null)
                Positioned.fromRect(
                  rect: target.inflate(6),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(BhorRadius.control),
                        border: Border.all(color: c.accent, width: 3),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: left,
                top: top,
                bottom: bottom,
                width: bubbleWidth,
                child: bubble,
              ),
            ],
          ),
        );
      },
    );
  }
}
