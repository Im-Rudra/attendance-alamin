// Payment methods (Product 3.12): show or hide the built-in methods and add the
// teacher's own (stored as `custom:<label>`). Saved instantly in the synced
// `payment_methods` setting.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/features/settings/controllers/settings_providers.dart';
import 'package:attendance_alamin/features/settings/data/payment_methods_config.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Display name of [method]: the localised built-in name, or the custom label.
String paymentMethodLabel(AppLocalizations l10n, PaymentMethod method) {
  if (method.isCustom) return method.customLabel ?? method.code;
  return switch (method.code) {
    'cash' => l10n.setPmCash,
    'bkash' => l10n.setPmBkash,
    'nagad' => l10n.setPmNagad,
    'rocket' => l10n.setPmRocket,
    'bank' => l10n.setPmBank,
    'other' => l10n.setPmOther,
    _ => method.code,
  };
}

/// Plain-language message for a rejected custom label; null for `ok`.
String? customLabelErrorText(AppLocalizations l10n, CustomLabelCheck check, String Function(int) digits) =>
    switch (check) {
      CustomLabelCheck.ok => null,
      CustomLabelCheck.empty => l10n.setPmErrEmpty,
      CustomLabelCheck.tooLong =>
        l10n.setPmErrLong(digits(PaymentMethod.maxCustomLabelLength)),
      CustomLabelCheck.duplicate => l10n.setPmErrDuplicate,
    };

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  final TextEditingController _label = TextEditingController();
  CustomLabelCheck _check = CustomLabelCheck.ok;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save(PaymentMethodsConfig next) =>
      saveSetting<String>(context, ref, SettingKeys.paymentMethods, next.encode());

  void _toggle(PaymentMethodsConfig config, PaymentMethod method, bool shown) {
    final PaymentMethodsConfig next = config.withBuiltInShown(method, shown: shown);
    if (next == config) {
      if (!shown) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.setPmKeepOne)));
      }
      return;
    }
    _save(next);
  }

  List<String> _reserved(AppLocalizations l10n) => <String>[
        for (final PaymentMethod m in PaymentMethod.builtIns) paymentMethodLabel(l10n, m),
      ];

  Future<void> _add(PaymentMethodsConfig config) async {
    final l10n = context.l10n;
    final String raw = _label.text;
    final CustomLabelCheck check = config.checkCustomLabel(raw, reserved: _reserved(l10n));
    if (check != CustomLabelCheck.ok) {
      setState(() => _check = check);
      return;
    }
    final PaymentMethodsConfig? next = config.withCustom(raw, reserved: _reserved(l10n));
    if (next == null) return;
    _label.clear();
    setState(() => _check = CustomLabelCheck.ok);
    await _save(next);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.setPmAdded(raw.trim()))));
  }

  Future<void> _remove(PaymentMethodsConfig config, String label) async {
    final l10n = context.l10n;
    final bool yes = await showConfirmDialog(
      context,
      title: l10n.setPmRemoveTitle(label),
      body: l10n.setPmRemoveBody,
      confirmLabel: l10n.setPmRemove,
      destructive: true,
    );
    if (!yes || !mounted) return;
    await _save(config.withoutCustom(label));
  }

  Widget _section(String title, Widget card) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[SettingsHeader(title), card],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final double g = WindowClass.of(context).gutter;
    final bool embedded = PaneScope.isEmbedded(context);
    final PaymentMethodsConfig config = ref.watch(paymentMethodsConfigProvider);

    final Widget builtIn = SettingsCard(children: <Widget>[
      for (final PaymentMethod m in PaymentMethod.builtIns)
        SettingSwitchRow(
          key: Key('pm-${m.code}'),
          title: paymentMethodLabel(l10n, m),
          subtitle: config.isHidden(m) ? l10n.setPmHidden : l10n.setPmShown,
          value: !config.isHidden(m),
          onChanged: (bool v) => _toggle(config, m, v),
        ),
    ]);

    final Widget custom = SettingsCard(children: <Widget>[
      if (config.custom.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Text(
            l10n.setPmCustomEmpty,
            style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
          ),
        ),
      for (final String label in config.custom)
        SettingRow(
          key: Key('pm-custom-$label'),
          icon: Icons.payments_outlined,
          title: label,
          value: l10n.setPmShown,
          trailing: IconButton(
            tooltip: l10n.setPmRemove,
            icon: Icon(Icons.delete_outline, color: tokens.error),
            onPressed: () => _remove(config, label),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const Key('pm-add-field'),
                controller: _label,
                textInputAction: TextInputAction.done,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(PaymentMethod.maxCustomLabelLength + 10),
                ],
                decoration: InputDecoration(
                  labelText: l10n.setPmAddLabel,
                  hintText: l10n.setPmAddHint,
                  errorText: customLabelErrorText(
                    l10n,
                    _check,
                    (int n) => fmt.digits(n.toString()),
                  ),
                  errorMaxLines: 2,
                ),
                onChanged: (_) {
                  if (_check != CustomLabelCheck.ok) {
                    setState(() => _check = CustomLabelCheck.ok);
                  }
                },
                onSubmitted: (_) => _add(config),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FilledButton.icon(
                key: const Key('pm-add-button'),
                onPressed: () => _add(config),
                icon: const Icon(Icons.add),
                label: Text(l10n.setPmAdd),
              ),
            ),
          ],
        ),
      ),
    ]);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Semantics(header: true, child: Text(l10n.shellTitlePaymentMethods)),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final bool wide = c.maxWidth >= WindowClass.expandedMin;
            return ListView(
              padding: EdgeInsets.fromLTRB(g, 4, g, g),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Text(
                    l10n.setPmIntro,
                    style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                  ),
                ),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: _section(l10n.setPmBuiltIn, builtIn)),
                      SizedBox(width: g),
                      Expanded(child: _section(l10n.setPmCustom, custom)),
                    ],
                  )
                else ...<Widget>[
                  _section(l10n.setPmBuiltIn, builtIn),
                  _section(l10n.setPmCustom, custom),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
