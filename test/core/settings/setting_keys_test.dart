import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingKeys registry', () {
    test('has 27 keys with unique snake_case ids', () {
      expect(SettingKeys.all.length, 27);
      final ids = SettingKeys.all.map((k) => k.id).toList();
      expect(ids.toSet().length, ids.length);
      final re = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final id in ids) {
        expect(re.hasMatch(id), isTrue, reason: id);
      }
    });

    test('scopes: 14 synced, 13 device', () {
      final synced = SettingKeys.all.where((k) => k.scope == SettingScope.synced);
      final device = SettingKeys.all.where((k) => k.scope == SettingScope.device);
      expect(synced.length, 14);
      expect(device.length, 13);
    });

    // (key, id, scope, default)
    final table = <(SettingKey<Object?>, String, SettingScope, Object?)>[
      (SettingKeys.centerName, 'center_name', SettingScope.synced, ''),
      (SettingKeys.centerPhone, 'center_phone', SettingScope.synced, ''),
      (SettingKeys.centerAddress, 'center_address', SettingScope.synced, ''),
      (SettingKeys.weekStart, 'week_start', SettingScope.synced, 6),
      (SettingKeys.defaultReminderLead, 'default_reminder_lead_min', SettingScope.synced, 15),
      (SettingKeys.billingCutoffDay, 'billing_cutoff_day', SettingScope.synced, 15),
      (SettingKeys.paymentMethods, 'payment_methods', SettingScope.synced, '[]'),
      (SettingKeys.reminderTemplateBn, 'reminder_template_bn', SettingScope.synced, ''),
      (SettingKeys.reminderTemplateEn, 'reminder_template_en', SettingScope.synced, ''),
      (SettingKeys.receiptTemplateBn, 'receipt_template_bn', SettingScope.synced, ''),
      (SettingKeys.receiptTemplateEn, 'receipt_template_en', SettingScope.synced, ''),
      (SettingKeys.dayWindowStart, 'day_window_start_min', SettingScope.synced, 360),
      (SettingKeys.dayWindowEnd, 'day_window_end_min', SettingScope.synced, 1380),
      (SettingKeys.centerUtcOffset, 'center_utc_offset_min', SettingScope.synced, 360),
      (SettingKeys.locale, 'locale', SettingScope.device, 'bn'),
      (SettingKeys.themeMode, 'theme_mode', SettingScope.device, 'system'),
      (SettingKeys.textSize, 'text_size', SettingScope.device, 'normal'),
      (SettingKeys.remindersEnabled, 'reminders_enabled', SettingScope.device, true),
      (SettingKeys.reducedEffects, 'reduced_effects', SettingScope.device, 'auto'),
      (SettingKeys.backupReminderDays, 'backup_reminder_days', SettingScope.device, 7),
      (SettingKeys.deviceName, 'device_name', SettingScope.device, ''),
      (SettingKeys.lastExportAt, 'last_export_at', SettingScope.device, null),
      (SettingKeys.onboardingDone, 'onboarding_done', SettingScope.device, false),
      (SettingKeys.lastBillingType, 'last_billing_type', SettingScope.device, 'prepaid'),
      (SettingKeys.notifPromptedVersion, 'notif_prompted_version', SettingScope.device, ''),
      (SettingKeys.exactPromptedVersion, 'exact_prompted_version', SettingScope.device, ''),
      (SettingKeys.remindersPlannedUntil, 'reminders_planned_until', SettingScope.device, null),
    ];
    for (final (key, id, scope, def) in table) {
      test('$id: scope, default, JSON round trip of the default', () {
        expect(key.id, id);
        expect(key.scope, scope);
        expect(key.defaultValue, def);
        expect(SettingKeys.all, contains(key));
        expect(key.decode(key.encode(key.defaultValue)), def);
        expect(key.decode(null), def);
      });
    }

    test('the table covers every key', () {
      expect(table.length, SettingKeys.all.length);
    });
  });

  group('SettingKey.decode', () {
    test('strings', () {
      expect(SettingKeys.centerName.decode('Alo Coaching'), 'Alo Coaching');
      expect(SettingKeys.centerName.decode(5), '');
      expect(SettingKeys.centerName.encode('x'), 'x');
    });

    test('week start accepts only 6, 7, 1', () {
      expect(SettingKeys.weekStart.decode(6), 6);
      expect(SettingKeys.weekStart.decode(7), 7);
      expect(SettingKeys.weekStart.decode(1), 1);
      expect(SettingKeys.weekStart.decode(2), 6);
      expect(SettingKeys.weekStart.decode(0), 6);
      expect(SettingKeys.weekStart.decode('7'), 6);
    });

    test('default reminder lead is 1..180', () {
      expect(SettingKeys.defaultReminderLead.decode(1), 1);
      expect(SettingKeys.defaultReminderLead.decode(180), 180);
      expect(SettingKeys.defaultReminderLead.decode(0), 15);
      expect(SettingKeys.defaultReminderLead.decode(181), 15);
      expect(SettingKeys.defaultReminderLead.decode(-5), 15);
      expect(SettingKeys.defaultReminderLead.decode(30), 30);
    });

    test('billing cutoff day is 1..28', () {
      expect(SettingKeys.billingCutoffDay.decode(1), 1);
      expect(SettingKeys.billingCutoffDay.decode(28), 28);
      expect(SettingKeys.billingCutoffDay.decode(29), 15);
      expect(SettingKeys.billingCutoffDay.decode(0), 15);
      expect(SettingKeys.billingCutoffDay.decode(20), 20);
    });

    test('day window is minutes of day', () {
      expect(SettingKeys.dayWindowStart.decode(0), 0);
      expect(SettingKeys.dayWindowEnd.decode(1440), 1440);
      expect(SettingKeys.dayWindowEnd.decode(1441), 1380);
      expect(SettingKeys.dayWindowStart.decode(-1), 360);
    });

    test('backup reminder days: 0 means off', () {
      expect(SettingKeys.backupReminderDays.decode(0), 0);
      expect(SettingKeys.backupReminderDays.decode(30), 30);
      expect(SettingKeys.backupReminderDays.decode(-1), 7);
      expect(SettingKeys.backupReminderDays.decode('x'), 7);
    });

    test('integers tolerate whole-number doubles (JSON on web)', () {
      expect(SettingKeys.centerUtcOffset.decode(330.0), 330);
      expect(SettingKeys.centerUtcOffset.decode(330.5), 360);
      expect(SettingKeys.centerUtcOffset.decode(double.nan), 360);
    });

    test('text size accepts only the four levels', () {
      expect(SettingKeys.textSize.decode('large'), 'large');
      expect(SettingKeys.textSize.decode('xlarge'), 'xlarge');
      expect(SettingKeys.textSize.decode('huge'), 'normal');
      expect(SettingKeys.textSize.decode(1.3), 'normal');
    });

    test('bool', () {
      expect(SettingKeys.remindersEnabled.decode(false), false);
      expect(SettingKeys.remindersEnabled.decode(true), true);
      expect(SettingKeys.remindersEnabled.decode('false'), true);
      expect(SettingKeys.onboardingDone.decode(true), true);
      expect(SettingKeys.onboardingDone.decode(1), false);
    });

    test('nullable int', () {
      expect(SettingKeys.lastExportAt.decode(null), isNull);
      expect(SettingKeys.lastExportAt.decode(1763700000000), 1763700000000);
      expect(SettingKeys.lastExportAt.decode('x'), isNull);
      expect(SettingKeys.lastExportAt.encode(null), isNull);
      expect(SettingKeys.lastExportAt.encode(5), 5);
    });
  });
}
