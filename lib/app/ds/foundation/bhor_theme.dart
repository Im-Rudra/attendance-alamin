// BhorTheme: the InheritedWidget that carries the Bhor tokens, and the
// `context.bhor` accessor every component reads.
//
// Usage: `BhorTheme(data: BhorThemeData.dark(), child: ...)`, then
// `final b = context.bhor; b.colors.accent; b.type.title;`.
// Without a BhorTheme ancestor, the platform brightness picks light or dark.

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';

/// Everything a component needs to paint itself.
class BhorThemeData {
  BhorThemeData._(this.colors) : type = BhorType(colors.text, colors.text2);

  factory BhorThemeData.light() => _light;
  factory BhorThemeData.dark() => _dark;

  /// Light or dark by [brightness].
  factory BhorThemeData.of(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  static final BhorThemeData _light = BhorThemeData._(BhorColors.light);
  static final BhorThemeData _dark = BhorThemeData._(BhorColors.dark);

  final BhorColors colors;
  final BhorType type;

  Brightness get brightness => colors.brightness;
  bool get isDark => colors.isDark;
}

/// Provides [data] to the subtree.
class BhorTheme extends InheritedWidget {
  const BhorTheme({super.key, required this.data, required super.child});

  final BhorThemeData data;

  /// The nearest theme, or the platform-brightness default.
  static BhorThemeData of(BuildContext context) {
    final BhorTheme? t = context.dependOnInheritedWidgetOfExactType<BhorTheme>();
    if (t != null) return t.data;
    final Brightness b = MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    return BhorThemeData.of(b);
  }

  @override
  bool updateShouldNotify(BhorTheme oldWidget) => oldWidget.data != data;
}

extension BhorContextX on BuildContext {
  /// The Bhor tokens for this subtree.
  BhorThemeData get bhor => BhorTheme.of(this);

  /// True on wide (desktop) windows: hover states and compact toolbars apply.
  bool get bhorIsWide => (MediaQuery.maybeSizeOf(this)?.width ?? 0) >= 840;
}
