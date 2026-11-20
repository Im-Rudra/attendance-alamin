import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Combines two [AsyncValue]s (plan 2.5: the only sanctioned way to do so).
///
/// Any error wins (first argument first); otherwise the result is loading
/// until both have a value, then `f(a, b)`. A value that is being refreshed
/// (loading with a previous value) counts as a value, so screens do not flash.
AsyncValue<R> combine2<A, B, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  R Function(A a, B b) f,
) {
  final err = _firstError<R>([a, b]);
  if (err != null) return err;
  if (!a.hasValue || !b.hasValue) return AsyncValue<R>.loading();
  return AsyncValue<R>.data(f(a.requireValue, b.requireValue));
}

/// Three-way [combine2].
AsyncValue<R> combine3<A, B, C, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  AsyncValue<C> c,
  R Function(A a, B b, C c) f,
) {
  final err = _firstError<R>([a, b, c]);
  if (err != null) return err;
  if (!a.hasValue || !b.hasValue || !c.hasValue) {
    return AsyncValue<R>.loading();
  }
  return AsyncValue<R>.data(
      f(a.requireValue, b.requireValue, c.requireValue));
}

AsyncValue<R>? _firstError<R>(List<AsyncValue<Object?>> values) {
  for (final v in values) {
    if (v.hasError) {
      return AsyncValue<R>.error(v.error!, v.stackTrace ?? StackTrace.empty);
    }
  }
  return null;
}
