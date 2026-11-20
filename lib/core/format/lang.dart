/// App language. Bangla is the default.
enum Lang {
  bn,
  en;

  String get code => name;

  /// `'en'` gives [en]; anything else (including null) gives [bn].
  static Lang fromCode(String? c) => c == 'en' ? Lang.en : Lang.bn;
}
