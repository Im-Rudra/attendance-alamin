// Draws a widget (the receipt card) off screen to a high-resolution PNG.
//
// The slip PDF is made from this image, not from PDF text, so Bangla shapes
// exactly as it does on screen (the `pdf` package has no complex-script
// shaping). The card is mounted for a frame in the root Overlay far outside
// the window, inside a light theme on white (a dark-mode slip must still
// print dark-on-white) and at text scale 1 (the app's text size setting must
// not change what comes out of the printer).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/features/payments/slip_paper.dart';

/// A rendered slip: PNG bytes and their size in pixels.
class SlipImage {
  const SlipImage({required this.png, required this.width, required this.height});

  final Uint8List png;
  final int width;
  final int height;
}

/// How [card] becomes an image; tests replace it.
typedef SlipRenderer = Future<SlipImage> Function(BuildContext context, Widget card, SlipPaper paper);

/// Pixels per logical pixel of the slip: about 290 dpi on the A4 sheet.
const double kSlipPixelRatio = 3;

/// Renders [card] at [SlipPaper.cardWidth] logical pixels wide.
Future<SlipImage> renderSlipImage(BuildContext context, Widget card, SlipPaper paper) async {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final GlobalKey boundaryKey = GlobalKey();
  final BhorThemeData light = BhorThemeData.of(Brightness.light);
  final OverlayEntry entry = OverlayEntry(
    builder: (BuildContext ctx) => Positioned(
      left: -20000,
      top: 0,
      child: MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.noScaling),
        child: BhorTheme(
          data: light,
          child: DefaultTextStyle(
            style: light.type.body,
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: SizedBox(width: paper.cardWidth, child: card),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // Two frames: the first lays the card out and paints it, the second makes
    // sure late work (fonts, icons) has landed.
    for (var i = 0; i < 2; i++) {
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
    }
    final RenderObject? render = boundaryKey.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary) throw StateError('The slip was not drawn.');
    final ui.Image image = await render.toImage(pixelRatio: kSlipPixelRatio);
    try {
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('The slip could not be encoded.');
      return SlipImage(
        png: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width: image.width,
        height: image.height,
      );
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}
