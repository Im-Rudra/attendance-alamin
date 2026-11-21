// Call a guardian or student (UX 3b "Calling on Windows").
// Android: opens the dialer with `tel:`. Windows and web have no dialer, so
// "কল" becomes "নম্বর কপি": the number is copied and shown in a toast.
// Use [ContactActions.label] / [ContactActions.icon] for the button.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

abstract final class ContactActions {
  /// True where a phone dialer exists (Android app).
  static bool get canCall => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Button icon: call on Android, copy elsewhere.
  static IconData get icon => canCall ? Icons.call : Icons.content_copy;

  /// Button label: "কল" on Android, "নম্বর কপি" elsewhere.
  static String label(AppLocalizations l10n) => canCall ? l10n.commonCall : l10n.commonCopyNumber;

  /// Dials [phone] on Android; otherwise (or if no dialer answers) copies it
  /// and confirms with a toast. Accepts Bangla or ASCII digits.
  static Future<void> callOrCopy(BuildContext context, String phone) async {
    final String number = AppFormat.toAsciiDigits(phone).replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) return;
    // Read before any await: the caller may be gone by then.
    final BuildContext anchor = BhorToast.anchorOf(context);
    final double lift = BhorToastInset.of(context);
    final String copied = context.l10n.shellNumberCopied(context.fmt.digits(number));
    if (canCall) {
      try {
        if (await launchUrl(Uri(scheme: 'tel', path: number))) return;
      } catch (_) {
        // No dialer: fall through to copying.
      }
    }
    await Clipboard.setData(ClipboardData(text: number));
    if (anchor.mounted) BhorToast.show(anchor, message: copied, bottomOffset: lift);
  }
}
