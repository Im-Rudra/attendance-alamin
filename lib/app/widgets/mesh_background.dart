// Aurora mesh: three static radial pools + film grain, one RepaintBoundary
// (UX 4 performance rules 3, 4, 7). Always fills the whole window; pools stay
// anchored to their corner / edge and are sized from the SHORTER side S so they
// never stretch into bands on wide windows.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/effects_mode.dart';
import 'package:attendance_alamin/app/widgets/grain_tile.dart';

class MeshBackground extends StatefulWidget {
  const MeshBackground({super.key, required this.child});

  final Widget child;

  @override
  State<MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<MeshBackground> {
  ui.Image? _grain = GrainTile.image;
  bool _loading = false;

  void _ensureGrain() {
    if (_grain != null || _loading) return;
    _loading = true;
    GrainTile.load().then((ui.Image img) {
      if (!mounted) return;
      setState(() => _grain = img);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = EffectsMode.reducedOf(context);
    if (!reduced) _ensureGrain();
    final tokens = context.aurora;
    final gradients = context.gradients;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          child: CustomPaint(
            painter: _MeshPainter(
              base: tokens.bg,
              pools: <RadialGradient>[gradients.meshA, gradients.meshB, gradients.meshC],
              grain: reduced ? null : _grain,
              grainOpacity: tokens.grainOpacity,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Pool ellipse radii as multiples of the shorter side S: (width, height).
const List<(double, double)> kMeshPoolRadii = <(double, double)>[
  (1.2, 0.72), // A, top-left
  (1.04, 0.64), // B, right edge
  (1.28, 0.72), // C, bottom-left
];

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.base,
    required this.pools,
    required this.grain,
    required this.grainOpacity,
  });

  final Color base;
  final List<RadialGradient> pools;
  final ui.Image? grain;
  final double grainOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    canvas.drawRect(full, Paint()..color = base);
    final double s = size.shortestSide;
    for (int i = 0; i < pools.length; i++) {
      final RadialGradient g = pools[i];
      final Offset c = (g.center as Alignment).alongSize(size);
      final double rx = kMeshPoolRadii[i].$1 * s;
      final double ry = kMeshPoolRadii[i].$2 * s;
      // A unit circle scaled to the ellipse (column-major Matrix4).
      final Float64List m = Float64List.fromList(<double>[
        rx, 0, 0, 0, //
        0, ry, 0, 0,
        0, 0, 1, 0,
        c.dx, c.dy, 0, 1,
      ]);
      final Paint p = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1.0,
          g.colors,
          g.stops,
          TileMode.clamp,
          m,
        );
      canvas.drawRect(full, p);
    }
    final ui.Image? tile = grain;
    if (tile != null) {
      final Paint gp = Paint()
        ..blendMode = BlendMode.overlay
        ..shader = ui.ImageShader(
          tile,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.identity().storage,
        )
        ..colorFilter = ColorFilter.matrix(<double>[
          1, 0, 0, 0, 0, //
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, grainOpacity, 0,
        ]);
      canvas.drawRect(full, gp);
    }
  }

  @override
  bool shouldRepaint(_MeshPainter old) =>
      old.base != base ||
      old.grain != grain ||
      old.grainOpacity != grainOpacity ||
      old.pools[0] != pools[0] ||
      old.pools[1] != pools[1] ||
      old.pools[2] != pools[2];
}
