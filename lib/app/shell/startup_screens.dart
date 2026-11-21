// What the window shows before the real app can run: a quiet loading frame
// while the database opens, and a full-screen localised error with a retry
// when it cannot open (plan M5-A, lead note on M3-A). Never a blank page.
// The language and the light/dark look follow the device (the saved choices
// live in the database).

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/app.dart' show BhorAppRoot;
import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
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
    return WidgetsApp(
      debugShowCheckedModeBanner: false,
      color: BhorThemeData.light().colors.accent,
      onGenerateTitle: (BuildContext context) => context.l10n.commonAppTitle,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (BuildContext context, Animation<double> a, Animation<double> s) => builder(context),
      ),
      builder: (BuildContext context, Widget? child) =>
          BhorAppRoot(themeMode: ThemeMode.system, child: child ?? const SizedBox.shrink()),
      home: e == null || retry == null ? const _Loading() : StartupErrorScreen(error: e, onRetry: retry),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return BhorScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(context.l10n.commonAppTitle, style: b.type.display),
            const SizedBox(height: BhorSpace.s20),
            BhorSpinner(size: 28, semanticLabel: context.l10n.a11yLoading),
          ],
        ),
      ),
    );
  }
}

/// "Data storage couldn't start" + retry + technical details behind an
/// expander (UX 3 error rule).
class StartupErrorScreen extends StatefulWidget {
  const StartupErrorScreen({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  State<StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends State<StartupErrorScreen> {
  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final l10n = context.l10n;
    return BhorScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BhorSpace.s16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: BhorCard(
              padding: const EdgeInsets.fromLTRB(BhorSpace.s24, 28, BhorSpace.s24, BhorSpace.s16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ExcludeSemantics(child: Icon(BhorIcons.storage, size: 64, color: c.danger)),
                  const SizedBox(height: BhorSpace.s16),
                  Semantics(
                    header: true,
                    child: Text(l10n.shellStartupErrorTitle, textAlign: TextAlign.center, style: b.type.title),
                  ),
                  const SizedBox(height: BhorSpace.s8),
                  Text(
                    l10n.shellStartupErrorBody,
                    textAlign: TextAlign.center,
                    style: b.type.body.copyWith(color: c.text2),
                  ),
                  const SizedBox(height: BhorSpace.s20),
                  Center(
                    child: BhorButton(label: l10n.commonRetry, icon: BhorIcons.refresh, onPressed: widget.onRetry),
                  ),
                  const SizedBox(height: BhorSpace.s8),
                  BhorPressable(
                    onTap: () => setState(() => _details = !_details),
                    semanticLabel: l10n.commonDetails,
                    toggled: _details,
                    scaleOnPress: false,
                    builder: (BuildContext context, BhorStates s) => SizedBox(
                      height: BhorSize.control,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              l10n.commonDetails,
                              style: b.type.label.copyWith(color: s.hovered ? c.text : c.text2),
                            ),
                          ),
                          AnimatedRotation(
                            turns: _details ? 0.5 : 0,
                            duration: BhorMotion.base,
                            child: Icon(BhorIcons.chevronDown, color: c.text2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_details)
                    BhorTextField(
                      initialValue: widget.error.toString(),
                      readOnly: true,
                      maxLines: null,
                      semanticLabel: l10n.commonDetails,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
