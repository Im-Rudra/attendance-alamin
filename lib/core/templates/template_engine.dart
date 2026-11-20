final RegExp _placeholderRe = RegExp(r'\{([A-Za-z0-9_]+)\}');

/// Replaces every `{key}` in [template] with `values[key]`.
///
/// Placeholders without an entry in [values] are left as-is (so a typo in a
/// custom template stays visible). Replacement text is inserted literally and
/// is never re-scanned, so values containing braces are safe.
String fillTemplate(String template, Map<String, String> values) {
  return template.replaceAllMapped(_placeholderRe, (m) {
    final key = m.group(1)!;
    return values[key] ?? m.group(0)!;
  });
}
