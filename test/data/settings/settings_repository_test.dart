import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/clock.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/db/app_database.dart';
import 'package:attendance_alamin/data/db/sync_stamper.dart';
import 'package:attendance_alamin/data/infra_providers.dart';
import 'package:attendance_alamin/data/repositories/drift/local_meta_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/drift/settings_repository_drift.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_repository.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes/fake_settings_repos.dart';

/// 2026-11-20 09:00 UTC.
const t0 = 1795165200000;

AppDatabase _openDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

class _MutableClock implements Clock {
  _MutableClock(this.ms);
  int ms;
  @override
  DateTime nowUtc() => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late AppDatabase db;
  late _MutableClock clock;
  late SettingsRepository repo;

  setUp(() {
    db = _openDb();
    clock = _MutableClock(t0);
    repo = DriftSettingsRepository(db, SyncStamper(clock: clock, deviceId: 'dev-A'));
  });

  Future<SettingRow?> settingRow(String id) =>
      (db.select(db.syncedSettings)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<LocalMetaRow?> metaRow(String key) =>
      (db.select(db.localMeta)..where((t) => t.metaKey.equals(key))).getSingleOrNull();

  group('defaults', () {
    Future<void> expectDefault<T>(SettingKey<T> k) async =>
        expect(await repo.get(k), k.defaultValue, reason: k.id);

    test('every key reads its default on an empty database', () async {
      await expectDefault(SettingKeys.centerName);
      await expectDefault(SettingKeys.centerPhone);
      await expectDefault(SettingKeys.centerAddress);
      await expectDefault(SettingKeys.weekStart);
      await expectDefault(SettingKeys.defaultReminderLead);
      await expectDefault(SettingKeys.billingCutoffDay);
      await expectDefault(SettingKeys.paymentMethods);
      await expectDefault(SettingKeys.reminderTemplateBn);
      await expectDefault(SettingKeys.reminderTemplateEn);
      await expectDefault(SettingKeys.receiptTemplateBn);
      await expectDefault(SettingKeys.receiptTemplateEn);
      await expectDefault(SettingKeys.dayWindowStart);
      await expectDefault(SettingKeys.dayWindowEnd);
      await expectDefault(SettingKeys.centerUtcOffset);
      await expectDefault(SettingKeys.locale);
      await expectDefault(SettingKeys.themeMode);
      await expectDefault(SettingKeys.remindersEnabled);
      await expectDefault(SettingKeys.reducedEffects);
      await expectDefault(SettingKeys.backupReminderDays);
      await expectDefault(SettingKeys.deviceName);
      await expectDefault(SettingKeys.lastExportAt);
      await expectDefault(SettingKeys.onboardingDone);
      await expectDefault(SettingKeys.lastBillingType);
      await expectDefault(SettingKeys.notifPromptedVersion);
      await expectDefault(SettingKeys.exactPromptedVersion);
      await expectDefault(SettingKeys.remindersPlannedUntil);
      expect(SettingKeys.all, hasLength(26));
    });

    test('malformed or out-of-range stored values read as the default', () async {
      await db.into(db.localMeta).insert(
          LocalMetaCompanion.insert(metaKey: 'theme_mode', metaValue: 'not json {'));
      await db.into(db.syncedSettings).insert(SyncedSettingsCompanion.insert(
          id: 'default_reminder_lead_min', createdAt: t0, updatedAt: t0, deviceId: 'x', value: '500'));
      await db.into(db.syncedSettings).insert(SyncedSettingsCompanion.insert(
          id: 'week_start', createdAt: t0, updatedAt: t0, deviceId: 'x', value: '"sat"'));
      expect(await repo.get(SettingKeys.themeMode), 'system');
      expect(await repo.get(SettingKeys.defaultReminderLead), 15);
      expect(await repo.get(SettingKeys.weekStart), 6);
    });
  });

  group('synced keys', () {
    test('round-trip stores a stamped JSON row in settings, not local_meta', () async {
      await repo.set(SettingKeys.centerName, 'আলামিন কোচিং');
      expect(await repo.get(SettingKeys.centerName), 'আলামিন কোচিং');
      final row = await settingRow('center_name');
      expect(row, isNotNull);
      expect(row!.value, '"আলামিন কোচিং"');
      expect(row.createdAt, t0);
      expect(row.updatedAt, t0);
      expect(row.rev, 1);
      expect(row.deviceId, 'dev-A');
      expect(row.deletedAt, isNull);
      expect(await metaRow('center_name'), isNull);
    });

    test('int keys round-trip', () async {
      await repo.set(SettingKeys.weekStart, 7);
      await repo.set(SettingKeys.defaultReminderLead, 30);
      await repo.set(SettingKeys.billingCutoffDay, 20);
      await repo.set(SettingKeys.dayWindowEnd, 1320);
      expect(await repo.get(SettingKeys.weekStart), 7);
      expect(await repo.get(SettingKeys.defaultReminderLead), 30);
      expect(await repo.get(SettingKeys.billingCutoffDay), 20);
      expect(await repo.get(SettingKeys.dayWindowEnd), 1320);
      expect((await settingRow('week_start'))!.value, '7');
    });

    test('an update bumps updatedAt monotonically and rev', () async {
      await repo.set(SettingKeys.defaultReminderLead, 10);
      // Clock skew: now is BEFORE the stored updatedAt.
      clock.ms = t0 - 60000;
      await repo.set(SettingKeys.defaultReminderLead, 20);
      final row = (await settingRow('default_reminder_lead_min'))!;
      expect(row.value, '20');
      expect(row.updatedAt, t0 + 1);
      expect(row.createdAt, t0);
      expect(row.rev, 2);
    });

    test('writing the stored value again is a no-op', () async {
      await repo.set(SettingKeys.centerPhone, '01711111111');
      clock.ms = t0 + 5000;
      await repo.set(SettingKeys.centerPhone, '01711111111');
      final row = (await settingRow('center_phone'))!;
      expect(row.rev, 1);
      expect(row.updatedAt, t0);
    });

    test('a tombstoned row reads as default and set revives it', () async {
      await db.into(db.syncedSettings).insert(SyncedSettingsCompanion.insert(
          id: 'center_name',
          createdAt: t0 - 1000,
          updatedAt: t0 - 1000,
          deletedAt: const Value(t0 - 1000),
          deviceId: 'dev-B',
          rev: const Value(4),
          value: '"Old"'));
      expect(await repo.get(SettingKeys.centerName), '');
      await repo.set(SettingKeys.centerName, 'New');
      final row = (await settingRow('center_name'))!;
      expect(row.deletedAt, isNull);
      expect(row.rev, 5);
      expect(row.deviceId, 'dev-A');
      expect(row.updatedAt, t0);
      expect(await repo.get(SettingKeys.centerName), 'New');
    });

    test('values the key codec rejects throw ArgumentError and write nothing', () async {
      await expectLater(repo.set(SettingKeys.weekStart, 3), throwsArgumentError);
      await expectLater(repo.set(SettingKeys.defaultReminderLead, 0), throwsArgumentError);
      await expectLater(repo.set(SettingKeys.billingCutoffDay, 29), throwsArgumentError);
      expect(await settingRow('week_start'), isNull);
    });

    test('watch emits the default, then each distinct new value', () async {
      final values = <int>[];
      final sub = repo.watch(SettingKeys.defaultReminderLead).listen(values.add);
      addTearDown(sub.cancel);
      await _until(() => values.isNotEmpty);
      await repo.set(SettingKeys.defaultReminderLead, 30);
      await _until(() => values.length >= 2);
      await repo.set(SettingKeys.centerName, 'unrelated');
      await repo.set(SettingKeys.defaultReminderLead, 45);
      await _until(() => values.length >= 3);
      expect(values, [15, 30, 45]);
    });
  });

  group('device keys', () {
    test('round-trip through local_meta and never touch settings', () async {
      await repo.set(SettingKeys.locale, 'en');
      await repo.set(SettingKeys.themeMode, 'dark');
      await repo.set(SettingKeys.remindersEnabled, false);
      await repo.set(SettingKeys.onboardingDone, true);
      await repo.set(SettingKeys.backupReminderDays, 0);
      expect(await repo.get(SettingKeys.locale), 'en');
      expect(await repo.get(SettingKeys.themeMode), 'dark');
      expect(await repo.get(SettingKeys.remindersEnabled), isFalse);
      expect(await repo.get(SettingKeys.onboardingDone), isTrue);
      expect(await repo.get(SettingKeys.backupReminderDays), 0);
      expect((await metaRow('locale'))!.metaValue, '"en"');
      expect((await metaRow('reminders_enabled'))!.metaValue, 'false');
      expect(await db.select(db.syncedSettings).get(), isEmpty);
    });

    test('nullable keys store ints and clear back to null', () async {
      await repo.set(SettingKeys.lastExportAt, t0);
      expect(await repo.get(SettingKeys.lastExportAt), t0);
      await repo.set(SettingKeys.lastExportAt, null);
      expect(await repo.get(SettingKeys.lastExportAt), isNull);
      expect(await metaRow('last_export_at'), isNull);
    });

    test('watch follows device keys', () async {
      final values = <String>[];
      final sub = repo.watch(SettingKeys.themeMode).listen(values.add);
      addTearDown(sub.cancel);
      await _until(() => values.isNotEmpty);
      await repo.set(SettingKeys.themeMode, 'light');
      await _until(() => values.length >= 2);
      expect(values, ['system', 'light']);
    });
  });

  group('LocalMetaRepository', () {
    late LocalMetaRepository meta;
    setUp(() => meta = DriftLocalMetaRepository(db));

    test('set, get, overwrite and remove', () async {
      final key = LocalMetaKeys.lastMethod('stu-1');
      expect(await meta.getRaw(key), isNull);
      await meta.setRaw(key, 'bkash');
      expect(await meta.getRaw(key), 'bkash');
      await meta.setRaw(key, 'cash');
      expect(await meta.getRaw(key), 'cash');
      await meta.setRaw(key, null);
      expect(await meta.getRaw(key), isNull);
    });

    test('device_id and empty keys are refused', () async {
      await expectLater(meta.setRaw('device_id', 'x'), throwsArgumentError);
      await expectLater(meta.setRaw('', 'x'), throwsArgumentError);
    });

    test('key formats', () {
      expect(LocalMetaKeys.rollCallDraft('s.abc.20261121'), 'rollcall_draft:s.abc.20261121');
      expect(LocalMetaKeys.lastMethod('stu-1'), 'last_method:stu-1');
      expect(LocalMetaKeys.reminded(LocalDate.parse('2026-11-21')), 'reminded:20261121');
      expect(LocalMetaKeys.absenceDismissed('enr-1'), 'absence_dismissed:enr-1');
      expect(LocalMetaKeys.pane('students'), 'pane:students');
      expect(LocalMetaKeys.lastImport('dev-P'), 'last_import:dev-P');
    });

    test('watchRaw emits changes', () async {
      final key = LocalMetaKeys.pane('students');
      final values = <String?>[];
      final sub = meta.watchRaw(key).listen(values.add);
      addTearDown(sub.cancel);
      await _until(() => values.isNotEmpty);
      await meta.setRaw(key, '360.0');
      await _until(() => values.length >= 2);
      await meta.setRaw(key, null);
      await _until(() => values.length >= 3);
      expect(values, [null, '360.0', null]);
    });
  });

  group('providers', () {
    test('resolve against the overridden database', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('dev-P'),
          clockProvider.overrideWithValue(clock),
        ],
        retry: (_, __) => null,
      );
      addTearDown(container.dispose);
      await container.read(settingsRepositoryProvider).set(SettingKeys.centerName, 'X');
      expect((await settingRow('center_name'))!.deviceId, 'dev-P');
      await container.read(localMetaRepositoryProvider).setRaw('pane:x', '1');
      expect(await DriftLocalMetaRepository(db).getRaw('pane:x'), '1');
    });
  });

  group('FakeSettingsRepository', () {
    test('mirrors defaults, round-trip, validation and watch', () async {
      final fake = FakeSettingsRepository();
      expect(await fake.get(SettingKeys.weekStart), 6);
      await fake.set(SettingKeys.weekStart, 7);
      expect(await fake.get(SettingKeys.weekStart), 7);
      await expectLater(fake.set(SettingKeys.weekStart, 2), throwsArgumentError);
      final values = <String>[];
      final sub = fake.watch(SettingKeys.locale).listen(values.add);
      addTearDown(sub.cancel);
      await _until(() => values.isNotEmpty);
      await fake.set(SettingKeys.locale, 'en');
      await _until(() => values.length >= 2);
      expect(values, ['bn', 'en']);
    });
  });
}
