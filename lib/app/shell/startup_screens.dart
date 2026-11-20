// What the window shows before the real app can run: a quiet loading frame
// while the database opens, and a full-screen localised error with a retry
// when it cannot open (plan M5-A, lead note on M3-A). Never a blank page.
// The language follows the device (the saved choice lives in the database).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class StartupApp extends StatelessWidget {
  /// Shown while the database opens.
  const StartupApp.loading({super.key})
      : error = null,
        onRetry = null;

  /// Shown when the database could not open.
  const StartupApp.error({super.key, required Object this.error, required VoidCallback this.onRetry});

  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final Object? e = error;
    final VoidCallback? retry = onRetry;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (BuildContext context) => context.l10n.commonAppTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MeshBackground(
        child: e == null || retry == null
            ? const _Loading()
            : StartupErrorScreen(error: e, onRetry: retry),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              context.l10n.commonAppTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                semanticsLabel: context.l10n.a11yLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Data storage couldn't start" + retry + technical details behind an
/// expander (UX 3 error rule).
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final TextTheme tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                blur: true,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ExcludeSemantics(child: Icon(Icons.storage_rounded, size: 64, color: tokens.error)),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.shellStartupErrorTitle,
                        textAlign: TextAlign.center,
                        style: tt.titleLarge?.copyWith(color: tokens.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.shellStartupErrorBody,
                      textAlign: TextAlign.center,
                      style: tt.bodyLarge?.copyWith(color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.commonRetry),
                    ),
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      // Own Material: the tile's ink must paint above the card fill.
                      child: Material(
                        type: MaterialType.transparency,
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(l10n.commonDetails, style: tt.labelLarge?.copyWith(color: tokens.textSecondary)),
                          children: <Widget>[
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: SelectableText(
                                error.toString(),
                                style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
