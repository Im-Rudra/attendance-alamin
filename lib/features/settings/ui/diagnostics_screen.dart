// Diagnostics (plan M6-E): where the data is stored (web storage report), the
// platform, this device's name, the app version, and the plain warning that
// uninstalling the app wipes its data.

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/providers/storage_report.dart';
import 'package:attendance_alamin/features/backup/backup_entry.dart';
import 'package:attendance_alamin/features/settings/controllers/settings_providers.dart';
import 'package:attendance_alamin/features/settings/widgets/setting_widgets.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  String _platformName(AppLocalizations l10n) {
    if (kIsWeb) return l10n.setPlatformWeb;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => l10n.setPlatformAndroid,
      TargetPlatform.windows => l10n.setPlatformWindows,
      _ => l10n.setPlatformOther,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final double g = WindowClass.of(context).gutter;
    final bool embedded = PaneScope.isEmbedded(context);
    final String deviceName = ref.watch(deviceNameProvider).value ?? '';
    final String version = ref.watch(appVersionProvider).value ?? l10n.setVersionUnknown;

    return BhorScaffold(
      header: BhorHeader(title: l10n.shellTitleDiagnostics, showBack: embedded ? false : null),
      body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final bool wide = c.maxWidth >= WindowClass.expandedMin;
            return ListView(
              padding: EdgeInsets.fromLTRB(g, 8, g, g),
              children: <Widget>[
                SettingsColumns(
                  twoUp: wide,
                  children: <Widget>[
                    ValueListenableBuilder<WebStorageInfo?>(
                      valueListenable: webStorageReport,
                      builder: (BuildContext context, WebStorageInfo? info, Widget? _) {
                        return SettingsCard(children: <Widget>[
                          _storageRow(l10n, info),
                          if (info != null && info.missingFeatures.isNotEmpty)
                            SettingRow(
                              key: const Key('diag-missing'),
                              icon: Icons.extension_off_outlined,
                              title: l10n.setDiagMissing(info.missingFeatures.join(', ')),
                            ),
                          SettingRow(
                            key: const Key('diag-platform'),
                            icon: Icons.devices_outlined,
                            title: l10n.setDiagPlatform,
                            value: _platformName(l10n),
                          ),
                          SettingRow(
                            key: const Key('diag-device-name'),
                            icon: Icons.smartphone_outlined,
                            title: l10n.setDiagDeviceName,
                            value: deviceName.trim().isEmpty
                                ? l10n.setDiagDeviceNameEmpty
                                : deviceName,
                          ),
                          // Hidden: long-press opens the Bhor design-system gallery.
                          GestureDetector(
                            onLongPress: () => context.push(Routes.moreDesignSystem),
                            child: SettingRow(
                              key: const Key('diag-version'),
                              icon: Icons.info_outline,
                              title: l10n.setVersion,
                              value: version,
                            ),
                          ),
                        ]);
                      },
                    ),
                    _WarningCard(body: _warningBody(l10n)),
                  ],
                ),
              ],
            );
          },
      ),
    );
  }

  String _warningBody(AppLocalizations l10n) {
    if (kIsWeb) return l10n.setDiagWebBody;
    if (defaultTargetPlatform == TargetPlatform.android) return l10n.setDiagUninstallBody;
    return l10n.setDiagDesktopBody;
  }

  Widget _storageRow(AppLocalizations l10n, WebStorageInfo? info) {
    if (info == null) {
      return SettingRow(
        key: const Key('diag-storage'),
        icon: Icons.storage_outlined,
        title: l10n.setDiagStorage,
        value: l10n.setDiagStorageNative,
      );
    }
    if (!info.persistent) {
      return SettingRow(
        key: const Key('diag-storage'),
        icon: Icons.warning_amber_rounded,
        title: l10n.setDiagStorage,
        value: l10n.setDiagStorageWebMemory,
        destructive: true,
      );
    }
    return SettingRow(
      key: const Key('diag-storage'),
      icon: Icons.storage_outlined,
      title: l10n.setDiagStorage,
      value: l10n.setDiagStorageWebOk(info.implementation),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    return Container(
      key: const Key('diag-warning'),
      padding: const EdgeInsets.all(BhorSpace.s16),
      decoration: BoxDecoration(
        color: c.dangerBg,
        borderRadius: BorderRadius.circular(BhorRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: c.danger),
              const SizedBox(width: BhorSpace.s12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.setDiagWarnTitle, style: b.type.heading.copyWith(color: c.danger)),
                ),
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s8),
          Text(body, style: b.type.body),
          const SizedBox(height: BhorSpace.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BhorButton(
              key: const Key('diag-backup-now'),
              icon: Icons.save_alt_outlined,
              label: l10n.setBackupNow,
              onPressed: () => runExportBackup(context),
            ),
          ),
        ],
      ),
    );
  }
}
