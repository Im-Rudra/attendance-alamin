// The slip as a PDF: the rendered receipt image placed on a page (feedback
// item 2). The card is drawn by Flutter (so Bangla shapes correctly) and only
// wrapped here, so this file knows nothing about widgets or fonts.
//
// A4: the slip on the top half, centred, never wider than 400 pt. 80 mm: the
// roll width minus a 4 mm margin, the page as tall as the slip.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:attendance_alamin/features/payments/slip_paper.dart';

/// A4 page margin and the widest the slip is drawn (points).
const double kA4Margin = 36;
const double kA4SlipMaxWidth = 400;

/// The roll's width and side margin.
const double kThermalWidth = 80 * PdfPageFormat.mm;
const double kThermalMargin = 4 * PdfPageFormat.mm;

/// Page size of [paper] for a slip image of [pixelWidth] x [pixelHeight].
PdfPageFormat slipPageFormat(SlipPaper paper, {required int pixelWidth, required int pixelHeight}) {
  if (paper == SlipPaper.a4) return PdfPageFormat.a4;
  final double inner = kThermalWidth - 2 * kThermalMargin;
  final double height = inner * pixelHeight / pixelWidth + 2 * kThermalMargin;
  // A hair taller than the content, so rounding never makes a second page.
  return PdfPageFormat(kThermalWidth, height + 2);
}

/// Size (points) the slip is drawn at on the page of [paper].
({double width, double height}) slipDrawSize(SlipPaper paper, {required int pixelWidth, required int pixelHeight}) {
  final double aspect = pixelHeight / pixelWidth;
  if (paper == SlipPaper.thermal80) {
    final double w = kThermalWidth - 2 * kThermalMargin;
    return (width: w, height: w * aspect);
  }
  final double halfHeight = (PdfPageFormat.a4.height - 2 * kA4Margin) / 2;
  double w = kA4SlipMaxWidth;
  double h = w * aspect;
  if (h > halfHeight) {
    h = halfHeight;
    w = h / aspect;
  }
  return (width: w, height: h);
}

/// The slip image ([png], [pixelWidth] x [pixelHeight]) on a one-page PDF.
Future<Uint8List> buildSlipPdf({
  required Uint8List png,
  required int pixelWidth,
  required int pixelHeight,
  required SlipPaper paper,
  String title = '',
}) async {
  final pw.Document doc = pw.Document(title: title, creator: 'Hajira Khata');
  final pw.MemoryImage image = pw.MemoryImage(png);
  final ({double width, double height}) size = slipDrawSize(paper, pixelWidth: pixelWidth, pixelHeight: pixelHeight);
  final PdfPageFormat base = slipPageFormat(paper, pixelWidth: pixelWidth, pixelHeight: pixelHeight);
  final double margin = paper == SlipPaper.a4 ? kA4Margin : kThermalMargin;
  doc.addPage(
    pw.Page(
      pageFormat: base,
      margin: pw.EdgeInsets.all(margin),
      build: (pw.Context context) => pw.Align(
        alignment: pw.Alignment.topCenter,
        child: pw.SizedBox(
          width: size.width,
          height: size.height,
          child: pw.Image(image, fit: pw.BoxFit.fill),
        ),
      ),
    ),
  );
  return doc.save();
}
