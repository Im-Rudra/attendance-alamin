// App-wide text size (Appearance setting, Ctrl + = / Ctrl + - / Ctrl + 0):
// four levels stored on this device; the factor multiplies the OS text scale
// and the product is clamped so layouts keep room.

import 'package:flutter/widgets.dart';

enum TextSizeLevel {
  small('small', 0.9),
  normal('normal', 1.0),
  large('large', 1.15),
  xlarge('xlarge', 1.3);

  const TextSizeLevel(this.code, this.factor);

  /// Value stored in `SettingKeys.textSize`.
  final String code;
  final double factor;

  static TextSizeLevel fromCode(String code) => TextSizeLevel.values
      .firstWhere((TextSizeLevel l) => l.code == code, orElse: () => TextSizeLevel.normal);

  /// The next bigger (+1) / smaller (-1) level; stays put at the ends.
  TextSizeLevel step(int delta) {
    final int i = (index + delta).clamp(0, TextSizeLevel.values.length - 1);
    return TextSizeLevel.values[i];
  }
}

/// Highest total text scale (OS scale x chosen factor).
const double kMaxTextScale = 1.5;

/// The effective scale: OS scale x [level] factor, never above [kMaxTextScale]
/// (an OS scale that is already above it is left as it is).
double effectiveTextScale(double osScale, TextSizeLevel level) {
  final double raw = osScale * level.factor;
  if (raw <= kMaxTextScale) return raw;
  return osScale > kMaxTextScale ? osScale : kMaxTextScale;
}

/// Applies the chosen text size below the app's MediaQuery.
class AppTextScale extends StatelessWidget {
  const AppTextScale({super.key, required this.level, required this.child});

  final TextSizeLevel level;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double os = mq.textScaler.scale(100) / 100;
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(effectiveTextScale(os, level))),
      child: child,
    );
  }
}
