// The receipt: in-app preview (the designed [ReceiptCard]), the receipt sheet
// (send / print / edit / delete) and sharing the text.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/services/share_service.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/place_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/place.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/receipt_text.dart';
import 'package:attendance_alamin/features/payments/slip_paper.dart';
import 'package:attendance_alamin/features/payments/widgets/collect_payment_sheet.dart';
import 'package:attendance_alamin/features/payments/widgets/receipt_card.dart';
import 'package:attendance_alamin/features/payments/widgets/slip_actions.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

export 'package:attendance_alamin/features/payments/widgets/receipt_card.dart' show ReceiptCard;

/// The receipt message for [model] with the given template and center name.
String receiptTextFor({
  required ReceiptModel model,
  required String template,
  required String center,
  required AppLocalizations l10n,
  required AppFormat fmt,
  required LocalDate today,
}) {
  return renderReceiptText(
    facts: model.facts,
    template: template,
    center: center,
    fmt: fmt,
    l10n: l10n,
    today: today,
    methodLabel: paymentMethodLabel(l10n, model.method),
    paidOn: model.paidOn,
  );
}

/// Builds the receipt text from the template and shares it (Product 5; the
/// template language follows the app language at this moment). `{center}` is
/// the name of the batch's place (the centre settings when it has none).
Future<void> shareReceiptNow(BuildContext context, {required String receiptId}) async {
  final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
  final AppLocalizations l10n = context.l10n;
  final AppFormat fmt = context.fmt;
  final lang = context.lang;
  final payments = container.read(paymentsRepositoryProvider);
  final List<Payment> rows = await payments.receipt(receiptId);
  if (rows.isEmpty) return;
  final Student? student = await container.read(studentsRepositoryProvider).getById(rows.first.studentId);
  final List<EnrollmentTerms> terms = await container.read(enrollmentsRepositoryProvider).watchTerms().first;
  final List<Payment> history = await payments.watchAll().first;
  final settings = container.read(settingsRepositoryProvider);
  final String stored = await settings.get(templateKey(TemplateKind.receipt, lang));
  final String center = await settings.get(SettingKeys.centerName);
  final LocalDate today = container.read(todayProvider);
  final ReceiptModel? model = assembleReceipt(
    receiptId: receiptId,
    rows: rows,
    terms: terms,
    history: history,
    student: student,
  );
  if (model == null) return;
  final Place? place = await container.read(placesRepositoryProvider).getById(model.placeId);
  if (!context.mounted) return;
  final String text = receiptTextFor(
    model: model,
    template: editorTextFor(TemplateKind.receipt, lang, stored),
    center: resolveReceiptCentre(place: place, centerName: center, centerPhone: '', centerAddress: '').name,
    l10n: l10n,
    fmt: fmt,
    today: today,
  );
  await ShareService.shareText(context, text);
}

/// Live preview of one receipt: the designed card for the current settings.
class ReceiptPreview extends ConsumerWidget {
  const ReceiptPreview({super.key, required this.receiptId});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lang = context.lang;
    final AsyncValue<ReceiptModel?> model = ref.watch(payReceiptProvider(receiptId));
    if (model.hasError) return Text(l10n.commonLoadingFailed);
    final ReceiptModel? m = model.value;
    final AsyncValue<ReceiptCentre>? centre =
        m == null ? null : ref.watch(payReceiptCentreProvider((placeId: m.placeId, lang: lang)));
    if (centre != null && centre.hasError) return Text(l10n.commonLoadingFailed);
    if (!model.hasValue || (m != null && !centre!.hasValue)) {
      return Padding(
        padding: const EdgeInsets.all(BhorSpace.s24),
        child: Center(child: Text(l10n.payReceiptLoading)),
      );
    }
    if (m == null) return Text(l10n.payReceiptMissing);
    final ReceiptCentre c = centre!.requireValue;
    return ReceiptCard(
      model: m,
      center: c.name,
      centerPhone: c.phone,
      centerAddress: c.address,
      today: ref.watch(todayProvider),
    );
  }
}

/// Receipt sheet: the preview with send, print, edit and delete.
Future<void> showReceiptSheet(BuildContext context, {required String receiptId}) async {
  final String? action = await showBhorPanel<String>(
    context,
    title: context.l10n.payReceiptTitle,
    // A side panel on desktop like every other record view / form (G1).
    kind: BhorPanelKind.form,
    scroll: false,
    builder: (BuildContext ctx) => _ReceiptSheet(receiptId: receiptId),
  );
  if (action == null || !context.mounted) return;
  if (action.startsWith('edit:')) {
    await showEditPaymentSheet(context, receiptId: receiptId, studentId: action.substring(5));
  }
}

class _ReceiptSheet extends ConsumerWidget {
  const _ReceiptSheet({required this.receiptId});

  final String receiptId;

  Future<void> _delete(BuildContext context, WidgetRef ref, ReceiptModel m) async {
    final AppLocalizations l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final LocalDate today = ref.read(todayProvider);
    final NavigatorState nav = Navigator.of(context);
    final bool yes = await showBhorConfirm(
      context,
      title: l10n.payDeleteTitle(
        fmt.money(m.facts.total),
        fmt.monthList(m.facts.months, currentYear: today.year),
      ),
      message: l10n.payDeleteBody,
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!yes) return;
    try {
      await ref.read(paymentsRepositoryProvider).deleteReceipt(receiptId);
    } on AppException catch (e) {
      if (context.mounted) BhorToast.show(context, message: errorText(l10n, e), tone: BhorTone.danger);
      return;
    }
    if (context.mounted) BhorToast.show(context, message: l10n.payDeletedToast, tone: BhorTone.ok);
    nav.pop();
  }

  /// Asks for the paper (the last one is preselected), then prints or saves.
  Future<void> _printOrSave(BuildContext context, WidgetRef ref, ReceiptModel m, ReceiptCentre centre) async {
    final SlipPaper last = ref.read(slipPaperProvider).value ?? SlipPaper.a4;
    final SlipChoice? choice = await showSlipPanel(context, initial: last);
    if (choice == null || !context.mounted) return;
    await runSlipAction(context, ref, model: m, centre: centre, paper: choice.paper, action: choice.action);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ReceiptModel? m = ref.watch(payReceiptProvider(receiptId)).value;
    final ReceiptCentre? centre =
        m == null ? null : ref.watch(payReceiptCentreProvider((placeId: m.placeId, lang: context.lang))).value;
    final SlipPaper paper = ref.watch(slipPaperProvider).value ?? SlipPaper.a4;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ReceiptPreview(receiptId: receiptId),
          const SizedBox(height: BhorSpace.s16),
          BhorButton(
            key: const ValueKey<String>('pay-receipt-share'),
            icon: BhorIcons.share,
            label: l10n.paySendReceipt,
            expand: true,
            onPressed: m == null ? null : () => shareReceiptNow(context, receiptId: receiptId),
          ),
          const SizedBox(height: BhorSpace.s8),
          BhorButton(
            key: const ValueKey<String>('pay-receipt-print'),
            variant: BhorButtonVariant.secondary,
            icon: BhorIcons.receipt,
            label: l10n.payPrintSave,
            expand: true,
            onPressed: m != null && centre != null ? () => _printOrSave(context, ref, m, centre) : null,
          ),
          const SizedBox(height: BhorSpace.s8),
          Row(
            children: <Widget>[
              Expanded(
                child: BhorButton(
                  key: const ValueKey<String>('pay-receipt-edit'),
                  variant: BhorButtonVariant.secondary,
                  icon: BhorIcons.edit,
                  label: l10n.commonEdit,
                  expand: true,
                  onPressed: m == null ? null : () => Navigator.of(context).pop('edit:${m.studentId}'),
                ),
              ),
              const SizedBox(width: BhorSpace.s8),
              // Print on the last paper and Delete live in the ⋮ menu; Delete
              // is quiet (red, with a confirm).
              Builder(
                builder: (BuildContext bc) => BhorIconButton(
                  key: const ValueKey<String>('pay-receipt-more'),
                  icon: BhorIcons.overflowVertical,
                  semanticLabel: l10n.payMenuTooltip,
                  variant: BhorButtonVariant.secondary,
                  onPressed: m == null
                      ? null
                      : () => showBhorMenu(
                            context,
                            anchor: bc,
                            items: <BhorMenuItem>[
                              BhorMenuItem(
                                key: const ValueKey<String>('pay-receipt-menu-print'),
                                icon: BhorIcons.receipt,
                                label: l10n.payPrintMenu(slipPaperShort(l10n, paper)),
                                onTap: centre == null
                                    ? null
                                    : () => runSlipAction(context, ref,
                                        model: m, centre: centre, paper: paper, action: SlipAction.print),
                              ),
                              BhorMenuItem(
                                key: const ValueKey<String>('pay-receipt-menu-pdf'),
                                icon: BhorIcons.backupDown,
                                label: l10n.payPdfMenu(slipPaperShort(l10n, paper)),
                                onTap: centre == null
                                    ? null
                                    : () => runSlipAction(context, ref,
                                        model: m, centre: centre, paper: paper, action: SlipAction.savePdf),
                              ),
                              BhorMenuItem(
                                key: const ValueKey<String>('pay-receipt-delete'),
                                icon: BhorIcons.delete,
                                label: l10n.commonDelete,
                                destructive: true,
                                onTap: () => _delete(context, ref, m),
                              ),
                            ],
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
