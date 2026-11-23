/// Whether a setting travels in backups (synced, last-writer-wins per key) or
/// stays on this device (`local_meta`).
enum SettingScope { synced, device }

/// A typed, JSON-encoded setting. [fromJson] must throw (any exception) for a
/// value of the wrong type or out of range; [decode] then falls back to
/// [defaultValue].
class SettingKey<T> {
  const SettingKey(
    this.id,
    this.scope,
    this.defaultValue,
    this.fromJson,
    this.toJson,
  );

  final String id;
  final SettingScope scope;
  final T defaultValue;
  final T Function(Object? json) fromJson;
  final Object? Function(T value) toJson;

  /// Stored JSON to value; null, wrong types and out-of-range values give [defaultValue].
  T decode(Object? json) {
    if (json == null) return defaultValue;
    try {
      return fromJson(json);
    } on Object {
      return defaultValue;
    }
  }

  /// Value to JSON.
  Object? encode(T value) => toJson(value);
}

String _str(Object? j) {
  if (j is String) return j;
  throw FormatException('Expected a string', j.toString());
}

int _int(Object? j) {
  if (j is int) return j;
  if (j is num && j == j.truncate()) return j.toInt();
  throw FormatException('Expected an integer', j.toString());
}

int? _intN(Object? j) => j == null ? null : _int(j);

bool _bool(Object? j) {
  if (j is bool) return j;
  throw FormatException('Expected a bool', j.toString());
}

int _weekStart(Object? j) {
  final v = _int(j);
  if (v == 6 || v == 7 || v == 1) return v;
  throw FormatException('Week start must be 6, 7 or 1', j.toString());
}

int _lead(Object? j) {
  final v = _int(j);
  if (v >= 1 && v <= 180) return v;
  throw FormatException('Lead must be 1..180', j.toString());
}

int _cutoff(Object? j) {
  final v = _int(j);
  if (v >= 1 && v <= 28) return v;
  throw FormatException('Cutoff day must be 1..28', j.toString());
}

int _minuteOfDay(Object? j) {
  final v = _int(j);
  if (v >= 0 && v <= 1440) return v;
  throw FormatException('Minute of day must be 0..1440', j.toString());
}

int _backupDays(Object? j) {
  final v = _int(j);
  if (v >= 0 && v <= 365) return v;
  throw FormatException('Backup reminder days must be 0..365', j.toString());
}

String _textSize(Object? j) {
  final String v = _str(j);
  if (v == 'small' || v == 'normal' || v == 'large' || v == 'xlarge') return v;
  throw FormatException('Unknown text size', v);
}

Object? _idStr(String v) => v;
Object? _idInt(int v) => v;
Object? _idIntN(int? v) => v;
Object? _idBool(bool v) => v;

/// Registry of every setting. Access settings only through these keys.
abstract final class SettingKeys {
  // ---- synced ----
  static const centerName = SettingKey<String>(
      'center_name', SettingScope.synced, '', _str, _idStr);
  static const centerPhone = SettingKey<String>(
      'center_phone', SettingScope.synced, '', _str, _idStr);
  static const centerAddress = SettingKey<String>(
      'center_address', SettingScope.synced, '', _str, _idStr);

  /// First day of the week as ISO weekday: 6 (Saturday), 7 (Sunday) or 1 (Monday).
  static const weekStart = SettingKey<int>(
      'week_start', SettingScope.synced, 6, _weekStart, _idInt);

  /// Default class-reminder lead in minutes (1..180).
  static const defaultReminderLead = SettingKey<int>(
      'default_reminder_lead_min', SettingScope.synced, 15, _lead, _idInt);

  /// New-admission billing cutoff day of month (1..28).
  static const billingCutoffDay = SettingKey<int>(
      'billing_cutoff_day', SettingScope.synced, 15, _cutoff, _idInt);

  /// JSON text of the payment-method configuration (hidden built-ins + customs).
  static const paymentMethods = SettingKey<String>(
      'payment_methods', SettingScope.synced, '[]', _str, _idStr);

  /// Empty string means "use the default template".
  static const reminderTemplateBn = SettingKey<String>(
      'reminder_template_bn', SettingScope.synced, '', _str, _idStr);
  static const reminderTemplateEn = SettingKey<String>(
      'reminder_template_en', SettingScope.synced, '', _str, _idStr);
  static const receiptTemplateBn = SettingKey<String>(
      'receipt_template_bn', SettingScope.synced, '', _str, _idStr);
  static const receiptTemplateEn = SettingKey<String>(
      'receipt_template_en', SettingScope.synced, '', _str, _idStr);

  /// Free-slot suggestion window, minutes of day.
  static const dayWindowStart = SettingKey<int>(
      'day_window_start_min', SettingScope.synced, 360, _minuteOfDay, _idInt);
  static const dayWindowEnd = SettingKey<int>(
      'day_window_end_min', SettingScope.synced, 1380, _minuteOfDay, _idInt);

  /// Center offset from UTC in minutes (fixed; Dhaka = 360).
  static const centerUtcOffset = SettingKey<int>(
      'center_utc_offset_min', SettingScope.synced, 360, _int, _idInt);

  // ---- device-only ----
  /// `'bn'` or `'en'`.
  static const locale =
      SettingKey<String>('locale', SettingScope.device, 'bn', _str, _idStr);

  /// `'system'`, `'light'` or `'dark'`.
  static const themeMode = SettingKey<String>(
      'theme_mode', SettingScope.device, 'system', _str, _idStr);

  /// App text size: `'small'`, `'normal'`, `'large'` or `'xlarge'`.
  static const textSize = SettingKey<String>(
      'text_size', SettingScope.device, 'normal', _textSize, _idStr);
  static const remindersEnabled = SettingKey<bool>(
      'reminders_enabled', SettingScope.device, true, _bool, _idBool);

  /// `'auto'` or `'on'`.
  static const reducedEffects = SettingKey<String>(
      'reduced_effects', SettingScope.device, 'auto', _str, _idStr);

  /// Days between backup nudges; 0 = off.
  static const backupReminderDays = SettingKey<int>(
      'backup_reminder_days', SettingScope.device, 7, _backupDays, _idInt);
  static const deviceName =
      SettingKey<String>('device_name', SettingScope.device, '', _str, _idStr);

  /// Epoch ms of the last successful export; null = never.
  static const lastExportAt = SettingKey<int?>(
      'last_export_at', SettingScope.device, null, _intN, _idIntN);
  static const onboardingDone = SettingKey<bool>(
      'onboarding_done', SettingScope.device, false, _bool, _idBool);

  /// `'prepaid'` or `'postpaid'`.
  static const lastBillingType = SettingKey<String>(
      'last_billing_type', SettingScope.device, 'prepaid', _str, _idStr);
  static const notifPromptedVersion = SettingKey<String>(
      'notif_prompted_version', SettingScope.device, '', _str, _idStr);
  static const exactPromptedVersion = SettingKey<String>(
      'exact_prompted_version', SettingScope.device, '', _str, _idStr);

  /// Epoch ms up to which class reminders are currently planned; null = none.
  static const remindersPlannedUntil = SettingKey<int?>(
      'reminders_planned_until', SettingScope.device, null, _intN, _idIntN);

  /// Every key above.
  static const all = <SettingKey<Object?>>[
    centerName,
    centerPhone,
    centerAddress,
    weekStart,
    defaultReminderLead,
    billingCutoffDay,
    paymentMethods,
    reminderTemplateBn,
    reminderTemplateEn,
    receiptTemplateBn,
    receiptTemplateEn,
    dayWindowStart,
    dayWindowEnd,
    centerUtcOffset,
    locale,
    themeMode,
    textSize,
    remindersEnabled,
    reducedEffects,
    backupReminderDays,
    deviceName,
    lastExportAt,
    onboardingDone,
    lastBillingType,
    notifPromptedVersion,
    exactPromptedVersion,
    remindersPlannedUntil,
  ];
}
