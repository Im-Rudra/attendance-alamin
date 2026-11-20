// Runs before every test file under test/ (flutter_test convention).
//
// - Loads the real fonts (Hind Siliguri for Bangla + Latin, MaterialIcons) so
//   widget tests measure text and icons like the app does instead of the
//   all-square Ahem test font.
// - Silences drift's "multiple databases" warning (tests open many in-memory
//   databases, one per test).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _hindFiles = <String>[
  'assets/fonts/hind_siliguri/HindSiliguri-Regular.ttf',
  'assets/fonts/hind_siliguri/HindSiliguri-Medium.ttf',
  'assets/fonts/hind_siliguri/HindSiliguri-SemiBold.ttf',
  'assets/fonts/hind_siliguri/HindSiliguri-Bold.ttf',
];

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await _loadFonts();
  await testMain();
}

Future<void> _loadFonts() async {
  final hind = FontLoader('HindSiliguri');
  for (final path in _hindFiles) {
    hind.addFont(_bytes(path));
  }
  await _loadQuietly(hind);

  final icons = FontLoader('MaterialIcons');
  icons.addFont(_materialIcons());
  await _loadQuietly(icons);
}

/// A missing font must never break the whole test run; text then falls back
/// to the test font.
Future<void> _loadQuietly(FontLoader loader) async {
  try {
    await loader.load();
  } on Object {
    // Ignored on purpose, see above.
  }
}

Future<ByteData> _bytes(String path) async {
  final file = File(path);
  if (file.existsSync()) {
    return ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync()));
  }
  return rootBundle.load(path);
}

Future<ByteData> _materialIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final file = File(
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (file.existsSync()) {
      return ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync()));
    }
  }
  return rootBundle.load('fonts/MaterialIcons-Regular.otf');
}
