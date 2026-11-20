import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mirrors the layering rules of tool/check_domain_purity.sh for lib/core so a
/// violation fails `flutter test test/core` locally as well as in the CI script.
void main() {
  final files = Directory('lib/core')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('lib/core has Dart files', () {
    expect(files, isNotEmpty);
  });

  test('imports only dart:*, uuid, crypto, archive and core/domain', () {
    final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);
    const forbiddenDart = {'io', 'ui', 'html', 'js', 'js_interop', 'js_util', 'ffi', 'isolate', 'mirrors'};
    for (final f in files) {
      for (final m in importRe.allMatches(f.readAsStringSync())) {
        final uri = m.group(1)!;
        if (uri.startsWith('dart:')) {
          expect(forbiddenDart.contains(uri.substring(5)), isFalse, reason: '${f.path}: $uri');
        } else {
          final ok = uri.startsWith('package:uuid/') ||
              uri.startsWith('package:crypto/') ||
              uri.startsWith('package:archive/') ||
              uri.startsWith('package:attendance_alamin/core/') ||
              uri.startsWith('package:attendance_alamin/domain/');
          expect(ok, isTrue, reason: '${f.path}: $uri');
        }
      }
    }
  });

  test('only core/time/clock.dart calls the system clock', () {
    final callRe = RegExp(r'DateTime\s*\.\s*now\s*\(');
    for (final f in files) {
      final isClock = f.path.replaceAll(r'\', '/').endsWith('lib/core/time/clock.dart');
      final code = f
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      if (!isClock) {
        expect(callRe.hasMatch(code), isFalse, reason: f.path);
      }
    }
  });
}
