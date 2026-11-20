/// Structural equality helpers for the immutable domain value types
/// (`package:collection` is not a declared dependency).
bool listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool mapEq<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

/// Order-independent hash for maps.
int mapHash<K, V>(Map<K, V> m) {
  var h = 0;
  for (final e in m.entries) {
    h = (h + Object.hash(e.key, e.value)) & 0x3FFFFFFF;
  }
  return h;
}
