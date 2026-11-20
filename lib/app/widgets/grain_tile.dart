// Film-grain tile (UX 4 performance rule 4): a 128x128 greyscale noise tile,
// 3-octave value noise from a FIXED seed, generated once and cached as a
// ui.Image. It tiles seamlessly because every octave's lattice wraps.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

abstract final class GrainTile {
  static const int size = 128;
  static const int seed = 20260101;

  static Future<ui.Image>? _future;
  static ui.Image? _image;
  static int _generations = 0;

  /// The decoded tile once [load] has finished, else null.
  static ui.Image? get image => _image;

  /// How many times the tile was generated in this isolate (always 0 or 1).
  @visibleForTesting
  static int get debugGenerations => _generations;

  /// Generates the tile on first call; later calls return the same future.
  static Future<ui.Image> load() {
    return _future ??= _generate();
  }

  static Future<ui.Image> _generate() {
    _generations++;
    final Completer<ui.Image> done = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels(), size, size, ui.PixelFormat.rgba8888, (ui.Image img) {
      _image = img;
      done.complete(img);
    });
    return done.future;
  }

  /// RGBA bytes (opaque greys, mean around 128). Deterministic for [seed].
  static Uint8List pixels() {
    const List<int> cells = <int>[8, 16, 32];
    const List<double> weights = <double>[0.5, 0.3, 0.2];
    final math.Random rnd = math.Random(seed);
    final List<List<double>> lattices = <List<double>>[
      for (final int c in cells) <double>[for (int i = 0; i < c * c; i++) rnd.nextDouble()],
    ];
    final Uint8List out = Uint8List(size * size * 4);
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        double v = 0;
        for (int o = 0; o < cells.length; o++) {
          v += weights[o] * _sample(lattices[o], cells[o], x, y);
        }
        final int g = (v.clamp(0.0, 1.0) * 255).round();
        final int i = (y * size + x) * 4;
        out[i] = g;
        out[i + 1] = g;
        out[i + 2] = g;
        out[i + 3] = 255;
      }
    }
    return out;
  }

  static double _sample(List<double> lat, int n, int x, int y) {
    final double step = size / n;
    final double fx = x / step;
    final double fy = y / step;
    final int x0 = fx.floor();
    final int y0 = fy.floor();
    final double tx = _smooth(fx - x0);
    final double ty = _smooth(fy - y0);
    final int x1 = (x0 + 1) % n;
    final int y1 = (y0 + 1) % n;
    final int xa = x0 % n;
    final int ya = y0 % n;
    final double a = lat[ya * n + xa];
    final double b = lat[ya * n + x1];
    final double c = lat[y1 * n + xa];
    final double d = lat[y1 * n + x1];
    final double top = a + (b - a) * tx;
    final double bottom = c + (d - c) * tx;
    return top + (bottom - top) * ty;
  }

  static double _smooth(double t) => t * t * (3 - 2 * t);
}
