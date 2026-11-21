// Diagnostics (plan M6-E): where the data is stored (web storage report), the
// platform, this device's name, the app version, and the plain warning that
// uninstalling the app wipes its data.

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
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
  const DiagnosticsScreen({super.key, this.embedded = false});

  /// True inside a desktop dialog: only the content, no page chrome.
  final bool embedded;

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
    final bool inPane = PaneScope.isEmbedded(context);
    final String deviceName = ref.watch(deviceNameProvider).value ?? '';
    final String version = ref.watch(appVersionProvider).value ?? l10n.setVersionUnknown;

    final List<Widget> cards = <Widget>[
                    ValueListenableBuilder<WebStorageInfo?>(
                      valueListenable: webStorageReport,
                      builder: (BuildContext context, WebStorageInfo? info, Widget? _) {
                        return SettingsCard(children: <Widget>[
                          _storageRow(l10n, info),
                          if (info != null && info.missingFeatures.isNotEmpty)
                            SettingRow(
                              key: const Key('diag-missing'),
                              icon: BhorIcons.warning,
                              title: l10n.setDiagMissing(info.missingFeatures.join(', ')),
                            ),
                          SettingRow(
                            key: const Key('diag-platform'),
                            icon: BhorIcons.desktop,
                            title: l10n.setDiagPlatform,
                            value: _platformName(l10n),
                          ),
                          SettingRow(
                            key: const Key('diag-device-name'),
                            icon: BhorIcons.phoneDevice,
                            title: l10n.setDiagDeviceName,
                            value: deviceName.trim().isEmpty
                                ? l10n.setDiagDeviceNameEmpty
                                : deviceName,
                          ),
                          // Hidden: long-press opens the Bhor design-system gallery.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: () => context.push(Routes.moreDesignSystem),
                            child: SettingRow(
                              key: const Key('diag-version'),
                              icon: BhorIcons.info,
                              title: l10n.setVersion,
                              value: version,
                            ),
                          ),
                        ]);
                      },
                    ),
                    _WarningCard(body: _warningBody(l10n)),
    ];
    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < cards.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 12),
            cards[i],
          ],
        ],
      );
    }
    return BhorScaffold(
      header: BhorHeader(title: l10n.shellTitleDiagnostics, showBack: inPane ? false : null),
      body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final bool wide = c.maxWidth >= WindowClass.expandedMin;
            return ListView(
              padding: EdgeInsets.fromLTRB(g, 8, g, g),
              children: <Widget>[
                SettingsColumns(
                  twoUp: wide,
                  children: cards,
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
        icon: BhorIcons.storage,
        title: l10n.setDiagStorage,
        value: l10n.setDiagStorageNative,
      );
    }
    if (!info.persistent) {
      return SettingRow(
        key: const Key('diag-storage'),
        icon: BhorIcons.warning,
        title: l10n.setDiagStorage,
        value: l10n.setDiagStorageWebMemory,
        destructive: true,
      );
    }
    return SettingRow(
      key: const Key('diag-storage'),
      icon: BhorIcons.storage,
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
              Icon(BhorIcons.warning, color: c.danger),
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
              icon: BhorIcons.backupUp,
              label: l10n.setBackupNow,
              onPressed: () => runExportBackup(context),
            ),
          ),
        ],
      ),
    );
  }
}
