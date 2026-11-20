// Permanent red banner when the web database fell back to memory (Arch 1.6
// step 3): "এই ব্রাউজারে ডেটা সংরক্ষণ হবে না". Never dismissible, sits above
// every route. Stays hidden on Android / Windows (report is null there).

import 'package:flutter/material.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/data/db/connection/web_storage_report.dart';

class StorageBanner extends StatelessWidget {
  const StorageBanner({super.key, required this.child});

  final Widget child;

  static const Key bannerKey = Key('storage-in-memory-banner');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WebStorageInfo?>(
      valueListenable: webStorageReport,
      builder: (BuildContext context, WebStorageInfo? info, Widget? _) {
        final bool show = info != null && !info.persistent;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (show) const _InMemoryBanner(key: bannerKey),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: show,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InMemoryBanner extends StatelessWidget {
  const _InMemoryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final TextStyle? style = Theme.of(context).textTheme.labelLarge?.copyWith(color: tokens.onError);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: tokens.error,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: <Widget>[
                ExcludeSemantics(child: Icon(Icons.warning_amber_rounded, color: tokens.onError, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(context.l10n.shellStorageInMemory, style: style)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
