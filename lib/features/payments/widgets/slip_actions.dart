// Print / Save PDF of a receipt slip (feedback item 2): the paper choice panel,
// and the run: draw the receipt card off screen, wrap it in a PDF page, then
// print it or save it. The last paper is remembered on this device.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/services/print_service.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/slip_paper.dart';
import 'package:attendance_alamin/features/payments/slip_pdf.dart';
import 'package:attendance_alamin/features/payments/slip_render.dart';
import 'package:attendance_alamin/features/payments/widgets/receipt_card.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

enum SlipAction { print, savePdf }

/// The remembered paper of this device (A4 until the teacher picks another).
final slipPaperProvider = StreamProvider.autoDispose<SlipPaper>(
    (ref) => ref.watch(localMetaRepositoryProvider).watchRaw(kSlipPaperKey).map(SlipPaper.parse));

/// How the card becomes an image; tests override it with a fake image.
final slipRendererProvider = Provider<SlipRenderer>((ref) => renderSlipImage);

/// Short paper name for menus ("A4", "80 mm").
String slipPaperShort(AppLocalizations l10n, SlipPaper paper) =>
    paper == SlipPaper.a4 ? l10n.payPaperA4 : l10n.payPaperThermalShort;

/// File name of the PDF: `slip-2026-0007.pdf` (`receipt.pdf` for a receipt
/// without a number).
String slipFileName(String receiptNo) => receiptNo.isEmpty ? 'receipt.pdf' : 'slip-$receiptNo.pdf';

/// Draws the slip of [model] on [paper] and prints or saves it. Errors become
/// a toast; a cancelled dialog is silent.
Future<void> runSlipAction(
  BuildContext context,
  WidgetRef ref, {
  required ReceiptModel model,
  required ReceiptCentre centre,
  required SlipPaper paper,
  required SlipAction action,
}) async {
  // Everything the run needs is read now: the sheet may close meanwhile.
  final AppLocalizations l10n = context.l10n;
  final BuildContext anchor = BhorToast.anchorOf(context);
  final SlipRenderer renderer = ref.read(slipRendererProvider);
  final PrintService printer = ref.read(printServiceProvider);
  final LocalMetaRepository meta = ref.read(localMetaRepositoryProvider);
  final LocalDate today = ref.read(todayProvider);
  try {
    await writeSlipPaper(meta, paper);
    final Widget card = ReceiptCard(
      model: model,
      center: centre.name,
      centerPhone: centre.phone,
      centerAddress: centre.address,
      today: today,
    );
    final SlipImage image = await renderer(context, card, paper);
    final String no = model.facts.receiptNo;
    final Uint8List pdf = await buildSlipPdf(
      png: image.png,
      pixelWidth: image.width,
      pixelHeight: image.height,
      paper: paper,
      title: no,
    );
    switch (action) {
      case SlipAction.print:
        final PdfPageFormat page = slipPageFormat(paper, pixelWidth: image.width, pixelHeight: image.height);
        await printer.printPdf(pdf, jobName: slipFileName(no), pageWidth: page.width, pageHeight: page.height);
      case SlipAction.savePdf:
        final bool saved = await printer.savePdf(pdf, fileName: slipFileName(no));
        if (saved && anchor.mounted) BhorToast.show(anchor, message: l10n.payPdfSaved, tone: BhorTone.ok);
    }
  } catch (_) {
    if (anchor.mounted) BhorToast.show(anchor, message: l10n.payPrintFailed, tone: BhorTone.danger);
  }
}

/// What the paper panel gives back.
typedef SlipChoice = ({SlipPaper paper, SlipAction action});

/// Asks for the paper, then Print or Save PDF; null when closed.
Future<SlipChoice?> showSlipPanel(BuildContext context, {required SlipPaper initial}) {
  return showBhorPanel<SlipChoice>(
    context,
    title: context.l10n.payPrintTitle,
    kind: BhorPanelKind.choice,
    builder: (BuildContext ctx) => _SlipPanel(initial: initial),
  );
}

class _SlipPanel extends StatefulWidget {
  const _SlipPanel({required this.initial});

  final SlipPaper initial;

  @override
  State<_SlipPanel> createState() => _SlipPanelState();
}

class _SlipPanelState extends State<_SlipPanel> {
  late SlipPaper _paper = widget.initial;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.payPrintPaperLabel, style: b.type.meta),
        const SizedBox(height: BhorSpace.s8),
        BhorRadioCard<SlipPaper>(
          key: const ValueKey<String>('pay-paper-a4'),
          value: SlipPaper.a4,
          groupValue: _paper,
          onChanged: (SlipPaper v) => setState(() => _paper = v),
          title: l10n.payPaperA4,
          subtitle: l10n.payPaperA4Hint,
        ),
        const SizedBox(height: BhorSpace.s8),
        BhorRadioCard<SlipPaper>(
          key: const ValueKey<String>('pay-paper-thermal'),
          value: SlipPaper.thermal80,
          groupValue: _paper,
          onChanged: (SlipPaper v) => setState(() => _paper = v),
          title: l10n.payPaperThermal,
          subtitle: l10n.payPaperThermalHint,
        ),
        const SizedBox(height: BhorSpace.s16),
        BhorButton(
          key: const ValueKey<String>('pay-print-now'),
          icon: BhorIcons.receipt,
          label: l10n.payPrintNow,
          expand: true,
          onPressed: () => Navigator.of(context).pop<SlipChoice>((paper: _paper, action: SlipAction.print)),
        ),
        const SizedBox(height: BhorSpace.s8),
        BhorButton(
          key: const ValueKey<String>('pay-pdf-save'),
          variant: BhorButtonVariant.secondary,
          icon: BhorIcons.backupDown,
          label: l10n.payPdfSave,
          expand: true,
          onPressed: () => Navigator.of(context).pop<SlipChoice>((paper: _paper, action: SlipAction.savePdf)),
        ),
      ],
    );
  }
}
