// M0-A bootstrap "hello" app. Proves the toolchain end to end: gen-l10n
// (bn template + en), the bundled Hind Siliguri font with Bangla conjuncts
// and digits, and a live bn/en switch. M5-A replaces this file with the real
// ProviderScope + App entry point.

import 'package:flutter/material.dart';

import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Font check sample: Bangla digits, taka sign with lakh grouping, conjuncts.
const kFontSample = '০১২৩৪৫৬৭৮৯ ৳১,২০,০০০ ক্ষ ন্ত্র';

void main() {
  runApp(const HelloApp());
}

class HelloApp extends StatefulWidget {
  const HelloApp({super.key, this.initialLocale = const Locale('bn')});

  final Locale initialLocale;

  @override
  State<HelloApp> createState() => _HelloAppState();
}

class _HelloAppState extends State<HelloApp> {
  late Locale _locale = widget.initialLocale;

  void _setLanguage(String code) {
    setState(() => _locale = Locale(code));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).commonAppTitle,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(fontFamily: 'HindSiliguri', brightness: Brightness.light),
      darkTheme: ThemeData(fontFamily: 'HindSiliguri', brightness: Brightness.dark),
      home: HelloScreen(
        languageCode: _locale.languageCode,
        onLanguageChanged: _setLanguage,
      ),
    );
  }
}

class HelloScreen extends StatelessWidget {
  const HelloScreen({
    super.key,
    required this.languageCode,
    required this.onLanguageChanged,
  });

  final String languageCode;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonAppTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.commonHello(l10n.commonAppTitle),
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  kFontSample,
                  style: textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Language names are endonyms: identical in every UI language.
                SegmentedButton<String>(
                  key: const Key('languageToggle'),
                  segments: const [
                    ButtonSegment<String>(value: 'bn', label: Text('বাংলা')),
                    ButtonSegment<String>(value: 'en', label: Text('English')),
                  ],
                  selected: {languageCode},
                  onSelectionChanged: (selection) => onLanguageChanged(selection.first),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
