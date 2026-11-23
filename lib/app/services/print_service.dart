// Printing and saving a PDF (the payment slip). Behind an interface so tests
// use a fake and never reach a plugin.
//
// The `printing` package's own widgets (PdfPreview and friends) are Material,
// so only its two plain calls are used here:
//   - print: `Printing.layoutPdf` opens the system print dialog (on Windows it
//     lists "Microsoft Print to PDF"; on Android the print framework);
//   - save: Windows / Linux / macOS ask for a file name (file_picker); Android
//     and web hand the PDF to the system (`Printing.sharePdf`: share sheet /
//     browser download).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';

abstract interface class PrintService {
  /// Opens the system print dialog for [pdf] on a page of
  /// [pageWidth] x [pageHeight] points. True when the job was sent; false when
  /// the teacher cancelled.
  Future<bool> printPdf(
    Uint8List pdf, {
    required String jobName,
    required double pageWidth,
    required double pageHeight,
  });

  /// Lets the teacher keep [pdf] as a file. True when it was saved or handed
  /// to the system; false when the teacher cancelled.
  Future<bool> savePdf(Uint8List pdf, {required String fileName});
}

/// [PrintService] over `printing` and `file_picker`.
class PluginPrintService implements PrintService {
  const PluginPrintService();

  static bool get _sharesInsteadOfSaves =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<bool> printPdf(
    Uint8List pdf, {
    required String jobName,
    required double pageWidth,
    required double pageHeight,
  }) {
    return Printing.layoutPdf(
      name: jobName,
      format: PdfPageFormat(pageWidth, pageHeight),
      dynamicLayout: false,
      onLayout: (PdfPageFormat format) async => pdf,
    );
  }

  @override
  Future<bool> savePdf(Uint8List pdf, {required String fileName}) async {
    if (_sharesInsteadOfSaves) {
      await Printing.sharePdf(bytes: pdf, filename: fileName);
      return true;
    }
    final Uri? saved = await FilePicker.saveFile(fileName: fileName, bytes: pdf, mimeType: 'application/pdf');
    return saved != null;
  }
}

/// The app's print service; tests override it with a fake.
final printServiceProvider = Provider<PrintService>((ref) => const PluginPrintService());
