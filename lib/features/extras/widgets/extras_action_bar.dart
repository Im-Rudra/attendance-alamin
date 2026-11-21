// The big action button pinned under a full-screen form of the extras feature:
// an optional live summary above it, the reason it is disabled below it.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';

class ExtrasActionBar extends StatelessWidget {
  const ExtrasActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.disabledReason,
    this.summary,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Key of the [BhorButton] itself (tests and automation tap it).
  final Key? buttonKey;
  final String? disabledReason;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: b.colors.surface,
        border: Border(top: BorderSide(color: b.colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(BhorSpace.s16, BhorSpace.s12, BhorSpace.s16, BhorSpace.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (summary != null) ...<Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(summary!, textAlign: TextAlign.center, style: b.type.meta),
                ),
                const SizedBox(height: BhorSpace.s8),
              ],
              BhorButton(key: buttonKey, label: label, onPressed: onPressed, expand: true),
              if (onPressed == null && disabledReason != null) ...<Widget>[
                const SizedBox(height: BhorSpace.s8),
                Text(disabledReason!, textAlign: TextAlign.center, style: b.type.meta),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
