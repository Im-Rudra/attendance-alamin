// Payment-method configuration kept in the synced `payment_methods` setting
// (Product 3.12): which built-in methods are hidden and which custom labels
// the teacher added. Stored as JSON text:
//   {"hidden":["rocket"],"custom":["Upay"]}
// The default `[]` (and anything unreadable) means "all built-ins, no custom".
//
// Pure Dart: no Flutter, no providers. The payment form (M7-B) reads
// [PaymentMethodsConfig.visible].

import 'dart:convert';

import 'package:attendance_alamin/domain/models/enums.dart';

/// Outcome of checking a new custom method label.
enum CustomLabelCheck { ok, empty, tooLong, duplicate }

class PaymentMethodsConfig {
  const PaymentMethodsConfig({
    this.hidden = const <String>{},
    this.custom = const <String>[],
  });

  /// Codes of built-in methods that are hidden (e.g. `rocket`).
  final Set<String> hidden;

  /// Labels of custom methods, in the order they were added (the stored code
  /// is `custom:<label>`).
  final List<String> custom;

  static const PaymentMethodsConfig empty = PaymentMethodsConfig();

  /// Reads the stored text; anything malformed gives [empty] (or the valid part).
  factory PaymentMethodsConfig.decode(String? text) {
    if (text == null || text.trim().isEmpty) return empty;
    try {
      final Object? v = jsonDecode(text);
      if (v is! Map) return empty;
      final Set<String> hidden = <String>{};
      final Object? h = v['hidden'];
      if (h is List) {
        for (final Object? code in h) {
          if (code is String && _isBuiltInCode(code)) hidden.add(code);
        }
      }
      final List<String> custom = <String>[];
      final Object? c = v['custom'];
      if (c is List) {
        for (final Object? label in c) {
          if (label is! String) continue;
          final String t = label.trim();
          if (t.isEmpty || t.length > PaymentMethod.maxCustomLabelLength) continue;
          if (custom.any((String e) => _same(e, t))) continue;
          custom.add(t);
        }
      }
      return PaymentMethodsConfig(hidden: hidden, custom: custom);
    } on Object {
      return empty;
    }
  }

  /// Text to store. Nothing hidden and nothing custom is the default `[]`, so
  /// an untouched configuration never writes a settings row.
  String encode() {
    if (hidden.isEmpty && custom.isEmpty) return '[]';
    final List<String> h = hidden.toList()..sort();
    return jsonEncode(<String, Object>{'hidden': h, 'custom': custom});
  }

  static bool _isBuiltInCode(String code) =>
      PaymentMethod.builtIns.any((PaymentMethod m) => m.code == code);

  static bool _same(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

  /// Built-in methods that are shown, then the custom ones.
  List<PaymentMethod> get visible => <PaymentMethod>[
        for (final PaymentMethod m in PaymentMethod.builtIns)
          if (!hidden.contains(m.code)) m,
        for (final String label in custom) PaymentMethod.custom(label),
      ];

  int get visibleCount => visible.length;

  bool isHidden(PaymentMethod method) => hidden.contains(method.code);

  /// Flips a built-in method. Hiding the last visible method is refused: the
  /// same configuration comes back (the UI says "keep at least one").
  PaymentMethodsConfig withBuiltInShown(PaymentMethod method, {required bool shown}) {
    if (!_isBuiltInCode(method.code)) return this;
    final Set<String> next = <String>{...hidden};
    if (shown) {
      next.remove(method.code);
    } else {
      next.add(method.code);
    }
    final PaymentMethodsConfig result = PaymentMethodsConfig(hidden: next, custom: custom);
    return result.visibleCount == 0 ? this : result;
  }

  /// Checks [raw] as a new custom label. [reserved] holds the display names of
  /// the built-in methods (language dependent), so "Cash" / "ক্যাশ" can't be
  /// added again. Case-insensitive.
  CustomLabelCheck checkCustomLabel(String raw, {Iterable<String> reserved = const <String>[]}) {
    final String t = raw.trim();
    if (t.isEmpty) return CustomLabelCheck.empty;
    if (t.length > PaymentMethod.maxCustomLabelLength) return CustomLabelCheck.tooLong;
    if (custom.any((String e) => _same(e, t))) return CustomLabelCheck.duplicate;
    if (reserved.any((String e) => _same(e, t))) return CustomLabelCheck.duplicate;
    if (PaymentMethod.builtIns.any((PaymentMethod m) => _same(m.code, t))) {
      return CustomLabelCheck.duplicate;
    }
    return CustomLabelCheck.ok;
  }

  /// This configuration plus the custom label [raw] (trimmed), or null when
  /// [checkCustomLabel] is not [CustomLabelCheck.ok].
  PaymentMethodsConfig? withCustom(String raw, {Iterable<String> reserved = const <String>[]}) {
    if (checkCustomLabel(raw, reserved: reserved) != CustomLabelCheck.ok) return null;
    return PaymentMethodsConfig(hidden: hidden, custom: <String>[...custom, raw.trim()]);
  }

  PaymentMethodsConfig withoutCustom(String label) => PaymentMethodsConfig(
        hidden: hidden,
        custom: <String>[
          for (final String e in custom)
            if (e != label) e,
        ],
      );

  @override
  bool operator ==(Object other) =>
      other is PaymentMethodsConfig &&
      other.hidden.length == hidden.length &&
      other.hidden.containsAll(hidden) &&
      _listEq(other.custom, custom);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(hidden), Object.hashAll(custom));

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
