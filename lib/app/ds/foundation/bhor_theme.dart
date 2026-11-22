// BhorTheme: the InheritedWidget that carries the Bhor tokens, and the
// `context.bhor` accessor every component reads.
//
// Usage: `BhorTheme(data: BhorThemeData.dark(), child: ...)`, then
// `final b = context.bhor; b.colors.accent; b.type.title;`.
// Without a BhorTheme ancestor, the platform brightness picks light or dark.
// Windows >= 1200 wide use the desktop type step (BhorType.desktop).

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/foundation/bhor_tokens.dart';

/// Everything a component needs to paint itself.
class BhorThemeData {
  BhorThemeData._(this.colors, {this.desktop = false})
      : type = BhorType(colors.text, colors.text2, desktop: desktop);

  factory BhorThemeData.light() => _light;
  factory BhorThemeData.dark() => _dark;

  /// Light or dark by [brightness]; [desktop] picks the desktop type step
  /// (windows >= [BhorType.desktopMinWidth]).
  factory BhorThemeData.of(Brightness brightness, {bool desktop = false}) => brightness == Brightness.dark
      ? (desktop ? _darkDesktop : _dark)
      : (desktop ? _lightDesktop : _light);

  /// The theme for a window [width] logical px wide: the desktop type step
  /// from [BhorType.desktopMinWidth] up, the phone scale below.
  factory BhorThemeData.forWidth(Brightness brightness, double width) =>
      BhorThemeData.of(brightness, desktop: width >= BhorType.desktopMinWidth);

  static final BhorThemeData _light = BhorThemeData._(BhorColors.light);
  static final BhorThemeData _dark = BhorThemeData._(BhorColors.dark);
  static final BhorThemeData _lightDesktop = BhorThemeData._(BhorColors.light, desktop: true);
  static final BhorThemeData _darkDesktop = BhorThemeData._(BhorColors.dark, desktop: true);

  final BhorColors colors;
  final BhorType type;

  /// True for the desktop type step.
  final bool desktop;

  Brightness get brightness => colors.brightness;
  bool get isDark => colors.isDark;
}

/// Provides [data] to the subtree.
class BhorTheme extends InheritedWidget {
  const BhorTheme({super.key, required this.data, required super.child});

  final BhorThemeData data;

  /// The nearest theme, or the platform-brightness default (with the
  /// desktop type step on windows >= 1200 wide).
  static BhorThemeData of(BuildContext context) {
    final BhorTheme? t = context.dependOnInheritedWidgetOfExactType<BhorTheme>();
    if (t != null) return t.data;
    final Brightness b = MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    return BhorThemeData.forWidth(b, MediaQuery.maybeSizeOf(context)?.width ?? 0);
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
