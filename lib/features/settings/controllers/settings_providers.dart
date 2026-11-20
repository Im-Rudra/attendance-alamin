// Providers and helpers of the settings screens. Every value is read from the
// typed [SettingKeys] through the settings repository and saved the moment it
// changes (no Save button).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/features/settings/data/payment_methods_config.dart';

StreamProvider<T> _watchKey<T>(SettingKey<T> key) =>
    StreamProvider<T>((Ref ref) => ref.watch(settingsRepositoryProvider).watch(key));

final defaultLeadProvider = _watchKey<int>(SettingKeys.defaultReminderLead);
final cutoffDayProvider = _watchKey<int>(SettingKeys.billingCutoffDay);
final remindersEnabledProvider = _watchKey<bool>(SettingKeys.remindersEnabled);
final reducedEffectsSettingProvider = _watchKey<String>(SettingKeys.reducedEffects);
final backupReminderDaysProvider = _watchKey<int>(SettingKeys.backupReminderDays);
final deviceNameProvider = _watchKey<String>(SettingKeys.deviceName);
final lastExportAtProvider = _watchKey<int?>(SettingKeys.lastExportAt);
final reminderTemplateBnProvider = _watchKey<String>(SettingKeys.reminderTemplateBn);
final reminderTemplateEnProvider = _watchKey<String>(SettingKeys.reminderTemplateEn);
final receiptTemplateBnProvider = _watchKey<String>(SettingKeys.receiptTemplateBn);
final receiptTemplateEnProvider = _watchKey<String>(SettingKeys.receiptTemplateEn);
final _paymentMethodsTextProvider = _watchKey<String>(SettingKeys.paymentMethods);

/// The payment-method configuration (hidden built-ins + custom labels). The
/// payment form reads `.visible`. Reads as [PaymentMethodsConfig.empty] while
/// the setting loads.
final paymentMethodsConfigProvider = Provider<PaymentMethodsConfig>((Ref ref) {
  final String? text = ref.watch(_paymentMethodsTextProvider).value;
  return PaymentMethodsConfig.decode(text);
});

/// Whole days since the last export in center time, null when never exported.
final daysSinceBackupProvider = Provider<int?>((Ref ref) {
  final int? at = ref.watch(lastExportAtProvider).value;
  if (at == null) return null;
  final center = ref.watch(centerTimeProvider);
  final int days = center.dateOfEpochMs(at).daysUntil(ref.watch(todayProvider));
  return days < 0 ? 0 : days;
});

/// App version text ("1.0.0 (12)"); null when the platform can't tell (tests).
final appVersionProvider = FutureProvider<String?>((Ref ref) async {
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    final String build = info.buildNumber.trim();
    return build.isEmpty ? info.version : '${info.version} ($build)';
  } on Object {
    return null;
  }
});

/// Saves [value] now; a failure shows a plain-language snackbar instead of
/// crashing the screen.
Future<void> saveSetting<T>(
  BuildContext context,
  WidgetRef ref,
  SettingKey<T> key,
  T value,
) async {
  final repo = ref.read(settingsRepositoryProvider);
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  try {
    await repo.set<T>(key, value);
  } on Object catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
  }
}
