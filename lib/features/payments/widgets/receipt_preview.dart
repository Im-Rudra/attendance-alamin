// The receipt: in-app preview (the "✓" of the template is drawn as an icon),
// the receipt sheet (send / edit / delete) and sharing the text.

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
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/payments/receipt_text.dart';
import 'package:attendance_alamin/features/payments/widgets/collect_payment_sheet.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Placeholder of the template that the in-app preview shows as an icon.
const String _kCheckMark = '✓';

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
/// template language follows the app language at this moment).
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
  if (model == null || !context.mounted) return;
  final String text = receiptTextFor(
    model: model,
    template: editorTextFor(TemplateKind.receipt, lang, stored),
    center: center,
    l10n: l10n,
    fmt: fmt,
    today: today,
  );
  await ShareService.shareText(context, text);
}

/// The message text on a card; every check mark becomes an icon.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final List<String> parts = text.split(_kCheckMark);
    final List<InlineSpan> spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(BhorIcons.check, size: 20, color: b.colors.accent),
        ));
      }
    }
    return SizedBox(
      width: double.infinity,
      child: BhorCard(
        child: Text.rich(
          TextSpan(style: b.type.body, children: spans),
          key: const ValueKey<String>('pay-receipt-text'),
        ),
      ),
    );
  }
}

/// Live preview of one receipt, rendered from the current template.
class ReceiptPreview extends ConsumerWidget {
  const ReceiptPreview({super.key, required this.receiptId});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lang = context.lang;
    final AsyncValue<ReceiptModel?> model = ref.watch(payReceiptProvider(receiptId));
    final AsyncValue<({String template, String center})> settings = ref.watch(payReceiptSettingsProvider(lang));
    if (model.hasError || settings.hasError) return Text(l10n.commonLoadingFailed);
    if (!model.hasValue || !settings.hasValue) {
      return Padding(
        padding: const EdgeInsets.all(BhorSpace.s24),
        child: Center(child: Text(l10n.payReceiptLoading)),
      );
    }
    final ReceiptModel? m = model.value;
    if (m == null) return Text(l10n.payReceiptMissing);
    return ReceiptCard(
      text: receiptTextFor(
        model: m,
        template: settings.requireValue.template,
        center: settings.requireValue.center,
        l10n: l10n,
        fmt: context.fmt,
        today: ref.watch(todayProvider),
      ),
    );
  }
}

/// Receipt sheet: the preview with send, edit and delete.
Future<void> showReceiptSheet(BuildContext context, {required String receiptId}) async {
  final String? action = await showBhorPanel<String>(
    context,
    title: context.l10n.payReceiptTitle,
    kind: BhorPanelKind.confirm,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ReceiptModel? m = ref.watch(payReceiptProvider(receiptId)).value;
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
          Row(
            children: <Widget>[
              Expanded(
                child: BhorButton(
                  key: const ValueKey<String>('pay-receipt-edit'),
                  variant: BhorButtonVariant.secondary,
                  icon: BhorIcons.edit,
                  label: l10n.commonEdit,
                  onPressed: m == null ? null : () => Navigator.of(context).pop('edit:${m.studentId}'),
                ),
              ),
              const SizedBox(width: BhorSpace.s8),
              Expanded(
                child: BhorButton(
                  key: const ValueKey<String>('pay-receipt-delete'),
                  variant: BhorButtonVariant.danger,
                  icon: BhorIcons.delete,
                  label: l10n.commonDelete,
                  onPressed: m == null ? null : () => _delete(context, ref, m),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
