import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_alamin/app/providers/async_combine.dart';

void main() {
  final err = StateError('boom');
  AsyncValue<int> data(int v) => AsyncValue<int>.data(v);
  AsyncValue<int> loading() => AsyncValue<int>.loading();
  AsyncValue<int> error() => AsyncValue<int>.error(err, StackTrace.empty);

  group('combine2', () {
    test('data + data applies the function', () {
      final r = combine2<int, int, int>(data(1), data(2), (a, b) => a + b);
      expect(r.hasValue, isTrue);
      expect(r.requireValue, 3);
    });

    test('loading while any side has no value', () {
      expect(combine2<int, int, int>(loading(), data(2), (a, b) => a + b).isLoading, isTrue);
      expect(combine2<int, int, int>(data(1), loading(), (a, b) => a + b).hasValue, isFalse);
    });

    test('an error wins over loading and data', () {
      final r = combine2<int, int, int>(loading(), error(), (a, b) => a + b);
      expect(r.hasError, isTrue);
      expect(r.error, same(err));
      expect(combine2<int, int, int>(data(1), error(), (a, b) => a + b).hasError, isTrue);
    });
  });

  group('combine3', () {
    test('data x3 applies the function', () {
      final r = combine3<int, int, int, int>(
          data(1), data(2), data(3), (a, b, c) => a * 100 + b * 10 + c);
      expect(r.requireValue, 123);
    });

    test('loading and error', () {
      expect(
          combine3<int, int, int, int>(data(1), data(2), loading(), (a, b, c) => 0)
              .isLoading,
          isTrue);
      final r = combine3<int, int, int, int>(data(1), error(), loading(), (a, b, c) => 0);
      expect(r.hasError, isTrue);
    });
  });
}
